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

	--[[ UGLY PRINT OUT
	local pseudoKey = 0
	for error,count in pairs(parsedErrors) do
		pseudoKey = pseudoKey+1
		print("=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n UNIQUE ERROR: "..pseudoKey.."  count:"..count)
		print(" -- error: \n"..error.."\n\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@")
	end
	--]]
end

---SPAM ERRORS IN DEBUG
--TODO: DISABLE BEFORE RELEASE
if getDebug() then local function test() DebugLogStream.printException() end Events.EveryTenMinutes.Add(test) end


local function EMButtonOnClick()

end

---@type ISButton
local errorMagButton
local function setErrorMagnifierButton()
	if errorMagButton then return errorMagButton end

	---@type Texture
	local errorMagTexture = getTexture("media/textures/magGlassError.png")
	local eW, eH = errorMagTexture:getWidth(), errorMagTexture:getHeight()

	local fontHeight = getTextManager():getFontHeight(UIFont.DebugConsole)
	local x = getCore():getScreenWidth() - eW/2 - 50
	local y = getCore():getScreenHeight() - (fontHeight*2) - eH - 15

	errorMagButton = ISButton:new(x, y, eW, eH, "", nil, EMButtonOnClick)
	errorMagButton:setImage(errorMagTexture)
	errorMagButton:setDisplayBackground(false)
	errorMagButton.borderColor = {r=1, g=1, b=1, a=0}

	ISEquippedItem.instance:addChild(errorMagButton)
end
Events.OnCreatePlayer.Add(setErrorMagnifierButton)


---pass checks every tick
local function compareErrorCount()
	if errorMagButton then errorMagButton:bringToTop() end
	if errorCount ~= getLuaDebuggerErrorCount() then parseErrors() end
end
Events.OnTickEvenPaused.Add(compareErrorCount)
Events.OnFETick.Add(compareErrorCount)