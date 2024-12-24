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
		--for i= count - 1, 0, -1 do
			---@type LuaCallFrame
			local luaCallFrame = getCoroutineCallframeStack(coroutine,0)
			if luaCallFrame ~= nil and luaCallFrame then
				local fileDir = getFilenameOfCallframe(luaCallFrame)
				if fileDir and fileDir ~= "" then
					local modInfoDir = fileDir:match("^(.*/Contents/mods/[^/]+/)")
					local modInfo = modInfoDir and getModInfo(modInfoDir)
					local modID = modInfo and modInfo:getId()
					if modID then
						printText = "\["..modID.."\] "
					end
				end
			end
		--end
	end

	local args = {...}
	local message = table.concat(args, "	")

	if printText and printText ~= "" then
		print_original(printText.." "..tostring(message))
	else
		print_original(...)
	end

	if getDebug() then
		printThis((printText and printText or "") .. message)
	end
end
