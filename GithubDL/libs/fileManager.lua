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

return fileManager