local STARTUP_LABEL_BEGIN = "--[GithubDL:start] Do Not Remove"
local STARTUP_LABEL_END = "--[GithubDL:end] Do Not Remove"
local STARTUP_TEMPLATE = [[--GithubDL startup code
local GithubDL = require("GithubDL")
GithubDL.commands["startup"]()
shell.setCompletionFunction("GithubDL", GithubDL.completion)]]

local function getStartup()
    local counter = 0
    local startPos=0
    local endPos=0
    local content = {}
    if not fs.exists("/startup") then
        return startPos, endPos, content
    end
    for line in io.lines("/startup") do
        counter = counter + 1
        if line == STARTUP_LABEL_BEGIN then
            startPos = counter
        elseif line == STARTUP_LABEL_END then
            endPos = counter
        end
        table.insert(content, line)
    end
    return startPos, endPos, content
end


local function install()
    print("Installing GithubDL...")
    
    --create the needed directories
    local dirs = {
        "/data",
        "/data/GithubDL"
    }
    for _, value in ipairs(dirs) do
        if not fs.exists(value) then
            fs.makeDir(value)
        end
    end

    --get the current startup code
    local startPos, endPos, content = getStartup()

    --remove the old startup code
    if startPos ~= 0 and endPos ~= 0 then
        for i = startPos, endPos do
            table.remove(content, startPos)
        end
    end

    --add the new startup code
    table.insert(content, STARTUP_LABEL_BEGIN)
    table.insert(content, STARTUP_TEMPLATE)
    table.insert(content, STARTUP_LABEL_END)

    --write the new startup code
    local file = fs.open("/startup", "w")
    for _, value in ipairs(content) do
        file.write(value .. "\n")
    end
    file.close()
end
local function remove()
    print("Removing GithubDL...")
    local startPos, endPos, content = getStartup()
    if startPos == 0 or endPos == 0 then
        print("GithubDL not found in startup")
        return
    end

    --remove the old startup code
    for i = startPos, endPos do
        table.remove(content, startPos)
    end

    --remove potentially generated files
    if fs.exists("/logs/GithubDL") then
        fs.delete("/logs/GithubDL")
    end
    if fs.exists("/data/GithubDL") then
        fs.delete("/data/GithubDL")
    end
end


local args = {...}
if #args < 1 then
    install()
    return
end
if args[1] == "install" then
    install()
elseif args[1] == "remove" then
    remove()
end