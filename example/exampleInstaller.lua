local function install()
    --TODO: Implement
    print("Installing example...")
end
local function remove()
    --TODO: Implement
    print("Removing example...")
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