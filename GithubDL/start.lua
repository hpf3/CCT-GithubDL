--method holder (to work around sequential function loading)
local this = {}


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

---@module "GithubDL.libs.libManager"
local libManager = require("libs.GithubDL.libManager")
local configManager = libManager.getConfigManager()
local apiHandler = libManager.getApiHandler()
local textHelper = libManager.gettextHelper()
---writes a message to stdout and writes it to the main log file
---@param message string
this.log = function(message)
    textHelper.log(message)
end


---finds the first matching repo manifest and project name for the provided ID
---ID is in the format of: owner.repo.branch.name, owner.repo.name, or name
---@param ID string
---@return RepoManifest? manifest
---@return Project? project
---@return string? errorMsg
this.findProject = function(ID)
    local apiHandler = apiHandler
    local textHelper = textHelper
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
            return nil, nil, "Invalid ID"
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
        return nil, nil, "No manifests found"
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
    return nil, nil, "Project not found"
end
--#endregion UtilityFunctions



--=======================
--=  Command Functions  =
--=======================
--#region CommandFunctions



this.startup = function()
    local configManager = configManager

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
    if configManager.GetValue("api_token") == "" then
        this.log(
            "No API token set, use 'GithubDL setToken <token>' to set one, api requests will be more limited without one")
    end

    --update
    if configManager.GetValue("auto_update") == "true" and configManager.GetValue("api_token") ~= "" then
        local result, msg = this.update({}, true)
        if result > 0 then
            this.log("Updates done: " .. result)
        else
            this.log("No updates done")
        end
        if msg then
            this.log("An error occured while getting updates: " .. msg)
        end
    end
end




this.addRepo = function(funcArgs)
    local apiHandler = apiHandler

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
    local apiHandler = apiHandler
    local textHelper = textHelper
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
    local apiHandler = apiHandler
    local textHelper = textHelper

    local ID = funcArgs[1]
    if ID == nil then
        this.log("No ID provided")
        return
    end
    textHelper.log("Installing: " .. ID)
    local manifest, project, msg = this.findProject(ID)
    if manifest == nil then
        textHelper.log("Failed to find project: " .. msg, "install", false)
        return
    end
    local projectDef = {
        name = project.name,
        owner = manifest.owner,
        repo = manifest.repo,
        branch = manifest.branch
    }
    local sucsess, msg = apiHandler.downloadProject(projectDef)
    if not sucsess then
        textHelper.log("Failed to download project: " .. msg, "install", false)
        return
    end
end



---Updates the manifests and updates any installed_projects.
---@param funcArgs FuncArgs -- here for positional argument consistency, not used
---@param quiet boolean? -- If true, minimizes the logging output
---@return number -- Number of updates performed
---@return string? -- Error message, if any
---@diagnostic disable-next-line: unused-local
this.update = function(funcArgs, quiet)
    local apiHandler = apiHandler
    local textHelper = textHelper

    if quiet == nil then quiet = false end

    local updatesDone = 0

    local manifests = apiHandler.getRepoManifests()
    if #manifests == 0 then
        return 0, "No manifests found"
    end
    for _, manifestPath in ipairs(manifests) do
        local manifest, msg = apiHandler.getRepoManifestFromPath(manifestPath)
        if not manifest then
            textHelper.log("Failed to locate manifest: " .. msg, "update", false)
        else
            manifest, msg = apiHandler.downloadManifest(manifest.owner, manifest.repo, manifest.branch, true)
            if not manifest then
                textHelper.log("Failed to update manifest: " .. msg, "update", false)
            else
                local projects = apiHandler.getInstalledProjects()
                for _, project in ipairs(manifest.projects) do
                    for _, installedProject in ipairs(projects) do
                        local projectDef = {
                            name = project.name,
                            owner = manifest.owner,
                            repo = manifest.repo,
                            branch = manifest.branch
                        }
                        if apiHandler.areProjectsSame(installedProject, projectDef) then
                            if manifest.last_commit ~= installedProject.last_commit then
                                local sucsess, msg = apiHandler.downloadProject(installedProject, quiet)
                                if not sucsess then
                                    textHelper.log("Failed to update project: " .. msg, "update", false)
                                else
                                    updatesDone = updatesDone + 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return updatesDone, nil
end






this.remove = function(funcArgs)
    local apiHandler = apiHandler
    local textHelper = textHelper

    local ID = funcArgs[1]
    if ID == nil then
        this.log("No ID provided")
        return
    end
    textHelper.log("Uninstalling: " .. ID)

    local manifest, project, msg = this.findProject(ID)
    if manifest == nil then
        textHelper.log("Failed to find project: " .. msg, "install", false)
        return
    end
    local projectDef = {
        name = project.name,
        owner = manifest.owner,
        repo = manifest.repo,
        branch = manifest.branch
    }
    local installedProjects = apiHandler.getInstalledProjects()

    ---@type ProjectDefinition
    local targetProject = nil
    for _, projectDefinst in ipairs(installedProjects) do
        if apiHandler.areProjectsSame(projectDef, projectDefinst) then
            targetProject = projectDefinst
        end
    end
    local sucsess, msg = apiHandler.removeProject(targetProject)
    if not sucsess then
        textHelper.log("Failed to remove project: " .. msg, "install", false)
        return
    end
end


local function setToken(funcArgs)
    local configManager = configManager
    local token = funcArgs[1]
    if token == nil then
        this.log("No token provided")
        return
    end
    configManager.SetValue("api_token", token)
    this.log("Token set")
end


---@diagnostic disable-next-line: unused-local
this.help = function(funcArgs)
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
    ["remove"] = this.remove,
    ["help"] = this.help,
    ["setToken"] = setToken
}

--==================
--=  Main program  =
--==================

---shell completion function
---@param shell any
---@param pos number
---@param text string
---@param previousText string[]
---@return string[] possible_completions the possible completions
---@diagnostic disable-next-line: unused-local
local function completion(shell, pos, text, previousText)
    local completions = {}
    if pos == 1 then
        if text == "" then
            for key, _ in pairs(this.SWITCH_Commands) do
                table.insert(completions, key)
            end
        else
            for key, _ in pairs(this.SWITCH_Commands) do
                if textHelper.startsWith(key, text) then
                    local remaining = key:sub(#text + 1)
                    table.insert(completions, remaining)
                end
            end
        end
    end
    return completions
end

local ApiTable = {
    completion = completion,
    commands = this.SWITCH_Commands
}



local info = debug.getinfo(1)
if info.name ~= nil then
    if info.name == "?" then
        return ApiTable
    end
end



local args = { ... }
local command = table.remove(args, 1)
local commandArgs = args

if command ~= nil then
    if command == "GithubDL" then
        --probably missed the api catch above, so return the api table
        return ApiTable
    end
    if this.SWITCH_Commands[command] then
        local _, msg = this.SWITCH_Commands[command](commandArgs)
        if msg then
            this.log(msg)
        end
    else
        this.log("Invalid command: '" .. command .. "', use 'GithubDL help' for help")
    end
end
