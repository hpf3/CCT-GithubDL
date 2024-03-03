local textHelper = {}

textHelper.splitString = function(str, pat)
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
 textHelper.startsWith = function(text, prefix)
    return text:find(prefix, 1, true) == 1
end
textHelper.endsWith = function(text, suffix)
   return text:sub(-#suffix) == suffix
end

textHelper.log = function(message,logName)
   print("[GithubDL] "..message)
   local libManager = require("GithubDL.libManager")
   local configManager = libManager.getConfigManager()

   local logDir = configManager.GetValue("log_dir")
   if logName == nil then
       logName = "main"
   end
   local logFile = logDir.."/"..logName..".log"
   local log = fs.open(logFile,"a")
   log.writeLine("["..os.time("local").."] "..message)
end

--pretty print a table of file paths
textHelper.PrettyPrint = function(tbl)
   local path = {}
   for _,v in ipairs(tbl) do
      local parts = textHelper.splitString(v,"/")
      --step through the parts, if they are new, set the current depth to that part and clear all deeper parts
      local depth = 1
      for _,part in ipairs(parts) do
         if path[depth] == nil then
            path[depth] = part
         else
            if path[depth] ~= part then
               path[depth] = part
               for i = depth+1, #path do
                  path[i] = nil
               end
               print(string.rep("  ",depth-1)..part)
            end
         end
         depth = depth + 1
      end
   end
end

return textHelper