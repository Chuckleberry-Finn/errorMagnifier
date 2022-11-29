local errorMagnifier = {}
errorMagnifier.parsedErrors = {} --{["error1"]=count1,["error2"]=count2}
errorMagnifier.parsedErrorsKeyed = {} --{[1]="error1",[2]="error2"}
errorMagnifier.errorCount = 0


function errorMagnifier.parseErrors()

	local errors = getLuaDebuggerErrors()
	if errors:size() <= 0 then return end

	for i = errorMagnifier.errorCount+1,errors:size() do
		local str = errors:get(i-1)
		str = str:gsub("\t", "    ")

		if not errorMagnifier.parsedErrors[str] then
			table.insert(errorMagnifier.parsedErrorsKeyed, str)
			errorMagnifier.parsedErrors[str] = 0
		end
		errorMagnifier.parsedErrors[str] = errorMagnifier.parsedErrors[str]+1

	end
	errorMagnifier.errorCount = getLuaDebuggerErrorCount()

	--[[ UGLY PRINT OUT
	local pseudoKey = 0
	for error,count in pairs(errorMagnifier.parsedErrors) do
		pseudoKey = pseudoKey+1
		print("=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=\n UNIQUE ERROR: "..pseudoKey.."  count:"..count)
		print(" -- error: \n"..error.."\n\n@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@")
	end
	--]]
end


---SPAM ERRORS IN DEBUG
--TODO: DISABLE BEFORE RELEASE
if getDebug() then local function test() DebugLogStream.printException() end Events.EveryTenMinutes.Add(test) end


errorMagnifier.popUps = {}
errorMagnifier.popupPanel = ISPanel:derive("errorMagnifier.popupPanel")
errorMagnifier.popupPanel.errorText = ""

function errorMagnifier.popupPanel:render()
	if not self:isVisible() then return end

	---@type ISPanel
	local popup = self
	local countOf = "x"..errorMagnifier.parsedErrors[popup.errorText]
	local font = UIFont.NewSmall
	local countOfWidth = getTextManager():MeasureStringX(font, countOf)

	popup:drawText(popup.errorText, 8, 4, 0.9, 0.9, 0.9, 0.9, font)
	popup:drawText(countOf, popup:getWidth()-countOfWidth-8, 4, 0.9, 0.9, 0.9, 0.9, font)
end


---@type ISButton
errorMagnifier.Button = false
errorMagnifier.currentlyViewing = 1
errorMagnifier.maxErrorsViewable = 4


function errorMagnifier.errorPanelPopulate()
	if not errorMagnifier.Button then return end

	if #errorMagnifier.parsedErrorsKeyed <= 0 or (errorMagnifier.popUps.errorMessage1 and errorMagnifier.popUps.errorMessage1:isVisible()) then
		for i=1, errorMagnifier.maxErrorsViewable do errorMagnifier.popUps["errorMessage"..i]:setVisible(false) end
		return
	end

	for i=1, math.min(#errorMagnifier.parsedErrorsKeyed,errorMagnifier.maxErrorsViewable) do
		---@type ISPanel
		local popup = errorMagnifier.popUps["errorMessage"..i]
		popup.errorText = errorMagnifier.parsedErrorsKeyed[errorMagnifier.currentlyViewing-1+i]
		popup:setVisible(true)
	end
end


function errorMagnifier.EMButtonOnClick()
	if not errorMagnifier.Button then return end
	errorMagnifier.errorPanelPopulate()
end


function errorMagnifier.setErrorMagnifierButton()
	if errorMagnifier.Button then return errorMagnifier.Button end



	---@type Texture
	local errorMagTexture = getTexture("media/textures/magGlassError.png")
	local eW, eH = errorMagTexture:getWidth(), errorMagTexture:getHeight()

	local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()

	local fontHeight = getTextManager():getFontHeight(UIFont.DebugConsole)
	local x = screenWidth - eW/2 - 50
	local y = screenHeight - (fontHeight*2) - eH - 15

	errorMagnifier.Button = ISButton:new(x, y, eW, eH, "", nil, errorMagnifier.EMButtonOnClick)
	errorMagnifier.Button:setImage(errorMagTexture)
	errorMagnifier.Button:setDisplayBackground(false)
	errorMagnifier.Button:initialise()
	errorMagnifier.Button:addToUIManager()

	local screenSpan = screenHeight - errorMagnifier.Button:getHeight() - 8
	local popupHeight, popupWidth = (screenSpan/6)-4, screenWidth/4

	local popupX = 0-popupWidth+(errorMagnifier.Button:getWidth()*1.25)--0+errorMagnifier.Button:getWdith()-popupWidth-8
	local popupY, popupYOffset = 0-8, popupHeight+4

	for i=1, errorMagnifier.maxErrorsViewable do
		errorMagnifier.popUps["errorMessage"..i] = errorMagnifier.popupPanel:new(popupX,popupY-(popupYOffset*i), popupWidth, popupHeight)
		---@type ISPanel
		local popup = errorMagnifier.popUps["errorMessage"..i]
		popup:initialise()
		popup:instantiate()
		errorMagnifier.Button:addChild(popup)
		popup:setVisible(false)
	end
end
Events.OnCreatePlayer.Add(errorMagnifier.setErrorMagnifierButton)


---pass checks every tick
local function compareErrorCount() if errorMagnifier.errorCount ~= getLuaDebuggerErrorCount() then errorMagnifier.parseErrors() end end
Events.OnTickEvenPaused.Add(compareErrorCount)
Events.OnFETick.Add(compareErrorCount)