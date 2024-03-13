local baseRequire = "libs.GithubDL."
local basePath = "/libs/GithubDL/"

---@class libManager
local libManager = {}

---wrapper for require, gets the library named, prefixing the base libs path
---@param libName string
---@return any?
---@return string?
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
libManager.getApiHandler = function()
    ---@module "GithubDL.libs.githubApiHandler"
    local lib = getLib("githubApiHandler")
    return lib
end


libManager.getFileManager = function()
    ---@module "GithubDL.libs.fileManager"
    local lib = getLib("fileManager")
    return lib
end


libManager.getConfigManager = function()
    ---@module "GithubDL.libs.configManager"
    local lib = getLib("configManager")
    return lib
end


libManager.gettextHelper = function()
    ---@module "GithubDL.libs.textHelper"
    local lib = getLib("textHelper")
    return lib
end


libManager.getBase64 = function()
    ---@module "GithubDL.libs.base64"
    local lib = getLib("base64")
    return lib
end

libManager.gethttpManager = function()
    ---@module "GithubDL.libs.httpManager"
    local lib = getLib("httpManager")
    return lib
end

return libManager