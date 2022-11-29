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


--[[
self.addStockBtn = ISButton:new(manageStockButtonsX-22, manageStockButtonsY+5, btnHgt-3, btnHgt-3, "+", self, storeWindow.onClick)
self.addStockBtn.internal = "ADDSTOCK"
self.addStockBtn:initialise()
self.addStockBtn:instantiate()
self:addChild(self.addStockBtn)
--]]

--[[
local font = getCore():getOptionTooltipFont()
local fontType = fontDict[font] or UIFont.Medium
local textWidth = math.max(getTextManager():MeasureStringX(fontType, tooltipStart),getTextManager():MeasureStringX(fontType, skillsRecord))
local textHeight = getTextManager():MeasureStringY(fontType, tooltipStart)
self:drawRect(0, tooltipY, journalTooltipWidth, textHeight + 8, math.min(1,bgColor.a+0.4), bgColor.r, bgColor.g, bgColor.b)
self:drawRectBorder(0, tooltipY, journalTooltipWidth, textHeight + 8, bdrColor.a, bdrColor.r, bdrColor.g, bdrColor.b)
self:drawText(skillsRecord, x+1, (y+(15-lineHeight)/2), fnt.r, fnt.g, fnt.b, fnt.a, fontType)
--]]

errorMagnifier.popupPanel = ISPanel:derive("errorMagnifier.popupPanel")

---@type ISButton
errorMagnifier.Button = false
errorMagnifier.currentlyViewing = 1
errorMagnifier.maxErrorsViewable = 3
function errorMagnifier.errorPanelPopulate()
	if not errorMagnifier.Button then return end

	if #errorMagnifier.parsedErrorsKeyed <= 0 or (errorMagnifier.errorMessage1 and errorMagnifier.errorMessage1:isVisible()) then
		for i=1, errorMagnifier.maxErrorsViewable do errorMagnifier["errorMessage"..i]:setVisible(false) end
		return
	end

	for i=1, math.min(#errorMagnifier.parsedErrorsKeyed,errorMagnifier.maxErrorsViewable) do
		---@type ISPanel
		local popup = errorMagnifier["errorMessage"..i]

		local errorText = errorMagnifier.parsedErrorsKeyed[errorMagnifier.currentlyViewing-1+i]
		local countOf = "x"..errorMagnifier.parsedErrors[errorText]

		local countOfWidth = getTextManager():MeasureStringX(UIFont.NewSmall, countOf)
		local countOfHeight = getTextManager():MeasureStringY(UIFont.NewSmall, countOf)

		popup:drawRect(4, 4, popup:getWidth()-8, popup:getHeight()-8, 0.2, 0.2, 0.2, 0.2)
		popup:drawText(errorText, 3, 3, 0.9, 0.9, 0.9, 0.9, UIFont.NewSmall)
		popup:drawText(countOf, popup:getWidth()-countOfWidth-4, 0-countOfHeight-4, 0.9, 0.9, 0.9, 0.9, UIFont.NewSmall)

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

	local popupX = 0-popupWidth+(errorMagnifier.Button:getWidth()*1.25)

	for i=1, errorMagnifier.maxErrorsViewable do
		errorMagnifier["errorMessage"..i] = errorMagnifier.popupPanel:new(popupX,0-15-((popupHeight+4)*i), popupWidth, popupHeight)
		---@type ISPanel
		local popup = errorMagnifier["errorMessage"..i]
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