local function install()
    --TODO: Implement startup
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
end
local function remove()
    --TODO: Implement startup removal
    print("Removing GithubDL...")
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