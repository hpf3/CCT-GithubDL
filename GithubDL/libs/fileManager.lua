---@class fileManager
local fileManager = {}

---save an object to a file
---@param path string
---@param data any
fileManager.SaveObject = function(path, data)
    if not fs.exists(fs.getDir(path)) then
        fs.makeDir(fs.getDir(path))
    end
    local file = fs.open(path, "w")
    file.write(textutils.serialize(data))
    file.close()
end

---load an object from a file
---@param path string
---@return any? data
---@return string? error
fileManager.LoadObject = function(path)
    if not fs.exists(path) then
        return nil, "File not found"
    end
    local file = fs.open(path, "r")
    local data = file.readAll()
    file.close()
    return textutils.unserialize(data)
end

---save a table to a file as json
---@param path string
---@param data table
fileManager.SaveJson = function(path, data)
    if not fs.exists(fs.getDir(path)) then
        fs.makeDir(fs.getDir(path))
    end
    local file = fs.open(path, "w")
    file.write(textutils.serializeJSON(data))
    file.close()
end


---load a table from a file as json
---@param path string
---@return table? data
---@return string? error
fileManager.LoadJson = function(path)
    if not fs.exists(path) then
        return nil, "File not found"
    end
    local file = fs.open(path, "r")
    local data = file.readAll()
    file.close()
    return textutils.unserializeJSON(data)
end

---write a line to a file
---@param path string
---@param data string
fileManager.AppendLine = function(path, data)
    if not fs.exists(fs.getDir(path)) then
        fs.makeDir(fs.getDir(path))
    end
    local file = fs.open(path, "a")
    file.writeLine(data)
    file.close()
end


---get all files in a directory and its subdirectories
---@param dir string
---@return string[] fileList list of file paths
fileManager.GetFilesRecursive = function(dir)
    local files = fs.list(dir)
    local allFiles = {}
    for i=1,#files do
        local file = files[i]
        if fs.isDir(dir.."/"..file) then
            local subFiles = fileManager.GetFilesRecursive(dir.."/"..file)
            for j=1,#subFiles do
                table.insert(allFiles,subFiles[j])
            end
        else
            table.insert(allFiles,dir.."/"..file)
        end
    end
    return allFiles
end

---save a file
---@param path string
---@param data string
fileManager.SaveFile = function(path, data)
    if not fs.exists(fs.getDir(path)) then
        fs.makeDir(fs.getDir(path))
    end
    local file = fs.open(path, "w")
    file.write(data)
    file.close()
end

---delete a file and its parent directories if they are empty
---@param path string
fileManager.Delete = function (path)
    fs.delete(path)
    local dir = fs.getDir(path)
    if not fs.isDriveRoot(dir) then
        if #fs.list(dir) == 0 then
            fileManager.Delete(dir)
        end
    end
end
return fileManager