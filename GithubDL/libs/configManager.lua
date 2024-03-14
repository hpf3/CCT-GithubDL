--#region Requires
---@module "GithubDL.libs.libManager"
local libManager = require("libs.GithubDL.libManager")
local fileManager = libManager.getFileManager()
--#endregion Requires

--#region Class Definition

---@alias ConfigTable table<string, string>

--#endregion Class Definition
---@class ConfigManager
local configManager = {}
local configFile = "/config.cfg"

---@type ConfigTable
local defaultConfig = {
    ["api_token"] = "",
    ["data_dir"] = "/data/GithubDL",
    ["log_dir"] = "/logs/GithubDL",
    ["lib_dir"] = "/libs/GithubDL",
    ["installed_projects"] = "/data/GithubDL/installedProjects.cfg",
    ["web_cache"] = "/data/GithubDL/webCache",
    ["auto_update"] = "true",
    ["log"] = "true",
}

--#region file functions

---save the config to a file
---@param data ConfigTable
local SaveConfig = function(data)
    fileManager.SaveObject(defaultConfig["data_dir"]..configFile, data)
end

---load the config from a file
---@return ConfigTable
local LoadConfig = function()
    local config = fileManager.LoadObject(defaultConfig["data_dir"]..configFile)
    if config == nil then
        config = {}
    end
    return config
end

--#endregion file functions

--#region config functions

---set a value in the config
---@param key string
---@param value string
configManager.SetValue = function(key, value)
    local config = LoadConfig()
    config[key] = value
    SaveConfig(config)
end

---get a value from the config
---@param key string
---@return string? value
---@return string? error
configManager.GetValue = function(key)
    local config = LoadConfig()
    if config[key] == nil then
        if defaultConfig[key] == nil then
            return nil, "Key not found"
        else
            return defaultConfig[key]
        end
    end
    return config[key]
end

---get the entire config table
---@return ConfigTable
configManager.GetConfig = function()
    local config = defaultConfig
    local loadedConfig = LoadConfig()
    for k, v in pairs(loadedConfig) do
        config[k] = v
    end
    return config
end

---set the entire config table (overwrites the entire config)
---@param data ConfigTable
configManager.SetConfig = function(data)
    SaveConfig(data)
end
return configManager