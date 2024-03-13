--method holder (to work around sequential function loading)
local this = {}

--api holder
local libs = {}

--======================
--=  Type Definitions  =
--======================
--#region TypeDefinitions

---@alias FuncArgs string[]

--#endregion TypeDefinitions
--=======================
--=  Utility Functions  =
--=======================
--#region UtilityFunctions

---loads needed libs into the libs var
this.loadLibs = function ()
    ---@module "GithubDL.libs.libManager"
    local libManager = require("libs.GithubDL.libManager")
    libs.base64 = libManager.getBase64()
    libs.configManager = libManager.getConfigManager()
    libs.fileManager = libManager.getFileManager()
    libs.apiHandler = libManager.getApiHandler()
    libs.httpManager = libManager.gethttpManager()
    libs.textHelper = libManager.gettextHelper()
end
this.loadLibs()
---writes a message to stdout and writes it to the main log file
---@param message string
this.log = function(message)
    libs.textHelper.log(message)
end


---finds the first matching repo manifest and project name for the provided ID
---ID is in the format of: owner.repo.branch.name, owner.repo.name, or name
---@param ID string
---@return RepoManifest? manifest
---@return Project | string project | error
this.findProject = function(ID)
    local apiHandler = libs.apiHandler
    local textHelper = libs.textHelper
    textHelper.log("searching for: " .. ID, "search", true)
    local name, owner, repo, branch = nil, nil, nil, nil
    --check if the ID is a '.' separated string, if so, split it
    if ID:find("%.") then
        local parts = textHelper.splitString(ID, "%.")
        textHelper.log("parts: " .. #parts, "search", true)
        --BUG if the ID is in the format owner.repo.branch we won't be able to tell
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
            this.log("Invalid ID, must be in the format owner.repo.branch.name, owner.repo.name, or name")
            return nil, "Invalid ID"
        end
    else
        name = ID
        branch = ""
    end
    textHelper.log("owner: " .. owner, "search", true)
    textHelper.log("repo: " .. repo, "search", true)
    textHelper.log("branch: " .. branch, "search", true)
    textHelper.log("name: " .. name, "search", true)
    local availProjects = apiHandler.getAvailableProjects()
    if #availProjects == 0 then
        return nil, "No manifests found"
    end
    textHelper.log("found " .. #availProjects .. " available projects", "search", true)
    local prefix = ""
    if owner ~= nil then
        --FIXME for some reason, branch is not being set correctly
        prefix = owner .. "/" .. repo .. "/" .. branch
    end
    textHelper.log("prefix: " .. prefix, "search", true)
    for _, value in ipairs(availProjects) do
        textHelper.log("checking: " .. value, "search", true)
        if textHelper.startsWith(value, prefix) then
            textHelper.log("found: " .. value, "search", true)
            local parts = textHelper.splitString(value, "/")
            local manifest = apiHandler.getRepoManifest(parts[1], parts[2], parts[3])
            for _, project in ipairs(manifest.projects) do
                textHelper.log("checking: " .. project.name, "search", true)
                if project.name == name then
                    textHelper.log("Project found", "search", true)
                    return manifest, project
                end
            end
        end
    end
    textHelper.log("Project not found", "search", false)
    return nil, "Project not found"
end
--#endregion UtilityFunctions



--=======================
--=  Command Functions  =
--=======================
--#region CommandFunctions



this.startup = function()
    local configManager = libs.configManager

    --dir setup
    if not fs.exists(configManager.GetValue("data_dir")) then
        fs.makeDir(configManager.GetValue("data_dir"))
    end
    if not fs.exists(configManager.GetValue("log_dir")) then
        fs.makeDir(configManager.GetValue("log_dir"))
    end
    --config init
    configManager.SetConfig(configManager.GetConfig()) -- if the file does not exist, this will create it

    --api token warning
    if configManager.GetValue("api_token") == nil then
        this.log(
        "No API token set, use 'GithubDL setToken <token>' to set one, api requests will be more limited without one")
    end

    --update
    if configManager.GetValue("auto_update") == "true" then
        local result, msg = this.update({}, true, false)
        if result > 0 then
            this.log("Updates needed: " .. result)
        end
        if msg then
            this.log("An error occured while getting updates: " .. msg)
        end
    end
end




this.addRepo = function(funcArgs)
    local apiHandler = libs.apiHandler

    local url = funcArgs[1]
    local owner, repo, branch = apiHandler.getRepoFromUrl(url)
    if owner == nil or repo == nil then
        this.log("Invalid url")
        return
    end
    if funcArgs[2] ~= nil then
        branch = funcArgs[2]
    end

    local manifest, msg = apiHandler.downloadManifest(owner, repo, branch)
    if manifest == nil then
        this.log("Failed to download manifest: " .. msg)
        return
    end
    this.log("repo manifest downloaded ( " .. manifest.owner .. "/" .. manifest.repo .. "/" .. manifest.branch .. ")")
end




---@diagnostic disable-next-line: unused-local
this.delRepo = function(funcArgs)
    --TODO: Implement
end




this.list = function(funcArgs)
    local apiHandler = libs.apiHandler
    local textHelper = libs.textHelper
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




this.install = function(funcArgs)
    local apiHandler = libs.apiHandler
    local textHelper = libs.textHelper

    local ID = funcArgs[1]
    if ID == nil then
        this.log("No ID provided")
        return
    end
    textHelper.log("Installing: " .. ID)
    local manifest, name = this.findProject(ID)
    if manifest == nil then
        textHelper.log("Failed to find project: " .. name, "install", false)
        return
    end
    local sucsess, msg = apiHandler.downloadProject(manifest, name.name)
    if not sucsess then
        textHelper.log("Failed to download project: " .. msg, "install", false)
        return
    end
end



---updates the manifest and optionally upgrades all outdated projects
---@param funcArgs FuncArgs
---@param quiet boolean?
---@param upgrade boolean?
---@return number
---@return string?
this.update = function(funcArgs, quiet, upgrade)
    local apiHandler = libs.apiHandler
    local textHelper = libs.textHelper

    if quiet == nil then
        quiet = false
    end
    if upgrade == nil then
        upgrade = false
    end
    if funcArgs == nil then
        funcArgs = {}
    end

    local manifest, name = nil, nil
    local ID = funcArgs[1]
    local updatesNeeded = 0
    --single project update
    if ID ~= nil then
        manifest, name = this.findProject(ID)
        if manifest == nil then
            textHelper.log("Failed to find project: " .. name, "update", quiet)
            return 0, "Failed to find project: " .. name
        end
        local commit, msg = apiHandler.getLatestCommit(manifest.owner, manifest.repo, manifest.branch)
        if commit == nil then
            return 0, msg
        end
        if manifest.last_commit == commit.sha then
            textHelper.log("manifest is up to date", "update", quiet)
        else
            textHelper.log(
            "updating manifest (" .. manifest.owner .. "/" .. manifest.repo .. "/" .. manifest.branch .. ")", "update",false)
            local manifest, msg = apiHandler.downloadManifest(manifest.owner, manifest.repo, manifest.branch)
            if manifest == nil then
                textHelper.log("Failed to update manifest: " .. msg, "update", quiet)
                return 0, msg
            end
            local outdatedProjects = apiHandler.getOutOfDateProjects()
            for _, project in ipairs(outdatedProjects) do
                if project.owner == manifest.owner and project.repo == manifest.repo and project.branch == manifest.branch and project.last_commit ~= manifest.last_commit then
                    updatesNeeded = updatesNeeded + 1
                    if upgrade then
                        --FIXME this should be doing a single project update, not a full manifest update
                        textHelper.log("updating project: " .. project.name, "update", quiet)
                        local sucsess, msg = apiHandler.downloadProject(manifest, project.name, quiet)
                        if not sucsess then
                            textHelper.log("Failed to update project: " .. msg, "update", quiet)
                        else
                            updatesNeeded = updatesNeeded - 1
                            textHelper.log("Project updated: " .. project.name, "update", quiet)
                        end
                    end
                end
            end
        end
    else
        --all manifests update
        
        local manifests = apiHandler.getRepoManifests()
        for _, manifestPath in ipairs(manifests) do
            local manifest,msg = apiHandler.getRepoManifestFromPath(manifestPath)
            if manifest == nil then
                return 0, msg
            end
            --FIXME the single project update mode expects a project id, not a manifest id
            local id = manifest.owner .. "." .. manifest.repo .. "." .. manifest.branch
            local result, _ = this.update({ id }, quiet, upgrade)
            if result > 0 then
                updatesNeeded = updatesNeeded + result
            end
        end
    end
    if updatesNeeded == 0 then
        textHelper.log("All projects are up to date", "update", quiet)
    else
        textHelper.log("Updates needed: " .. updatesNeeded, "update", quiet)
    end
    return updatesNeeded
end




this.remove = function(funcArgs)
    local apiHandler = libs.apiHandler
    local textHelper = libs.textHelper

    local ID = funcArgs[1]
    if ID == nil then
        this.log("No ID provided")
        return
    end
    textHelper.log("Uninstalling: " .. ID)

    local manifest, name = this.findProject(ID)
    if manifest == nil then
        textHelper.log("Failed to find project: " .. name, "install", false)
        return
    end

    local installedProjects = apiHandler.getInstalledProjects()

    ---@type ProjectDefinition
    local targetProject = nil
    for _, project in ipairs(installedProjects) do
        if apiHandler.areProjectsSame(name,project) then
            targetProject = project
        end
    end
    local sucsess, msg = apiHandler.removeProject(targetProject)
    if not sucsess then
        textHelper.log("Failed to remove project: " .. msg, "install", false)
        return
    end
end


local function setToken(funcArgs)
    local configManager = libs.configManager
    local token = funcArgs[1]
    if token == nil then
        this.log("No token provided")
        return
    end
    configManager.SetValue("api_token", token)
    this.log("Token set")
end


this.help = function (funcArgs)
    --HACK Implement better to provide context for each command
    this.log("Usage: GithubDL <command> [args]")
    this.log("Commands:")
    for key, _ in pairs(this.SWITCH_Commands) do
        this.log(key)
    end
end
--#endregion CommandFunctions



--=====================
--=    Data Tables    =
--=====================


---@type table<string, fun(FuncArgs):any?,string?>
this.SWITCH_Commands = {
    ["startup"] = this.startup,
    ["addRepo"] = this.addRepo,
    ["delRepo"] = this.delRepo,
    ["list"] = this.list,
    ["install"] = this.install,
    ["update"] = this.update,
    ["upgrade"] = function(args)
        return this.update(args, false, true)
    end,
    ["remove"] = this.remove,
    ["help"] = this.help,
    ["setToken"] = setToken
}


--Main program
local info = debug.getinfo(1)
if info.name ~= nil then
    if info.name == "?" then
        return this.SWITCH_Commands
    end
end



local args = { ... }
local command = table.remove(args, 1)
local commandArgs = args

if command ~= nil then
    if this.SWITCH_Commands[command] then
        local _, msg = this.SWITCH_Commands[command](commandArgs)
        if msg then
            this.log(msg)
        end
    else
        this.log("Invalid command: '"..command.."', use 'GithubDL help' for help")
    end
end

