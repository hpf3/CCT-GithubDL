---@class textHelper
local textHelper = {}

---split a string by a pattern
---@param str string target string
---@param pat string pattern to split by
---@return string[] parts
textHelper.splitString = function(str, pat)
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

---checks if a string startsWith the specified string
---@param text string
---@param prefix string
---@return boolean
textHelper.startsWith = function(text, prefix)
   return text:find(prefix, 1, true) == 1
end

---checks if a string endsWith the specified string
---@param text string
---@param suffix string
---@return boolean
textHelper.endsWith = function(text, suffix)
   return text:sub(- #suffix) == suffix
end


---log a message to the console and a log file
---@param message string
---@param logName string?
---@param quiet boolean?
textHelper.log = function(message, logName, quiet)
   if quiet == nil then
      quiet = false
   end
   if not quiet then
      print("[GithubDL] " .. message)
   end

   --file logging
   local libManager = require("libs.GithubDL.libManager")
   local configManager = libManager.getConfigManager()

   --check if logging is enabled
   if configManager.GetValue("log") ~= "true" then
      return
   end
   local logDir = configManager.GetValue("log_dir")
   if logName == nil then
      logName = "main"
   end
   local logFile = logDir .. "/" .. logName .. ".log"
   local log = fs.open(logFile, "a")
   log.write("[" .. os.date("%c") .. "] " .. message .. "\n")
   log.close()
end


---pretty print a table of file paths
---@param tbl string[] the table of file paths
textHelper.PrettyPrint = function(tbl)
   if tbl == nil then
      return
   end
   if #tbl == 0 then
      return
   end
   local path = {}
   for _, v in ipairs(tbl) do
      local parts = textHelper.splitString(v, "/")
      --step through the parts, if they are new, set the current depth to that part and clear all deeper parts
      local depth = 1
      for _, part in ipairs(parts) do
         if path[depth] == nil then
            path[depth] = part
            print(string.rep("  ", depth - 1) .. part)
         else
            if path[depth] ~= part then
               path[depth] = part
               for i = depth + 1, #path do
                  path[i] = nil
               end
               print(string.rep("  ", depth - 1) .. part)
            end
         end
         depth = depth + 1
      end
   end
end

---removes all newlines from the text
---@param text string
---@return string
textHelper.flatten = function(text)
   local result, _ = text:gsub("\n", "")
   return result
end

return textHelper
