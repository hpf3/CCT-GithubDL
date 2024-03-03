local libManager = require("GithubDL.libManager")
local configManager = libManager.getConfigManager()
local textHelper = libManager.gettextHelper()
local fileManager = libManager.getFileManager()
local base64 = libManager.getBase64()
local httpManager = libManager.gethttpManager()
local ApiUrl = "https://api.github.com"
local manifestExtension = ".GDLManifest"
local githubApiHandler = {}

--remote functions
local function GetFile64(url)
    local response,error = httpManager.SendHttpGET(url)
    if response == nil then
        return nil, error
    end
    local responseData = textutils.unserializeJSON(response.body)
    --textHelper.log("Downloaded "..url, "githubApiHandler.GetFile64",true)
    --textHelper.log("response: "..response.body, "githubApiHandler.GetFile64",true)
    local decoded = base64.decode(responseData.content)
    --textHelper.log("data: "..decoded, "githubApiHandler.GetFile64",true)
    return decoded
end


githubApiHandler.Gettree = function(owner,repo,branch)
    if branch == nil or branch == "" then
        return nil, "No branch provided"
    end
    local url = ApiUrl.."/repos/"..owner.."/"..repo.."/git/trees/"..branch.."?recursive=1"
    local response,error = httpManager.SendHttpGET(url)
    if response == nil then
        return nil, error
    end
    return textutils.unserializeJSON(response.body)
end

githubApiHandler.getRepoInfo = function (owner,repo)
    local url = ApiUrl.."/repos/"..owner.."/"..repo
    local response,error = httpManager.SendHttpGET(url)
    if response == nil then
        return nil, error
    end

    return textutils.unserializeJSON(response.body)
end
githubApiHandler.getLatestCommit = function(owner,repo,branch)
    local url = ApiUrl.."/repos/"..owner.."/"..repo.."/commits/"..branch
    local headers = {
        ["per_page"] = "1"
    }
    local response,error = httpManager.SendHttpGET(url,headers)
    if response == nil then
        return nil, error
    end
    return textutils.unserializeJSON(response.body)
end

githubApiHandler.downloadManifest = function(owner,repo,branch)
    local repoData,msg = githubApiHandler.getRepoInfo(owner,repo)
    if repoData == nil then
        return nil, msg
    end
    local manifest = {}
    manifest.owner = owner
    manifest.repo = repo
    if branch == nil or branch == "" then
        branch = repoData.default_branch
    end
    manifest.branch = branch
    local commit,msg = githubApiHandler.getLatestCommit(owner,repo,branch)
    if commit == nil then
        return nil, msg
    end
    manifest.last_commit = commit.sha
    textHelper.log("Downloading manifest for "..manifest.owner.."/"..manifest.repo.."/"..manifest.branch, "githubApiHandler.downloadManifest",true)
    local tree,error = githubApiHandler.Gettree(owner,repo,branch)
    if tree == nil then
        return nil, error
    end
    local count = 0
    local files = {}
    for i=1,#tree.tree do
        local file = tree.tree[i]
        --check if item is file
        if file.type == "blob" then
            if textHelper.endsWith(file.path,manifestExtension) then
                files[file.path] = file
                count = count + 1
            end
        end
    end
    textHelper.log("Found "..count.." manifest files", "githubApiHandler.downloadManifest",true)
    manifest.projects = {}
    for k,v in pairs(files) do
        local project = {}
        project.path = k
        project.sha = v.sha
        --download the file
        local content = GetFile64(v.url)
        if content == nil then
            return nil, error
        end
        --content = textHelper.flatten(content)
        local manifestData,msg = textutils.unserializeJSON(content)
        if manifestData == nil then
            textHelper.log("Failed to parse manifest: "..project.path)
            textHelper.log("Failed content: "..content, "githubApiHandler.downloadManifest",true)
            textHelper.log("Failed reason: "..msg, "githubApiHandler.downloadManifest",true)
        else
            textHelper.log("found project: "..manifestData.name)
            project.manifest = manifestData
            table.insert(manifest.projects,project)
        end
    end
    local savePath = configManager.GetValue("data_dir").."/manifests/"..owner.."/"..repo.."/"..branch..".json"
    fileManager.SaveJson(savePath,manifest)
    return manifest
