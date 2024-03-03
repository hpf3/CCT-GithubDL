local fileManager = {}


fileManager.SaveObject = function(path, data)
    if not fs.exists(fs.getDir(path)) then
        fs.makeDir(fs.getDir(path))
    end
    local file = fs.open(path, "w")
    file.write(textutils.serialize(data))
    file.close()
end

fileManager.LoadObject = function(path)
    if not fs.exists(path) then
        return nil, "File not found"
    end
    local file = fs.open(path, "r")
    local data = file.readAll()
    file.close()
    return textutils.unserialize(data)
end

fileManager.SaveJson = function(path, data)
    if not fs.exists(fs.getDir(path)) then
        fs.makeDir(fs.getDir(path))
    end
    local file = fs.open(path, "w")
    file.write(textutils.serializeJSON(data))
    file.close()
end

fileManager.LoadJson = function(path)
    if not fs.exists(path) then
        return nil, "File not found"
    end
    local file = fs.open(path, "r")
    local data = file.readAll()
    file.close()
    return textutils.unserializeJSON(data)
end

fileManager.AppendLine = function(path, data)
    if not fs.exists(fs.getDir(path)) then
        fs.makeDir(fs.getDir(path))
    end
    local file = fs.open(path, "a")
    file.writeLine(data)
    file.close()
end

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

fileManager.SaveFile = function(path, data)
    if not fs.exists(fs.getDir(path)) then
        fs.makeDir(fs.getDir(path))
    end
    local file = fs.open(path, "w")
    file.write(data)
    file.close()
end

fileManager.Exists = fs.exists

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