--{["body"]=count}
local parsedErrors = {}

local errorCount = 0
local function parseErrors()

	local errors = getLuaDebuggerErrors()
	if errors:size() <= 0 then return end

	for i = errorCount+1,errors:size() do
		local str = errors:get(i-1)
		str = str:gsub("\t", "    ")

		parsedErrors[str] = (parsedErrors[str] or 0)+1

	end
	errorCount = getLuaDebuggerErrorCount()

	--[[
	local pseudoKey = 0
	for error,count in pairs(parsedErrors) do
		pseudoKey = pseudoKey+1
		print("=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=")
		print("UNIQUE ERROR: "..pseudoKey.."  count:"..count)
		print(" -- error: \n"..error.."\n\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@")
	end
	--]]
end



local function test()
	DebugLogStream.printException()
end
Events.EveryTenMinutes.Add(test)

local function compareErrorCount() if errorCount ~= getLuaDebuggerErrorCount() then parseErrors() end end

Events.OnTickEvenPaused.Add(compareErrorCount)
Events.OnFETick.Add(compareErrorCount)