end

githubApiHandler.downloadProject = function(manifest,projectName)
    textHelper.log("Downloading project "..projectName.." from "..manifest.owner.."/"..manifest.repo.."/"..manifest.branch, "githubApiHandler.downloadProject",false)
    local project = nil
    for _,v in ipairs(manifest.projects) do
        if v.manifest.name == projectName then
            project = v
            break
        end
    end
    if project == nil then
        return nil, "Project not found"
    end
    local tree = githubApiHandler.Gettree(manifest.owner,manifest.repo,manifest.branch)
    for index, value in ipairs(project.manifest.files) do
        local pair = textHelper.splitString(value,"=")
        local hostPath = pair[1]
        textHelper.log("Downloading "..hostPath.."( "..index.." of "..#project.manifest.files.." )", "githubApiHandler.downloadProject",false)
        local remotePath = pair[2]
        if textHelper.startsWith(remotePath,"/") then
            remotePath = remotePath:sub(2)
        end
        local file = nil
        for _,v in ipairs(tree.tree) do
            if v.path == remotePath then
                file = v
                break
            end
        end
        if file == nil then
            return nil, "File not found"
        end
        local content = GetFile64(file.url)
        fileManager.SaveFile(hostPath,content)
    end
    --if the project has an installer, download it
    if project.manifest.installer ~= nil then
        local target = project.manifest.installer
        if textHelper.startsWith(target,"/") then
            target = target:sub(2)
        end
        local installer = nil
        for _,v in ipairs(tree.tree) do
            if v.path == target then
                installer = v
                break
            end
        end
        if installer == nil then
            return nil, "Installer not found"
        end
        local content = GetFile64(installer.url)
        fileManager.SaveFile(configManager.GetValue("data_dir").."/tmp/installer.lua",content)
        shell.run(configManager.GetValue("data_dir").."/tmp/installer.lua","install")
        fileManager.Delete(configManager.GetValue("data_dir").."/tmp/installer.lua")
    end

    --update installed projects list
    local installedProjectsList = configManager.GetValue("installed_projects")
    local installedProjects = {}
    if fs.exists(installedProjectsList) then
        installedProjects = fileManager.LoadObject(installedProjectsList)
    end
    local projectID = manifest.owner.."/"..manifest.repo.."/"..manifest.branch.."/"..project.manifest.name
    table.insert(installedProjects,projectID)
    fileManager.SaveObject(installedProjectsList,installedProjects)
    textHelper.log("Project "..project.manifest.name.." installed", "githubApiHandler.downloadProject",false)
    return true
end

githubApiHandler.removeProject = function(manifest,projectName)
    textHelper.log("Removing project "..projectName.." from "..manifest.owner.."/"..manifest.repo.."/"..manifest.branch)
    local project = nil
    for _,v in ipairs(manifest.projects) do
        if v.manifest.name == projectName then
            project = v
            break
        end
    end
    if project == nil then
        return nil, "Project not found"
    end
    local installedProjects = githubApiHandler.getInstalledProjects()
    local projectID = manifest.owner.."/"..manifest.repo.."/"..manifest.branch.."/"..project.manifest.name
    if projectID == "hpf3/GithubDL/master/GithubDL" then
        return nil, "Cannot remove GithubDL automatically, please remove manually"
    end
    local found = false
    for _,v in ipairs(installedProjects) do
        if v == projectID then
            found = true
            break
        end
    end
    if not found then
        return nil, "Project not installed"
    end
    --if the project has an installer, run it with the remove argument
    if project.manifest.installer ~= nil then
        local tree = githubApiHandler.Gettree(manifest.owner,manifest.repo,manifest.branch)
        local target = project.manifest.installer
        if textHelper.startsWith(target,"/") then
            target = target:sub(2)
        end
        local installer = nil
        for _,v in ipairs(tree.tree) do
            if v.path == target then
                installer = v
                break
            end
        end
        if installer == nil then
            return nil, "Installer not found"
        end
        local content = GetFile64(installer.url)
        fileManager.SaveFile(configManager.GetValue("data_dir").."/tmp/installer.lua",content)
        shell.run(configManager.GetValue("data_dir").."/tmp/installer.lua","remove")
        fileManager.Delete(configManager.GetValue("data_dir").."/tmp/installer.lua")
    end
    --remove the files
    for index, value in ipairs(project.manifest.files) do
        local pair = textHelper.splitString(value,"=")
        local hostPath = pair[1]
        textHelper.log("Removing "..hostPath.."( "..index.." of "..#project.manifest.files.." )")
        fileManager.Delete(hostPath)
    end
    --update installed projects list
    local installedProjectsList = configManager.GetValue("installed_projects")
    local installedProjects = fileManager.LoadObject(installedProjectsList)
    local projectID = manifest.owner.."/"..manifest.repo.."/"..manifest.branch.."/"..project.manifest.name
    for i=1,#installedProjects do
        if installedProjects[i] == projectID then
            table.remove(installedProjects,i)
            break
        end
    end
    fileManager.SaveObject(installedProjectsList,installedProjects)
    textHelper.log("Project "..project.manifest.name.." removed")
    return true
end


--local functions
githubApiHandler.getRepoManifests = function()
    local manifestDir = configManager.GetValue("data_dir").."/manifests"
    if not fs.exists(manifestDir) then
        fs.makeDir(manifestDir)
        return {}
    end
    local manifests = fileManager.GetFilesRecursive(manifestDir)
    return manifests
end

githubApiHandler.getRepoManifest = function(owner,repo,branch)
    local manifestDir = configManager.GetValue("data_dir").."/manifests"
    local manifestPath = manifestDir.."/"..owner.."/"..repo.."/"..branch..".json"
    if not fs.exists(manifestPath) then
        return nil, "Manifest not found"
    end
    return fileManager.LoadJson(manifestPath)
end

githubApiHandler.getInstalledProjects = function()
    local installedProjectsList = configManager.GetValue("installed_projects")
    if installedProjectsList == nil then
        return {}
    end
    return fileManager.LoadObject(installedProjectsList)
end

githubApiHandler.getAvailableProjects = function()
    local manifests = githubApiHandler.getRepoManifests()
    local availableProjects = {}
    for _,v in ipairs(manifests) do
        local manifest = fileManager.LoadJson(v)
        for _,v in ipairs(manifest.projects) do
            table.insert(availableProjects,manifest.owner.."/"..manifest.repo.."/"..manifest.branch.."/"..v.manifest.name)
        end
    end
    return availableProjects
end

--misc functions

--parses a github url starting with https://github.com
local function parseBrowser(url)
    local parts = textHelper.splitString(url,"/")
    local owner = parts[4]
    local repo = parts[5]
    if textHelper.endsWith(repo,".git") then
        repo = repo:sub(1,#repo-4)
    end
    if parts[6] == "tree" then
        return owner,repo,parts[7]
    end
    return owner,repo
end

--parses a github url starting with git@github.com:
local function parseSSH(url)
    local parts = textHelper.splitString(url,":")
    local ownerRepoParts = textHelper.splitString(parts[2],"/")
    local owner = ownerRepoParts[1]
    local repo = ownerRepoParts[2]
    if textHelper.endsWith(repo,".git") then
        repo = repo:sub(1,#repo-4)
    end
    return owner,repo
end

githubApiHandler.getRepoFromUrl = function(url)
    if textHelper.startsWith(url,"https://github.com") then
        return parseBrowser(url)
    elseif textHelper.startsWith(url,"git@github.com:") then
        return parseSSH(url)
    end
    return nil, "Invalid url"
end


return githubApiHandler