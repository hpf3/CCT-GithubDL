
--utility functions
local function log(message)
    print("[GithubDL] "..message)
end

--split based on a pattern
local function split(str, pat)
    local t = {}  -- NOTE: use {n = 0} in Lua-5.0
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
       if s ~= 1 or cap ~= "" then
          table.insert(t, cap)
       end
       last_end = e+1
       s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
       cap = str:sub(last_end)
       table.insert(t, cap)
    end
    return t
 end

 -- test if a string starts with a prefix
local function startsWith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

local function setPath()
    local libsPath = "/libs"
    local pathEndings = {
        "/?",
        "/?.lua",
        "/?/init.lua"
    }
    
    local basePath = package.path
    local paths = split(basePath,";")
    local newpaths = {}
    --add all existing paths to newpaths, unless they start with the libsPath
    for _, v in ipairs(paths) do
        if not startsWith(v,libsPath) then
            table.insert(newpaths, v)
        end
    end
    --add the new paths
    for _, v in ipairs(pathEndings) do
        table.insert(newpaths, libsPath..v)
    end
    --set the new path
    package.path = table.concat(newpaths, ";")
end



local function findProject(ID)
    setPath()
    local libManager = require("GithubDL.libManager")
    local apiHandler = libManager.getApiHandler()
    local textHelper = libManager.gettextHelper()
    local name, owner, repo, branch = nil,nil,nil,nil
    --check if the ID is a '.' separated string, if so, split it
    if ID:find("%.") then
        parts = textHelper.splitString(ID, "%.")
        if #parts == 4 then
            owner = parts[1]
            repo = parts[2]
            branch = parts[3]
            name = parts[4]
        elseif #parts == 3 then
            owner = parts[1]
            repo = parts[2]
            name = parts[3]
        else
            log("Invalid ID, must be in the format owner.repo.branch.name, owner.repo.name, or name")
            return
        end
    else
        name = ID
        branch = ""
    end
    local manifests = apiHandler.getAvailableProjects()
    textHelper.log("found "..#manifests.." manifests", "search", true)
    local prefix = ""
    if owner ~= nil then
        prefix = owner.."/"..repo.."/"..branch
    end
    textHelper.log("prefix: "..prefix, "search", true)
    for _, value in ipairs(manifests) do
        textHelper.log("checking: "..value, "search", true)
        if textHelper.startsWith(value, prefix) then
            textHelper.log("found: "..value, "search", true)
            local parts = textHelper.splitString(value, "/")
            local manifest = apiHandler.getRepoManifest(parts[1], parts[2], parts[3])
            for _, project in ipairs(manifest.projects) do
                textHelper.log("checking: "..project.manifest.name, "search", true)
                if project.manifest.name == name then
                    textHelper.log("Project found", "search", true)
                    return manifest, project.manifest.name
                end
            end
        end
    end
    textHelper.log("Project not found", "search", false)
    return nil, "Project not found"
end


--main functions
local function startup()
    setPath()
    --TODO: Verify that needed files and folders exist, then perform updates
    local libManager = require("GithubDL.libManager")
    local configManager = libManager.getConfigManager()

    --dir setup
    if not fs.exists(configManager.GetValue("data_dir"))  then
        fs.makeDir(configManager.GetValue("data_dir"))
    end
    if not fs.exists(configManager.GetValue("log_dir"))  then
        fs.makeDir(configManager.GetValue("log_dir"))
    end
    if not fs.exists(configManager.GetValue("lib_dir"))  then
        fs.makeDir(configManager.GetValue("lib_dir"))
    end
    --config init
    configManager.SetConfig(configManager.GetConfig()) -- if the file does not exist, this will create it

end


local function addRepo(funcArgs)
    setPath()
    local libManager = require("GithubDL.libManager")
    local apiHandler = libManager.getApiHandler()

    local url = funcArgs[1]
    local owner, repo, branch = apiHandler.getRepoFromUrl(url)
    if owner == nil or repo == nil then
        log("Invalid url")
        return
    end
    if funcArgs[2] ~= nil then
        branch = funcArgs[2]
    end

    local manifest,msg = apiHandler.downloadManifest(owner,repo,branch)
    if manifest == nil then
        log("Failed to download manifest: "..msg)
        return
    end
    log("repo manifest downloaded ( "..manifest.owner.."/"..manifest.repo.."/"..manifest.branch..")")
end
local function delRepo(funcArgs)
    setPath()
    --TODO: Implement
end
local function list(funcArgs)
    setPath()
    local libManager = require("GithubDL.libManager")
    local apiHandler = libManager.getApiHandler()
    local textHelper = libManager.gettextHelper()
    local projects = {}
    if funcArgs[1] == "installed" then
        projects = apiHandler.getInstalledProjects()
    else
        projects = apiHandler.getAvailableProjects()
    end
    if #projects == 0 then
        textHelper.log("No projects found")
    end
    textHelper.PrettyPrint(projects)
end


local function install(funcArgs)
    setPath()
    local libManager = require("GithubDL.libManager")
    local apiHandler = libManager.getApiHandler()
    local textHelper = libManager.gettextHelper()

    local ID = funcArgs[1]
    if ID == nil then
        log("No ID provided")
        return
    end
    textHelper.log("Installing: "..ID)
    local manifest, name = findProject(ID)
    if manifest == nil then
        textHelper.log("Failed to find project: "..name, "install", false)
        return
    end
    local sucsess,msg = apiHandler.downloadProject(manifest,name)
    if not sucsess then
        textHelper.log("Failed to download project: "..msg, "install", false)
        return
    end
end
local function update(funcArgs)
    setPath()
    --TODO: Implement
end
local function remove(funcArgs)
    setPath()
    local libManager = require("GithubDL.libManager")
    local apiHandler = libManager.getApiHandler()
    local textHelper = libManager.gettextHelper()

    local ID = funcArgs[1]
    if ID == nil then
        log("No ID provided")
        return
    end
    textHelper.log("Installing: "..ID)
    local manifest, name = findProject(ID)
    if manifest == nil then
        textHelper.log("Failed to find project: "..name, "install", false)
        return
    end
    local sucsess,msg = apiHandler.removeProject(manifest,name)
    
end
local function setToken(funcArgs)
    setPath()
    local libManager = require("GithubDL.libManager")
    local configManager = libManager.getConfigManager()
    local token = funcArgs[1]
    if token == nil then
        log("No token provided")
        return
    end
    configManager.SetValue("api_token", token)
    log("Token set")
end


--Main program
local args = {...}
if #args < 1 then
    log("use 'githubdl help' for help")
    return
end
local command = table.remove(args, 1)
local commandArgs = args

local SWITCH_Commands = {
    ["startup"] = startup,
    ["addRepo"] = addRepo,
    ["delRepo"] = delRepo,
    ["list"] = list,
    ["install"] = install,
    ["update"] = update,
    ["remove"] = remove,
    ["help"] = help,
    ["setToken"] = setToken
}

if SWITCH_Commands[command] then
    SWITCH_Commands[command](commandArgs)
else
    log("Invalid command")
end

return SWITCH_Commands