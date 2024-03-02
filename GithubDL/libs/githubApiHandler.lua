local libManager = require("GithubDL.libManager")
local configManager = libManager.getConfigManager()
local ApiUrl = "https://api.github.com"
local githubApiHandler = {}

local function SendHttpGET(url, bonusHeaders)
    local possible = http.checkURL(url)
    if not possible then
        return nil, "Invalid URL"
    end
    --set the headers
    local headers = {
        ["User-Agent"] = "GithubDL/script",
        ["Accept"] = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28"
    }
    --check if we have a token
    local token = configManager.GetValue("api_token")
    if token ~= nil and token ~= "" then
        headers["Authorization"] = "Bearer "..token
    end
    --add the bonus headers
    if bonusHeaders ~= nil then
        for k, v in pairs(bonusHeaders) do
            headers[k] = v
        end
    end
    --send the request
    local response,error = http.get(url, headers)
    if response == nil then
        return nil, "Failed to send request: "..error
    end
    return response
end
--[[ TODO: Find a use for this function
local function SendHttpPOST(url, data, bonusHeaders)

    local possible = http.checkURL(url)
    if not possible then
        return nil, "Invalid URL"
    end
    --set the headers
    local headers = {
        ["User-Agent"] = "GithubDL/script",
        ["Accept"] = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28"
    }
    --check if we have a token
    local token = configManager.GetValue("api_token")
    if token ~= nil and token ~= "" then
        headers["Authorization"] = "Bearer "..token
    end
    --add the bonus headers
    if bonusHeaders ~= nil then
        for k, v in pairs(bonusHeaders) do
            headers[k] = v
        end
    end
    local dataString = textutils.serializeJSON(data)
    --send the request
    local response,error = http.post(url, dataString, headers)
    if response == nil then
        return nil, "Failed to send request: "..error
    end
    return response
end
]]--

githubApiHandler.Gettree = function(owner,repo,branch)
    if branch == nil or branch == "" then
        branch = "master"
    end
    local url = ApiUrl.."/repos/"..owner.."/"..repo.."/git/trees/"..branch.."?recursive=1"
    local response,error = SendHttpGET(url)
    if response == nil then
        return nil, error
    end
    local status,msg = response.getResponseCode()
    if status ~= 200 then
        return nil, "Failed to get tree: "..msg
    end
    return textutils.unserializeJSON(response.readAll())
end

githubApiHandler.getCommit = function(owner,repo,branch)
    if branch == nil or branch == "" then
        branch = "master"
    end
    local url = ApiUrl.."/repos/"..owner.."/"..repo.."/commits/"..branch
    local headers = {
        ["Accept"] = "application/vnd.github.VERSION.sha"
    }
    local response,error = SendHttpGET(url,headers)
    if response == nil then
        return nil, error
    end
    local status,msg = response.getResponseCode()
    if status ~= 200 then
        return nil, "Failed to get commit: "..msg
    end
    return textutils.unserializeJSON(response.readAll())
end
return githubApiHandler