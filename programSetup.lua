---split based on a pattern
---@param str string target string
---@param pat string pattern to split by
---@return string[] parts
local function split(str, pat)
    local t = {}
    local fpat = "(.-)" .. pat
    local last_end = 1
    local s, e, cap = str:find(fpat, 1)
    while s do
        if s ~= 1 or cap ~= "" then
            table.insert(t, cap)
        end
        last_end = e + 1
        s, e, cap = str:find(fpat, last_end)
    end
    if last_end <= #str then
        cap = str:sub(last_end)
        table.insert(t, cap)
    end
    return t
end

--the base url for the project, if you change this, keep in mind whether or not you need a trailing slash based on your manifest
local baseUrl = "https://raw.githubusercontent.com/hpf3/CCT-GithubDL/main"
local manifestPath = "/GithubDL.GDLManifest"

--grab the manifest
local response, error = http.get(baseUrl .. manifestPath)
if response == nil then
    print("Failed to download manifest: " .. error)
    return
end
local manifest = textutils.unserialiseJSON(response.readAll())
response.close()
print("Installing " .. manifest.name .. "...")

--download the files
for k, v in ipairs(manifest.files) do
    local pair = split(v, "=")
    local path = pair[2] --i don't know why this is backwards, but it is.
    print("Downloading: " .. path .. " to " .. pair[1])
    local url = baseUrl .. path
    local response, error = http.get(url)
    if response == nil then
        print("Failed to download file: " .. path .. " " .. error)
        return
    end
    local file = fs.open(pair[1], "w")
    file.write(response.readAll())
    file.close()
    response.close()
    print("Downloaded: " .. path .. " (" .. k .. "/" .. #manifest.files .. ")")
end
if manifest.installer ~= nil then
    --download the installer
    local response, error = http.get(baseUrl .. manifest.installer)
    if response == nil then
        print("Failed to download installer: " .. error)
        return
    end
    local file = fs.open("installer.lua", "w")
    file.write(response.readAll())
    file.close()
    response.close()
    print("Downloaded: installer.lua")
    print("Running installer...")
    shell.run("installer.lua", "install")
    print("Install Finished! cleaning up...")
    fs.delete("installer.lua")
end
print("Done!")
local counter = 5
while counter > 0 do
    print("Restarting in " .. counter .. "...")
    os.sleep(1)
    counter = counter - 1
end
os.reboot()
