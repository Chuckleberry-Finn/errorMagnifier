function _G.print(...)

	local coroutine = getCurrentCoroutine()
	local modTag
	if coroutine then

		local luaCallFrame = getCoroutineCallframeStack(coroutine,0)
		if luaCallFrame ~= nil and luaCallFrame then
			local fileDir = getFilenameOfCallframe(luaCallFrame)
			if fileDir and fileDir ~= "" then
				local modInfoDir = fileDir:match("^(.*/Contents/mods/[^/]+/)")
				local modInfo = modInfoDir and getModInfo(modInfoDir)
				local modID = modInfo and modInfo:getId()
				if modID then
					modTag = "["..modID.."] "
				end
			end
		end

	end

	local output = modTag and modTag ~= "" and modTag or ""

	for i = 1, select('#', ...) do
		local val = select(i, ...)
		output = output .. "    " .. tostring(val)
	end

	DebugLog.log(output)
end