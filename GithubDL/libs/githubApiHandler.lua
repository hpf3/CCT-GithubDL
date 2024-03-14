--======================
--=  Type Definitions  =
--======================
--#region TypeDefinitions

--RepoManifest

--- @alias FileMapping string Format is "/local/path=remote/path"

--- @class (exact) Project
--- @field sha string
--- @field path string
--- @field description string The projects description, unused, but may be seen by the user at some point
--- @field name string The ID of the project, should be unique, simple ID searching returns the first match found
--- @field files FileMapping[] list of strings representing the needed remote files and where they go locally
--- @field installer string? optional, a lua script that will be ran to install/uninstall the program. mode set by arg1 being "install" or "remove". script is ran last on install and first on uninstall

--- @class (exact) RepoManifest
--- @field branch string the name of the branch/tag
--- @field repo string the name of the repository
--- @field projects Project[] list representing the manifest files found in the repo
--- @field last_commit string the sha(hash) of the commit at the time the manifest was last updated
--- @field owner string the name of the owner of the repository

--InstalledProjects
--- @class (exact) ProjectDefinition
--- @field owner string the owner of the repository
--- @field repo string the name of the repository
--- @field branch string the branch/tag of the repository
--- @field last_commit string the sha(hash) of the commit at the time the project was last updated
--- @field name string the name/id of the project

--- @alias InstalledProjects ProjectDefinition[]



--partial definition of the commit response object
--- @class (exact) CommitResponse
--- @field sha string the sha(hash) of the commit

--partial definition of the tree response object
--- @class (exact) TreeResponse
--- @field sha string the sha(hash) of the tree
--- @field url string the url of the tree
--- @field tree FileObject[] list of tree objects

--partial definition of the file object
--- @class (exact) FileObject
--- @field path string the path of the file
--- @field type string the type of the file, can be "blob" or "tree"
--- @field url string the download url of the file
--#endregion TypeDefinitions

--==============
--=  Requires  =
--==============
--#region Requires

---@module "GithubDL.libs.libManager"
local libManager = require("libs.GithubDL.libManager")

---@module "GithubDL.libs.configManager"
local configManager = libManager.getConfigManager()

---@module "GithubDL.libs.textHelper"
local textHelper = libManager.gettextHelper()

---@module "GithubDL.libs.fileManager"
local fileManager = libManager.getFileManager()

---@module "GithubDL.libs.base64"
local base64 = libManager.getBase64()

---@module "GithubDL.libs.httpManager"
local httpManager = libManager.gethttpManager()
--#endregion Requires

--============
--=  Config  =
--============
--#region Config
local ApiUrl = "https://api.github.com"
local manifestExtension = ".GDLManifest"

---@class GithubApiHandler
local githubApiHandler = {}
--#endregion Config

--======================
--=  Remote Utilities  =
--======================
--#region Utilities

---gets the file blob at the url and decodes it into a string
---@param url string should be a github file blob url
---@return string? decodeResult the result of decoding the file
---@return string? error the error message, if any
local function GetFile64(url)
    local response, error = httpManager.SendHttpGET(url)
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


---gets the github tree of the provided repo, uses recursive mode
---@param owner string the owner of the repo
---@param repo string the repo
---@param branch string the branch/tag/commitSha
---@return TreeResponse? apiResult deserialized result directly from the github api
---@return string? error the error message, if any
githubApiHandler.Gettree = function(owner, repo, branch)
    if branch == nil or branch == "" then
        return nil, "No branch provided"
    end
    local url = ApiUrl .. "/repos/" .. owner .. "/" .. repo .. "/git/trees/" .. branch .. "?recursive=1"
    local response, error = httpManager.SendHttpGET(url)
    if response == nil then
        return nil, error
    end
    return textutils.unserializeJSON(response.body)
end


---gets basic repo info
---@param owner string the owner of the repo
---@param repo string the repo
---@return any? apiResult deserialized result directly from the github api
---@return string? error the error message, if any
githubApiHandler.getRepoInfo = function(owner, repo)
    local url = ApiUrl .. "/repos/" .. owner .. "/" .. repo
    local response, error = httpManager.SendHttpGET(url)
    if response == nil then
        return nil, error
    end

    return textutils.unserializeJSON(response.body)
end



---gets the latest commit
---@param owner string the owner of the repo
---@param repo string the repo
---@param branch string the branch/tag
---@return CommitResponse? apiResult deserialized result directly from the github api
---@return string? error the error message, if any
githubApiHandler.getLatestCommit = function(owner, repo, branch)
    local url = ApiUrl .. "/repos/" .. owner .. "/" .. repo .. "/commits/" .. branch
    local headers = {
        ["per_page"] = "1"
    }
    local response, error = httpManager.SendHttpGET(url, headers)
    if response == nil then
        return nil, error
    end
    return textutils.unserializeJSON(response.body)
