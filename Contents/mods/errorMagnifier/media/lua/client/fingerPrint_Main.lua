local print_original = print
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
					local modInfo = getModInfo(fileDir:match("(.-)media/"))
					if modInfo then
						local modID = modInfo:getId()
						if modID and modID~="errorMagnifier" then
							printText = "\["..modID.."\] "
						end
					end
				end
			end
		end
	end

	if printText then
		print_original(printText,...)
	else
		print_original(...)
	end
end