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
		---remove header noise, '---' is regex, hence the escapes
		str = str:gsub("%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-\n","")
		str = str:gsub("%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-\nSTACK TRACE\n%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-\n","")

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
errorMagnifier.spamErrorTest = true
--TODO: DISABLE BEFORE RELEASE
if getDebug() and errorMagnifier.spamErrorTest then
	local function callingNonexistentFunctionTest() DebugLogStream.printException() end
	Events.EveryTenMinutes.Add(callingNonexistentFunctionTest)

	local function concatStringAndBooleanTest() local testString = "test"..true end
	Events.EveryTenMinutes.Add(concatStringAndBooleanTest)

	local function lessThanNonNumberTest() if 1 <= "a" then print("miracles happen") end end
	Events.EveryTenMinutes.Add(lessThanNonNumberTest)
end


errorMagnifier.popUps = {}
errorMagnifier.popupPanel = ISPanelJoypad:derive("errorMagnifier.popupPanel")
errorMagnifier.popupPanel.currentErrorNum = 0
---@type ISButton
errorMagnifier.Button = false
errorMagnifier.currentlyViewing = 1
errorMagnifier.maxErrorsViewable = 5


function errorMagnifier.popupPanel:render()
	if not self:isVisible() then return end
	---@type ISPanel
	local popup = self
	local font = UIFont.NewSmall
	local fontHeight = getTextManager():getFontHeight(font)

	local errorText = errorMagnifier.parsedErrorsKeyed[popup.currentErrorNum]

	local countOf = "x"..tostring(errorMagnifier.parsedErrors[errorText])
	local countOfWidth = getTextManager():MeasureStringX(font, countOf)

	local outOf = popup.currentErrorNum.." out of "..#errorMagnifier.parsedErrorsKeyed
	local outOfWidth = getTextManager():MeasureStringX(font, outOf)

	local errorBoundWidth, errorBoundHeight = popup:getWidth()-8, popup:getHeight()-8
	popup:setStencilRect(7, 3+fontHeight, errorBoundWidth-countOfWidth-4, errorBoundHeight-3-fontHeight)

	popup:drawText(errorText, 8, 3+fontHeight, 0.9, 0.9, 0.9, 0.9, font)
	popup:clearStencilRect()
	popup:drawText(countOf, popup:getWidth()-countOfWidth-8, 4, 0.9, 0.9, 0.9, 0.9, font)
	popup:drawText(outOf, popup:getWidth()-countOfWidth-8-outOfWidth-8, 4, 0.9, 0.9, 0.9, 0.6, font)
	popup.clipboardButton:bringToTop()
end


function errorMagnifier.getErrorOntoClipboard(popup)
	local errorText = errorMagnifier.parsedErrorsKeyed[popup.currentErrorNum]
	if errorText then Clipboard.setClipboard(errorText) end
end


function errorMagnifier.popupPanel:onMouseWheel(del)
	errorMagnifier.currentlyViewing = errorMagnifier.currentlyViewing-del
	errorMagnifier.currentlyViewing = math.min(#errorMagnifier.parsedErrorsKeyed-(errorMagnifier.maxErrorsViewable-1), errorMagnifier.currentlyViewing)
	errorMagnifier.currentlyViewing = math.max(1, errorMagnifier.currentlyViewing)
	errorMagnifier.errorPanelPopulate()
	return true
end


function errorMagnifier.errorPanelPopulate()
	if not errorMagnifier.Button then return end
	if #errorMagnifier.parsedErrorsKeyed <= 0 then return end
	for i=1, math.min(#errorMagnifier.parsedErrorsKeyed,errorMagnifier.maxErrorsViewable) do
		---@type ISPanel
		local popup = errorMagnifier.popUps["errorMessage"..i]
		popup.currentErrorNum = errorMagnifier.currentlyViewing-1+i
		popup:setVisible(true)
		popup.clipboardButton:setVisible(true)
	end
end


function errorMagnifier.EMButtonOnClick()
	if not errorMagnifier.Button then return end

	if #errorMagnifier.parsedErrorsKeyed <= 0 or (errorMagnifier.popUps.errorMessage1 and errorMagnifier.popUps.errorMessage1:isVisible()) then
		for i=1, errorMagnifier.maxErrorsViewable do
			errorMagnifier.popUps["errorMessage"..i]:setVisible(false)
			errorMagnifier.popUps["errorMessage"..i].clipboardButton:setVisible(false)
		end
		return
	end
	errorMagnifier.errorPanelPopulate()
end



function errorMagnifier.setErrorMagnifierButton()
	if errorMagnifier.Button then return errorMagnifier.Button end

	---@type Texture
	local errorMagTexture = getTexture("media/textures/magGlassError.png")
	local errorClipTexture = getTexture("media/textures/clipboardError.png")
	local eW, eH = errorMagTexture:getWidth(), errorMagTexture:getHeight()

	local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()

	local fontHeight = getTextManager():getFontHeight(UIFont.NewSmall)
	local x = screenWidth - eW - 15
	local y = screenHeight - (fontHeight*2) - eH - 15

	errorMagnifier.Button = ISButton:new(x, y, eW, eH, "", nil, errorMagnifier.EMButtonOnClick)
	errorMagnifier.Button:setImage(errorMagTexture)
	errorMagnifier.Button:setDisplayBackground(false)
	errorMagnifier.Button:initialise()
	errorMagnifier.Button:addToUIManager()

	local screenSpan = screenHeight - errorMagnifier.Button:getHeight() - 8
	local popupHeight, popupWidth = (screenSpan/11)-4, screenWidth/3

	local popupX = screenWidth-popupWidth-8
	local popupY, popupYOffset = errorMagnifier.Button:getY()-8, popupHeight+4

	for i=1, errorMagnifier.maxErrorsViewable do
		errorMagnifier.popUps["errorMessage"..i] = errorMagnifier.popupPanel:new(popupX,popupY-(popupYOffset*i), popupWidth, popupHeight)
		---@type ISPanel
		local popup = errorMagnifier.popUps["errorMessage"..i]
		popup:initialise()
		popup:instantiate()
		popup:addToUIManager()

		popup.clipboardButton = ISButton:new(popupX+popupWidth-26, (popupY-(popupYOffset*i))+10+fontHeight, 22, 22, "", popup, errorMagnifier.getErrorOntoClipboard)
		popup.clipboardButton:setImage(errorClipTexture)
		popup.clipboardButton:setDisplayBackground(false)
		popup.clipboardButton:initialise()
		popup.clipboardButton:addToUIManager()

		popup:setVisible(false)
		popup.clipboardButton:setVisible(false)
	end
end
Events.OnCreatePlayer.Add(errorMagnifier.setErrorMagnifierButton)


---pass checks every tick
local function compareErrorCount() if errorMagnifier.errorCount ~= getLuaDebuggerErrorCount() then errorMagnifier.parseErrors() end end
Events.OnTickEvenPaused.Add(compareErrorCount)
Events.OnFETick.Add(compareErrorCount)