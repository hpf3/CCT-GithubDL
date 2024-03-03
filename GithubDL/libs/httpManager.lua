local libManager = require("GithubDL.libManager")
local configManager = libManager.getConfigManager()
local textHelper = libManager.gettextHelper()
local fileManager = libManager.getFileManager()
local base64 = libManager.getBase64()
local httpManager = {}

--utils
local function isCached(url)
    local cacheDir = configManager.GetValue("web_cache")
    local cacheFile = cacheDir.."/"..base64.encode(url)
    if fileManager.Exists(cacheFile) then
        return true
    end
    return false
end

local function getCached(url)
    local cacheDir = configManager.GetValue("web_cache")
    local cacheFile = cacheDir.."/"..base64.encode(url)
    return fileManager.LoadObject(cacheFile)
end


local function getCachedHeaders(url)
    if not isCached(url) then
        return {}
    end
    local cache = getCached(url)

    local headers = {}
    if cache.headers["etag"] ~=nil then
        headers["if-none-match"] = cache.headers["etag"]
    elseif cache.headers["last-modified"] ~=nil then
        headers["if-modified-since"] = cache.headers["last-modified"]
    end
    return headers
end

local function packageResponse(response)
    local headers = response.getResponseHeaders()
    local body = response.readAll()
    local status,msg = response.getResponseCode()
    local cache = {
        headers = headers,
        body = body,
        status = status,
        msg = msg
    }
    return cache
end
local function packageConversation(url,headers,response)
    local cache = {}
    cache.response = packageResponse(response)
    cache.request = {
        url = url,
        headers = headers
    }
    return cache
end

local function cacheResponse(url, responsePackage)
    local cacheDir = configManager.GetValue("web_cache")
    local cacheFile = cacheDir.."/"..base64.encode(url)
    fileManager.SaveObject(cacheFile, responsePackage)
end



--status functions
local function good(ConvPackage)
    --check if we need to cache the response
    if ConvPackage.response.headers["etag"] ~= nil or ConvPackage.response.headers["last-modified"] ~= nil then
        cacheResponse(ConvPackage.request.url, ConvPackage.response)
    end
    return ConvPackage.response
end

local function bad(ConvPackage)
    --if we are rate limited, wait and retry
    local retryTime = ConvPackage.response.headers["retry-after"]
    if retryTime ~= nil then
        textHelper.log("Rate limited, retrying in "..retryTime.." seconds")
        os.sleep(tonumber(retryTime))
        return httpManager.SendHttpGET(ConvPackage.request.url,ConvPackage.request.headers)
    end
    local ratelimit = ConvPackage.response.headers["x-ratelimit-remaining"]
    if ratelimit == "0" then
        local resetTime = ConvPackage.response.headers["x-ratelimit-reset"]
        local timeLeft = resetTime - (os.epoch("utc")/1000)
        if timeLeft <= 60 then
            textHelper.log("Rate limited, retrying in "..timeLeft.." seconds")
            os.sleep(timeLeft)
            return httpManager.SendHttpGET(ConvPackage.request.url,ConvPackage.request.headers)
        else
            textHelper.log("Rate limited, retrying in 60 seconds")
            os.sleep(60)
            return httpManager.SendHttpGET(ConvPackage.request.url,ConvPackage.request.headers)
        end
    end

    --if it is a 400 error, return nil
    local status = ConvPackage.response.status
    if status >= 400 and status < 500 then
        return nil, "Failed to get data: "..ConvPackage.response.msg
    end

    --if it is a 500 error, retry after 60 seconds
    if status >= 500 and status < 600 then
        textHelper.log("Server error, retrying in 60 seconds")
        os.sleep(60)
        return httpManager.SendHttpGET(ConvPackage.request.url,ConvPackage.request.headers)
    end
end

local function forward(ConvPackage)
    local newUrl = ConvPackage.response.headers["location"]
    return httpManager.SendHttpGET(newUrl,ConvPackage.request.headers)
end

local function useCache(ConvPackage)
    return getCached(ConvPackage.request.url)
end


local SWITCH_httpStatus = {
    [200] = good,
    [201] = good,
    [202] = forward,
    [203] = useCache,
    [204] = good,
    [205] = good,
    [206] = good,
    [300] = forward,
    [301] = forward,
    [302] = forward,
    [303] = forward,
    [304] = useCache,
    [305] = forward,
    [306] = forward,
    [307] = forward,
    [308] = forward,
    [400] = bad,
    [401] = bad,
    [403] = bad,
    [404] = bad,
    [422] = bad,
    [500] = bad,
    [502] = bad,
    [503] = bad,
    [504] = bad
}

--main GET function
httpManager.SendHttpGET = function(url, bonusHeaders)
    local possible = http.checkURL(url)
    if not possible then
        return nil, "Invalid URL"
    end
    --set the basic headers
    local headers = {
        ["User-Agent"] = "hpf3/GithubDL",
        ["Accept"] = "application/vnd.github+json",
        ["X-GitHub-Api-Version"] = "2022-11-28"
    }
    --check if we have a token
    local token = configManager.GetValue("api_token")
    if token ~= nil and token ~= "" then
        headers["Authorization"] = "Bearer "..token
    end
    --add cache headers
    local cacheHeaders = getCachedHeaders(url)
    for k, v in pairs(cacheHeaders) do
        headers[k] = v
    end
    --add the bonus headers
    if bonusHeaders ~= nil then
        for k, v in pairs(bonusHeaders) do
            headers[k] = v
        end
    end
    --send the request
    textHelper.log("Sending request to: "..url)
    local response,error = http.get(url, headers)
    if response == nil then
        return nil, "Failed to send request: "..error
    end
    local status,msg = response.getResponseCode()
    if SWITCH_httpStatus[status] == nil then
        return nil, "Unhandled status code: "..status.." "..msg
    end
    local ConvPackage = packageConversation(url,bonusHeaders,response)
    return SWITCH_httpStatus[status](ConvPackage)
end


return httpManager