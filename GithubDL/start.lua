
--utility functions
local function log(message)
    print("[GithubDL] "..message)
end
-- Compatibility: Lua-5.1
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
local function startsWith(text, prefix)
    return text:find(prefix, 1, true) == 1
end

--Startup functions
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
local function main(funcArgs)
    setPath()
    --TODO: Implement main functions
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
    ["main"] = main,
    ["setToken"] = setToken
}

if SWITCH_Commands[command] then
    SWITCH_Commands[command](commandArgs)
end

return SWITCH_Commands