local print_original = print

local writer = getFileWriter("TEMP_PRINT_LOG.txt", true, false)
writer:close()

local function printThis(msg)
	local w = getFileWriter("TEMP_PRINT_LOG.txt", true, true)
	w:write(msg.."\n")
	w:close()
end

function _G.print(...)

	local coroutine = getCurrentCoroutine()
	local printText
	if coroutine then
		local count = getCallframeTop(coroutine)
		for i= count - 1, 0, -1 do
			---@type LuaCallFrame
			local luaCallFrame = getCoroutineCallframeStack(coroutine,i)
			if luaCallFrame ~= nil and luaCallFrame then
				local fileDir = getFilenameOfCallframe(luaCallFrame)
				if fileDir then
					local modInfoDir = fileDir:match("(.-)media/")
					local modInfo = modInfoDir and getModInfoByID(modInfoDir)
					local modID = modInfo and modInfo:getId()
					if modID and modID~="errorMagnifier" then
						printText = "\["..modID.."\] "
					end
				end
			end
		end
	end

	local args = {...}
	local message = table.concat(args, " ")

	if printText and printText ~= "" then
		print_original(printText, args)
	else
		print_original(args)
	end

	if getDebug() then
		printThis((printText and printText or "") .. message)
	end
end


if getActivatedMods():contains("ChuckleberryFinnAlertSystem") then
	local modCountSystem = require "chuckleberryFinnModding_modCountSystem"
	if modCountSystem then modCountSystem.pullAndAddModID() end
else print("WARNING: Highly recommended to install `ChuckleberryFinnAlertSystem` (Workshop ID: `3077900375`) for latest news and updates.") end