end
--#endregion Utilities

--========================
--=  Download Functions  =
--========================
--#region Download



---downloads and saves the repository Manifest
---@param owner string the owner of the repo
---@param repo string the repo
---@param branch string the branch/tag
---@param save boolean? whether or not to save the manifest, default: true
---@return RepoManifest? repoManifest the manifest that was downloaded and saved
---@return string? error the error message, if any
githubApiHandler.downloadManifest = function(owner, repo, branch, save)
    local repoData, msg = githubApiHandler.getRepoInfo(owner, repo)
    if save == nil then
        save = true
    end
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

    --check if we already have a copy of the manifest
    local oldManifest = githubApiHandler.getRepoManifest(owner, repo, branch)
    local commit, msg = githubApiHandler.getLatestCommit(owner, repo, branch)
    if commit == nil then
        return nil, msg
    end
    manifest.last_commit = commit.sha
    if oldManifest ~= nil then
        if oldManifest.last_commit == manifest.last_commit then
            return oldManifest
        end
    end

    textHelper.log("Downloading manifest for " .. manifest.owner .. "/" .. manifest.repo .. "/" .. manifest.branch,
        "githubApiHandler.downloadManifest", false)
    local tree, error = githubApiHandler.Gettree(owner, repo, branch)
    if tree == nil then
        return nil, error
    end
    local count = 0
    local files = {}
    for i = 1, #tree.tree do
        local file = tree.tree[i]
        --check if item is file
        if file.type == "blob" then
            if textHelper.endsWith(file.path, manifestExtension) then
                files[file.path] = file
                count = count + 1
            end
        end
    end
    textHelper.log("Found " .. count .. " projects", "githubApiHandler.downloadManifest", false)
    manifest.projects = {}
    for k, v in pairs(files) do
        local project = {}
        project.path = k
        project.sha = v.sha
        --download the file
        local content = GetFile64(v.url)
        if content == nil then
            return nil, error
        end
        --content = textHelper.flatten(content)
        local manifestData, msg = textutils.unserializeJSON(content)
        if manifestData == nil then
            textHelper.log("Failed to parse manifest: " .. project.path)
            textHelper.log("Failed content: " .. content, "githubApiHandler.downloadManifest", true)
            textHelper.log("Failed reason: " .. msg, "githubApiHandler.downloadManifest", true)
        else
            textHelper.log("found project: " .. manifestData.name, "githubApiHandler.downloadManifest", true)
            for k, v in pairs(manifestData) do
                project[k] = v
            end
            table.insert(manifest.projects, project)
        end
    end
    if save then
        local savePath = configManager.GetValue("data_dir") ..
            "/manifests/" .. owner .. "/" .. repo .. "/" .. branch .. ".json"
        fileManager.SaveJson(savePath, manifest)
    end
    return manifest
end



---installs the given project
---@param projectDef ProjectDefinition definition of the project to download
---@param quiet boolean? whether or not to write to the console, default: false
---@return boolean? didComplete returns true if it finishes, nil otherwise
---@return string|nil error returns the error, if any
githubApiHandler.downloadProject = function(projectDef, quiet)
    if quiet == nil then
        quiet = false
    end
    local manifest, msg = githubApiHandler.getRepoManifestFromPath(configManager.GetValue("data_dir") .. "/manifests/" .. projectDef.owner .. "/" .. projectDef.repo .. "/" .. projectDef.branch .. ".json")
    if manifest == nil then
        manifest, msg = githubApiHandler.downloadManifest(projectDef.owner, projectDef.repo, projectDef.branch)
        if manifest == nil then
            return nil, msg
        end
    end
    textHelper.log(
        "Downloading project " ..
        projectDef.name .. " from " .. manifest.owner .. "/" .. manifest.repo .. "/" .. manifest.branch,
        "githubApiHandler.downloadProject", false)

    ---@type Project
    local project = nil
    for _, v in ipairs(manifest.projects) do
        if v.name == projectDef.name then
            project = v
            break
        end
    end
    if project == nil then
        return nil, "Project not found"
    end
    local tree = githubApiHandler.Gettree(manifest.owner, manifest.repo, manifest.last_commit)
    for index, value in ipairs(project.files) do
        local pair = textHelper.splitString(value, "=")
        local hostPath = pair[1]
        textHelper.log("Downloading " .. hostPath .. "( " .. index .. " of " .. #project.files .. " )",
            "githubApiHandler.downloadProject", quiet)
        local remotePath = pair[2]
        if textHelper.startsWith(remotePath, "/") then
            remotePath = remotePath:sub(2)
        end
        local file = nil
        for _, v in ipairs(tree.tree) do
            if v.path == remotePath then
                file = v
                break
            end
        end
        if file == nil then
            return nil, "File not found"
        end
        local content = GetFile64(file.url)
        fileManager.SaveFile(hostPath, content)
    end
    --if the project has an installer, download it
    if project.installer ~= nil then
        local target = project.installer
        if textHelper.startsWith(target, "/") then
            target = target:sub(2)
        end
        local installer = nil
        for _, v in ipairs(tree.tree) do
            if v.path == target then
                installer = v
                break
            end
        end
        if installer == nil then
            return nil, "Installer not found"
        end
        local content = GetFile64(installer.url)
        fileManager.SaveFile(configManager.GetValue("data_dir") .. "/tmp/installer.lua", content)
        shell.run(configManager.GetValue("data_dir") .. "/tmp/installer.lua", "install")
        fileManager.Delete(configManager.GetValue("data_dir") .. "/tmp/installer.lua")
    end

    --update installed projects list
    local installedProjects = githubApiHandler.getInstalledProjects()
    ---@type ProjectDefinition
    local newProject = {
        owner = manifest.owner,
        repo = manifest.repo,
        branch = manifest.branch,
        last_commit = manifest.last_commit,
        name = project.name
    }
    --check if the project is already installed
    local found = false
    if installedProjects == nil then
        installedProjects = {}
    else
        for k, v in ipairs(installedProjects) do
            if v.owner == newProject.owner and v.repo == newProject.repo and v.branch == newProject.branch and v.name == newProject.name then
                installedProjects[k] = newProject
                found = true
            end
        end
    end
    if not found then
        table.insert(installedProjects, newProject)
    end
    fileManager.SaveObject(configManager.GetValue("installed_projects"), installedProjects)
    textHelper.log("Project " .. project.name .. " installed", "githubApiHandler.downloadProject", quiet)
    return true
