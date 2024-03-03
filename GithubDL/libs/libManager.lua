local baseRequire = "GithubDL."
local basePath = "/libs/GithubDL/"
local libManager = {}
--wrapper for require
local function getLib(libName)
    --test if the lib is available to load
    local file = basePath..libName..".lua"
    if not fs.exists(file) then
        return nil, "File not found"
    end
    if fs.isDir(file) then
        return nil, "File is a directory"
    end
    return require(baseRequire..libName)
end
libManager.getLib = getLib

--shortcuts for the most used libs
local function getApiHandler()
    return getLib("githubApiHandler")
end
libManager.getApiHandler = getApiHandler

local function getFileManager()
    return getLib("fileManager")
end
libManager.getFileManager = getFileManager

local function getConfigManager()
    return getLib("configManager")
end
libManager.getConfigManager = getConfigManager

local function gettextHelper()
    return getLib("textHelper")
end
libManager.gettextHelper = gettextHelper

local function getBase64()
    return getLib("base64")
end
libManager.getBase64 = getBase64

local function gethttpManager()
    return getLib("httpManager")
end
libManager.gethttpManager = gethttpManager
return libManager