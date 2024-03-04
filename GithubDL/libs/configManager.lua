local libManager = require("GithubDL.libManager")
local fileManager = libManager.getFileManager()
local configManager = {}
local configFile = "/config.cfg"
local defaultConfig = {
    ["api_token"] = "",
    ["data_dir"] = "/data/GithubDL",
    ["log_dir"] = "/logs/GithubDL",
    ["lib_dir"] = "/libs/GithubDL",
    ["installed_projects"] = "/data/GithubDL/installedProjects.cfg",
    ["web_cache"] = "/data/GithubDL/webCache",
    ["auto_update"] = "true"
}
--file functions
local SaveConfig = function(data)
    fileManager.SaveObject(defaultConfig["data_dir"]..configFile, data)
end
local LoadConfig = function()
    local config = fileManager.LoadObject(defaultConfig["data_dir"]..configFile)
    if config == nil then
        config = {}
    end
    return config
end

-- config functions
configManager.SetValue = function(key, value)
    local config = LoadConfig()
    config[key] = value
    SaveConfig(config)
end
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
configManager.GetConfig = function()
    local config = defaultConfig
    local loadedConfig = LoadConfig()
    for k, v in pairs(loadedConfig) do
        config[k] = v
    end
    return config
end
configManager.SetConfig = function(data)
    SaveConfig(data)
end
return configManager