end
--#endregion Download

--=====================
--=  Removal Methods  =
--=====================
--#region Delete

---removes the given project from the computer
---@param project ProjectDefinition the project to remove
---@return boolean? didComplete returns true if it finishes, nil otherwise
---@return string|nil error returns the error, if any
githubApiHandler.removeProject = function(project)
    textHelper.log("Removing project " ..
        project.name .. " from " .. project.owner .. "/" .. project.repo .. "/" .. project.branch)
    local tree = githubApiHandler.Gettree(project.owner, project.repo, project.last_commit)
    ---@type Project
    local manifest = nil
    --scan the tree for the project definition
    for _, file in ipairs(tree.tree) do
        if file.type == "blob" and textHelper.endsWith(file.path, manifestExtension) then
            local content = GetFile64(file.url)
            ---@type Project
            local tmpManifest = textutils.unserializeJSON(content)
            if tmpManifest ~= nil then
                if tmpManifest.name == project.name then
                    manifest = tmpManifest
                end
            end
        end
    end
    if manifest == nil then
        return nil, "Project manifest not found"
    end
    local projectID = project.owner .. "/" .. project.repo .. "/" .. project.branch .. "/" .. project.name
    if projectID == "hpf3/GithubDL/master/GithubDL" then
        return nil, "Cannot remove GithubDL automatically, please remove manually"
    end
    --if the project has an installer, run it with the remove argument
    if manifest.installer ~= nil then
        local target = manifest.installer
        if textHelper.startsWith(target, "/") then
            target = target:sub(2)
        end
        local installer = nil
        for _, v in ipairs(tree.tree) do
            if v.path == target then
                installer = v
                break
            end
        end
        if installer == nil then
            return nil, "Installer not found"
        end
        local content = GetFile64(installer.url)
        fileManager.SaveFile(configManager.GetValue("data_dir") .. "/tmp/installer.lua", content)
        shell.run(configManager.GetValue("data_dir") .. "/tmp/installer.lua", "remove")
        fileManager.Delete(configManager.GetValue("data_dir") .. "/tmp/installer.lua")
    end
    --remove the files
    for index, value in ipairs(manifest.files) do
        local pair = textHelper.splitString(value, "=")
        local hostPath = pair[1]
        textHelper.log("Removing " .. hostPath .. "( " .. index .. " of " .. #manifest.files .. " )")
        fileManager.Delete(hostPath)
    end
    --update installed projects list
    local installedProjects = githubApiHandler.getInstalledProjects()
    for i = 1, #installedProjects do
        if githubApiHandler.areProjectsSame(installedProjects[i], project) then
            table.remove(installedProjects, i)
            break
        end
    end
    fileManager.SaveObject(configManager.GetValue("installed_projects"), installedProjects)
    textHelper.log("Project " .. manifest.name .. " removed")
    return true
end

--#endregion Delete

--=====================
--=  Local Functions  =
--=====================
--#region Local

---gets a list of all the manifest files in the data directory
---@return string[] manifestList list of strings representing the paths to the manifest files
githubApiHandler.getRepoManifests = function()
    local manifestDir = configManager.GetValue("data_dir") .. "/manifests"
    if not fs.exists(manifestDir) then
        fs.makeDir(manifestDir)
        return {}
    end
    local manifests = fileManager.GetFilesRecursive(manifestDir)
    return manifests
end

---gets the manifest for the given repo
---@param owner string
---@param repo string
---@param branch string
---@return nil|RepoManifest
---@return string
githubApiHandler.getRepoManifest = function(owner, repo, branch)
    local manifestDir = configManager.GetValue("data_dir") .. "/manifests"
    local manifestPath = manifestDir .. "/" .. owner .. "/" .. repo .. "/" .. branch .. ".json"
    if not fs.exists(manifestPath) then
        return nil, "Manifest not found"
    end
    return fileManager.LoadJson(manifestPath)
end
---gets the local manifest for the given repo
---@param path string
---@return RepoManifest? repoManifest the manifest that was found
---@return string? error the error message, if any
githubApiHandler.getRepoManifestFromPath = function(path)
    return fileManager.LoadJson(path)
end

---gets the list of installed projects
---@return InstalledProjects
githubApiHandler.getInstalledProjects = function()
    local installedProjectsList = configManager.GetValue("installed_projects")
    if installedProjectsList == nil then
        return {}
    end
    return fileManager.LoadObject(installedProjectsList)
end


---gets a list of all the available projects
---@return string[] availableProjects list of strings representing the available projects
githubApiHandler.getAvailableProjects = function()
    local manifests = githubApiHandler.getRepoManifests()
    if manifests == nil then
        manifests = {}
    end
    local availableProjects = {}
    for _, v in ipairs(manifests) do
        ---@type RepoManifest
        local manifest, msg = fileManager.LoadJson(v)
        if manifest == nil then
            textHelper.log("Failed to load manifest: " .. msg)
        else
            for _, v in ipairs(manifest.projects) do
                table.insert(availableProjects,
                    manifest.owner .. "/" .. manifest.repo .. "/" .. manifest.branch .. "/" .. v.name)
            end
        end
    end
    return availableProjects
end


---gets projects that are out of date
---@return ProjectDefinition[] outOfDateProjects list of projects that are out of date
githubApiHandler.getOutOfDateProjects = function()
    local installedProjects = githubApiHandler.getInstalledProjects()
    local outOfDateProjects = {}
    for _, v in ipairs(installedProjects) do
        local manifest = githubApiHandler.getRepoManifest(v.owner, v.repo, v.branch)
        if manifest == nil then
            --skip if the manifest is not found
            textHelper.log("Manifest not found for " .. v.owner .. "/" .. v.repo .. "/" .. v.branch)
        else
            if manifest.last_commit ~= v.last_commit then
                table.insert(outOfDateProjects, v)
            end
        end
    end
    return outOfDateProjects
end

--#endregion Local

--====================
--=  Misc Utilities  =
--====================
--#region Misc


---parses a github url starting with https://github.com
---@param url string
---@return string owner the owner of the repository
---@return string repo the name of the repository
---@return string? branch the branch/tag of the repository
local function parseBrowser(url)
    local parts = textHelper.splitString(url, "/")
    local owner = parts[4]
    local repo = parts[5]
    if textHelper.endsWith(repo, ".git") then
        repo = repo:sub(1, #repo - 4)
    end
    if parts[6] == "tree" then
        return owner, repo, parts[7]
    end
    return owner, repo
end

---parses a github url starting with git@github.com:
---@param url string
---@return string owner the owner of the repository
---@return string repo the name of the repository
local function parseSSH(url)
    local parts = textHelper.splitString(url, ":")
    local ownerRepoParts = textHelper.splitString(parts[2], "/")
    local owner = ownerRepoParts[1]
    local repo = ownerRepoParts[2]
    if textHelper.endsWith(repo, ".git") then
        repo = repo:sub(1, #repo - 4)
    end
    return owner, repo
end

---gets the owner and repo from a github url
---@param url string
---@return string? owner the owner of the repository
---@return string repo the name of the repository (if owner is nil, this is an error message)
---@return string? branch the branch/tag of the repository
githubApiHandler.getRepoFromUrl = function(url)
    if textHelper.startsWith(url, "https://github.com") then
        return parseBrowser(url)
    elseif textHelper.startsWith(url, "git@github.com:") then
        return parseSSH(url)
    end
    return nil, "Invalid url"
end

---tests if two projects are the same
---@param project1 ProjectDefinition
---@param project2 ProjectDefinition
---@return boolean areProjectsSame
githubApiHandler.areProjectsSame = function(project1, project2)
    return project1.owner == project2.owner and project1.repo == project2.repo and project1.branch == project2.branch and
        project1.name == project2.name
end
--#endregion Misc

return githubApiHandler
