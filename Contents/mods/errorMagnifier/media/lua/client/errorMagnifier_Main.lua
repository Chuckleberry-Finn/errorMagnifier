local errorMagnifier = {}

errorMagnifier.parsedErrors = {} --{["error1"]=count1,["error2"]=count2}
errorMagnifier.parsedErrorsKeyed = {} --{[1]="error1",[2]="error2"}
errorMagnifier.errorTimestamps = {}
errorMagnifier.errorCount = 0

errorMagnifier.modReports = {}
errorMagnifier.cachedReports = {}

errorMagnifier.currentTab = "errors"
errorMagnifier.hiddenMode = false

errorMagnifier.lastCopiedKey = nil
errorMagnifier.lastCopiedTime = 0

--TODO: DISABLE THIS FOR RELEASE
errorMagnifier.spamErrorTest = false

errorMagnifier.colors = {
    modId = {1, 1, 0.3},
    normal = {0.9, 0.9, 0.9},
}


function errorMagnifier.getRealTimeStamp()
    local calendar = Calendar.getInstance()
    local year = calendar:get(Calendar.YEAR)
    local month = calendar:get(Calendar.MONTH) + 1
    local day = calendar:get(Calendar.DAY_OF_MONTH)
    return string.format("%04d-%02d-%02d", year, month, day)
end


function errorMagnifier.registerDebugReport(modId, reportFunc, displayName)
    if type(modId) ~= "string" or modId == "" then print("[ErrorMagnifier] registerDebugReport: Invalid modId") return false end
    if type(reportFunc) ~= "function" then print("[ErrorMagnifier] registerDebugReport: reportFunc must be a function") return false end
    
    errorMagnifier.modReports[modId] = {
        func = reportFunc,
        displayName = displayName or modId,
        registered = getTimestamp,
    }
    print("[ErrorMagnifier] Registered debug report for: " .. modId)
    return true
end


function errorMagnifier.unregisterDebugReport(modId)
    if errorMagnifier.modReports[modId] then
        errorMagnifier.modReports[modId] = nil
        errorMagnifier.cachedReports[modId] = nil
        return true
    end
    return false
end

function errorMagnifier.collectAllReports()
    errorMagnifier.cachedReports = {}
    
    for modId, reportData in pairs(errorMagnifier.modReports) do
        local success, result = pcall(reportData.func)
        if success then
            if type(result) == "table" then
                result = errorMagnifier.tableToString(result, 0)
            elseif type(result) ~= "string" then
                result = tostring(result)
            end
            errorMagnifier.cachedReports[modId] = {
                displayName = reportData.displayName,
                content = result,
                timestamp = getTimestamp
            }
        else
            errorMagnifier.cachedReports[modId] = {
                displayName = reportData.displayName,
                content = "Error collecting report: " .. tostring(result),
                timestamp = getTimestamp
            }
        end
    end
end


function errorMagnifier.refreshSingleReport(modId)
    local reportData = errorMagnifier.modReports[modId]
    if not reportData then return false end
    
    local success, result = pcall(reportData.func)
    if success then
        if type(result) == "table" then
            result = errorMagnifier.tableToString(result, 0)
        elseif type(result) ~= "string" then
            result = tostring(result)
        end
        errorMagnifier.cachedReports[modId] = {
            displayName = reportData.displayName,
            content = result,
            timestamp = getTimestamp
        }
    else
        errorMagnifier.cachedReports[modId] = {
            displayName = reportData.displayName,
            content = "Error collecting report: " .. tostring(result),
            timestamp = getTimestamp
        }
    end
    return true
end


function errorMagnifier.tableToString(tbl, indent)
    indent = indent or 0
    local result = {}
    local indentStr = string.rep("  ", indent)
    
    for k, v in pairs(tbl) do
        local keyStr = type(k) == "string" and k or "[" .. tostring(k) .. "]"
        if type(v) == "table" then
            table.insert(result, indentStr .. keyStr .. " = {")
            table.insert(result, errorMagnifier.tableToString(v, indent + 1))
            table.insert(result, indentStr .. "}")
        else
            local valStr = type(v) == "string" and '"' .. v .. '"' or tostring(v)
            table.insert(result, indentStr .. keyStr .. " = " .. valStr)
        end
    end
    
    return table.concat(result, "\n")
end


function errorMagnifier.parseErrors()
    local errors = getLuaDebuggerErrors()
    if errors:size() <= 0 then return end
    if not errorMagnifier.Button then return end

    errorMagnifier.Button:setVisible(not errorMagnifier.hiddenMode)

    local newErrors = {}

    for i = errorMagnifier.errorCount + 1, errors:size() do
        local str = errors:get(i - 1)
        str = str:gsub("\t", "    ")
        str = str:gsub("%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-\n", "")
        str = str:gsub("%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-\nSTACK TRACE\n%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-%-\n", "")
        str = str:gsub("reporting Lua stack trace%s*\n?", "")
        table.insert(newErrors, str)
    end

    for k, str in pairs(newErrors) do
        if type(str) == "string" then
            local causedBy = string.match(str, "Caused by: (.+)(... .-)")
            if causedBy then
                causedBy = "Caused by: " .. causedBy .. "\n"
                str = causedBy .. str
            end

            local callFrame = string.match(str, "Callframe at: (.-)") and string.sub(str, 1, string.len("Callframe at: ")) == "Callframe at: "
            if callFrame then
                local entryBefore = newErrors[k - 1]
                if entryBefore then
                    newErrors[k] = newErrors[k] .. "\n" .. entryBefore
                    newErrors[k - 1] = false
                end
            end

            local attemptedIndex = string.match(str, "java.lang.RuntimeException: attempted index: (.-) of ")
            if attemptedIndex then
                local entryBefore2 = newErrors[k - 2]
                local entryBefore = newErrors[k - 1]
                local entryAfter = newErrors[k + 1]
                if entryAfter then newErrors[k + 1] = false end
                if entryBefore then
                    newErrors[k] = entryBefore .. "\n" .. newErrors[k]
                    newErrors[k - 1] = false
                end
                if entryBefore2 then
                    newErrors[k] = entryBefore2 .. "\n" .. newErrors[k]
                    newErrors[k - 2] = false
                end
            end

            local jE = string.match(str, "at se.krka.kahlua.vm.KahluaThread.luaMainloop%(KahluaThread.java:(.-)%)")
            if jE and (not attemptedIndex) and (not callFrame) then
                local entryBefore = newErrors[k - 1]
                local entryAfter = newErrors[k + 1]
                if entryAfter then
                    newErrors[k] = entryAfter .. "\n" .. newErrors[k]
                    newErrors[k + 1] = false
                end
                if entryBefore and entryAfter and entryBefore == entryAfter then
                    newErrors[k - 1] = false
                end
            end
        end
    end

    local function isOrphanFragment(str)
        if not str or type(str) ~= "string" then return false end

        local hasStackMarkers = str:find("function:") or 
                                str:find("at se%.krka") or 
                                str:find("Callframe at:") or
                                str:find("MOD:") or
                                str:find("java%.lang%.")
        if hasStackMarkers then return false end

        local lineCount = select(2, str:gsub("\n", "\n")) + 1
        return lineCount <= 3
    end
    
    for k, str in pairs(newErrors) do
        if type(str) == "string" and isOrphanFragment(str) then
            local trimmedStr = str:gsub("^%s+", ""):gsub("%s+$", "")
            if #trimmedStr > 5 then
                for offset = -5, 5 do
                    if offset ~= 0 then
                        local otherEntry = newErrors[k + offset]
                        if otherEntry and type(otherEntry) == "string" and otherEntry ~= str then
                            if otherEntry:find(trimmedStr, 1, true) then
                                newErrors[k] = false
                                break
                            end
                        end
                    end
                end
            end
        end
    end

    for _, str in pairs(newErrors) do
        if type(str) == "string" then
            if not errorMagnifier.parsedErrors[str] then
                table.insert(errorMagnifier.parsedErrorsKeyed, str)
                errorMagnifier.parsedErrors[str] = 0
                errorMagnifier.errorTimestamps[str] = errorMagnifier.getRealTimeStamp()
            end
            errorMagnifier.parsedErrors[str] = errorMagnifier.parsedErrors[str] + 1
        end
    end

    errorMagnifier.errorCount = getLuaDebuggerErrors():size()

    if errorMagnifier.MainWindow.instance and errorMagnifier.MainWindow.instance:isVisible() and errorMagnifier.currentTab == "errors" then
        errorMagnifier.refreshErrorDisplay()
    end
end


errorMagnifier.MainWindow = ISCollapsableWindow:derive("ErrorMagnifierWindow")
errorMagnifier.MainWindow.instance = nil


function errorMagnifier.MainWindow:new(x, y, width, height)
    local o = ISCollapsableWindow:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    
    o.title = "Error Magnifier"
    o.resizable = true
    o.drawFrame = true
    o.moveWithMouse = true
    o.backgroundColor = {r = 0.1, g = 0.1, b = 0.1, a = 0.95}
    o.borderColor = {r = 0.4, g = 0.4, b = 0.4, a = 1}
    
    return o
end


function errorMagnifier.MainWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    
    local btnHeight = 24
    local tabY = self:titleBarHeight() + 4
    local contentY = tabY + btnHeight + 8

    self.errorsTabBtn = ISButton:new(10, tabY, 100, btnHeight, "Errors (0)", self, self.onTabClick)
    self.errorsTabBtn.internal = "errors"
    self.errorsTabBtn:initialise()
    self.errorsTabBtn:instantiate()
    self.errorsTabBtn.borderColor = {r = 0.5, g = 0.5, b = 0.5, a = 1}
    self:addChild(self.errorsTabBtn)
    
    self.reportsTabBtn = ISButton:new(115, tabY, 120, btnHeight, "Mods (0)", self, self.onTabClick)
    self.reportsTabBtn.internal = "reports"
    self.reportsTabBtn:initialise()
    self.reportsTabBtn:instantiate()
    self.reportsTabBtn.borderColor = {r = 0.5, g = 0.5, b = 0.5, a = 1}
    self:addChild(self.reportsTabBtn)

    local contentHeight = self.height - contentY - 46
    
    self.scrollPanel = ISScrollingListBox:new(10, contentY, self.width - 20, contentHeight)
    self.scrollPanel:initialise()
    self.scrollPanel:instantiate()
    self.scrollPanel.backgroundColor = {r = 0.05, g = 0.05, b = 0.05, a = 0.5}
    self.scrollPanel.borderColor = {r = 0.3, g = 0.3, b = 0.3, a = 0.5}
    self.scrollPanel:setAnchorRight(true)
    self.scrollPanel:setAnchorBottom(true)
    self.scrollPanel.itemheight = 100
    self.scrollPanel.selected = 0
    self.scrollPanel.doDrawItem = errorMagnifier.doDrawItem
    self.scrollPanel.onMouseUp = errorMagnifier.onListMouseUp
    self.scrollPanel.onMouseDown = errorMagnifier.onListMouseDown
    self:addChild(self.scrollPanel)

    local bottomY = self.height - 42

    self.copyAllBtn = ISButton:new(10, bottomY, 24, 24, "", self, self.onCopyAll)
    self.copyAllBtn:initialise()
    self.copyAllBtn:instantiate()
    self.copyAllBtn:setTooltip("Copy All to Clipboard")
    self.copyAllBtn:setImage(getTexture("common/media/textures/consolelogError.png"))
    self.copyAllBtn:setAnchorTop(false)
    self.copyAllBtn:setAnchorBottom(true)
    self:addChild(self.copyAllBtn)
    
    self.openLogsBtn = ISButton:new(42, bottomY, 24, 24, "", self, errorMagnifier.openLogsInExplorer)
    self.openLogsBtn:initialise()
    self.openLogsBtn:instantiate()
    self.openLogsBtn:setTooltip("Open Logs Folder")
    self.openLogsBtn:setImage(getTexture("common/media/textures/consolelogErrorFolder.png"))
    self.openLogsBtn:setAnchorTop(false)
    self.openLogsBtn:setAnchorBottom(true)
    self:addChild(self.openLogsBtn)
    
    self.clearBtn = ISButton:new(74, bottomY, 24, 24, "", self, self.onClear)
    self.clearBtn:initialise()
    self.clearBtn:instantiate()
    self.clearBtn:setTooltip("Clear All Errors")
    self.clearBtn:setImage(getTexture("common/media/textures/consolelogClear.png"))
    self.clearBtn:setAnchorTop(false)
    self.clearBtn:setAnchorBottom(true)
    self:addChild(self.clearBtn)

    self:setAlwaysOnTop(true)

    self:updateTabAppearance()
    errorMagnifier.refreshErrorDisplay()
end


function errorMagnifier.doDrawItem(self, y, item, alt)
    local data = item.item
    if not data then return y + self.itemheight end
    if item.height <= 0 then return y + item.height end

    if (y + self:getYScroll() + self.itemheight < 0) or (y + item.height + self:getYScroll() >= self.height) then return y + item.height end

    local itemPadding = 4
    local rowHeight = self.itemheight - itemPadding

    local scrollBarWidth = 0
    if self.vscroll and self.vscroll:isVisible() then
        scrollBarWidth = 13
    end
    local rowWidth = self.width - scrollBarWidth

    self:drawRect(0, y+rowHeight, rowWidth, 4, 0.8, 0.1, 0.1, 0.1)
    self:drawRectBorder(0, y, rowWidth, rowHeight, 0.8, 0.4, 0.4, 0.4)
    
    local font = UIFont.Small
    local fontH = getTextManager():getFontHeight(font)
    local padding = 6
    local c = errorMagnifier.colors

    local btnSize = math.min(24, rowHeight - 4)
    local btnX = rowWidth - btnSize - padding + 6
    local btnY = y + rowHeight - btnSize - padding + 4

    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local isHovered = mouseX >= btnX and mouseX <= btnX + btnSize and mouseY >= btnY and mouseY <= btnY + btnSize
    
    if isHovered then
        self:drawRect(btnX, btnY, btnSize, btnSize, 0.4, 0.3, 0.5, 0.7)
    end

    local clipTexture = getTexture("common/media/textures/clipboardError.png")
    if clipTexture then
        self:drawTextureScaled(clipTexture, btnX + 2, btnY + 2, btnSize - 4, btnSize - 4, 1, 1, 1, 1)
    end

    local currentTime = getTimestampMs()
    local itemKey = data.isError and data.index or data.modId
    if errorMagnifier.lastCopiedKey == itemKey and itemKey and (currentTime - errorMagnifier.lastCopiedTime) < 1500 then
        local feedbackText = "Copied!"
        self:drawTextRight(feedbackText, btnX - 4, btnY + (btnSize - fontH) / 2, 0.3, 0.8, 0.5, 1, font)
    end

    if data.isError then
        local errorText = data.text or ""
        local count = data.count or 1
        local index = data.index or 0
        local timestamp = data.timestamp or ""
        local total = #errorMagnifier.parsedErrorsKeyed
        if total == 0 then total = 1 end

        if timestamp ~= "" then
            self:drawTextRight(timestamp, rowWidth - 8, y + padding, 0.6, 0.8, 0.6, 0.9, font)
        end

        local countText = index .. " out of " .. total
        self:drawTextRight(countText, rowWidth - 8, y + padding + fontH + 2, 0.7, 0.7, 0.7, 0.8, font)

        local xText = "x" .. count
        self:drawTextRight(xText, rowWidth - 8, y + padding + fontH * 2 + 4, 0.9, 0.9, 0.9, 1, font)

        local lines = errorText:gsub("\r\n", "\n"):gsub("\r", "\n"):split("\n")
        local textY = y + padding

        for _, line in ipairs(lines) do
            if textY + fontH > y + rowHeight - padding then break end

            local modStart = line:find("MOD:%s*")
            if modStart then
                local modColonEnd = line:find(":", modStart) + 1
                local afterMod = line:sub(modColonEnd)
                local leadingSpace = afterMod:match("^(%s*)") or ""
                afterMod = afterMod:gsub("^%s+", "")

                local javaStart = afterMod:find("[a-z]+%.[a-z]")
                
                local modId
                local remainder
                if javaStart and javaStart > 1 then
                    modId = afterMod:sub(1, javaStart - 1):gsub("%s+$", "")
                    remainder = afterMod:sub(javaStart)
                else
                    modId = afterMod:gsub("%s+$", "")
                    remainder = ""
                end

                local beforeMod = line:sub(1, modStart - 1)
                local xPos = padding
                if beforeMod ~= "" then
                    self:drawText(beforeMod, xPos, textY, c.normal[1], c.normal[2], c.normal[3], 0.95, font)
                    xPos = xPos + getTextManager():MeasureStringX(font, beforeMod)
                end

                local modText = "MOD:" .. leadingSpace .. modId
                self:drawText(modText, xPos, textY, c.modId[1], c.modId[2], c.modId[3], 1, font)
                xPos = xPos + getTextManager():MeasureStringX(font, modText)

                if remainder and remainder ~= "" then
                    self:drawText(remainder, xPos, textY, c.normal[1], c.normal[2], c.normal[3], 0.95, font)
                end
            else
                self:drawText(line, padding, textY, c.normal[1], c.normal[2], c.normal[3], 0.95, font)
            end
            
            textY = textY + fontH
        end

    else
        local modId = data.modId
        local displayName = data.displayName or modId
        local hasReport = data.hasReport
        local errorCount = data.errorCount or 0
        local textY = y + (rowHeight - fontH) / 2
        local xPos = padding

        self:drawText(displayName, xPos, textY, c.modId[1], c.modId[2], c.modId[3], 1, font)
        xPos = xPos + getTextManager():MeasureStringX(font, displayName) + 8

        if displayName ~= modId then
            local idText = "[" .. modId .. "]"
            self:drawText(idText, xPos, textY, 0.6, 0.6, 0.6, 0.7, font)
            xPos = xPos + getTextManager():MeasureStringX(font, idText) + 12
        else
            xPos = xPos + 4
        end

        if hasReport then
            self:drawText("Report: Yes", xPos, textY, 0.5, 0.8, 0.5, 0.9, font)
        else
            self:drawText("Report: No", xPos, textY, 0.6, 0.6, 0.6, 0.5, font)
        end
        xPos = xPos + getTextManager():MeasureStringX(font, "Report: Yes") + 12

        if errorCount > 0 then
            local errText = "Errors: " .. errorCount
            self:drawText(errText, xPos, textY, 0.8, 0.4, 0.4, 1, font)
        else
            self:drawText("Errors: 0", xPos, textY, 0.5, 0.5, 0.5, 0.5, font)
        end
    end
    
    return y + self.itemheight
end


function errorMagnifier.getErrorsForMod(modId)
    local errors = {}
    local searchPattern = "MOD: " .. modId
    local searchPattern2 = "MOD:" .. modId
    for _, errorText in ipairs(errorMagnifier.parsedErrorsKeyed) do
        if errorText:find(searchPattern, 1, true) or errorText:find(searchPattern2, 1, true) then
            local count = errorMagnifier.parsedErrors[errorText] or 1
            table.insert(errors, {text = errorText, count = count})
        end
    end
    return errors
end


function errorMagnifier.getModIdsFromErrors()
    local modIds = {}
    local seen = {}
    for _, errorText in ipairs(errorMagnifier.parsedErrorsKeyed) do
        -- Process line by line to extract MOD: names
        for line in errorText:gmatch("[^\n]+") do
            local modStart = line:find("MOD:%s*")
            if modStart then
                -- Get everything after "MOD:"
                local afterMod = line:sub(modStart + 4):gsub("^%s+", "")  -- Skip "MOD:" and trim leading space

                -- Stop at java package names or end of line
                local javaStart = afterMod:find("[a-z]+%.[a-z]")
                local modId
                if javaStart and javaStart > 1 then
                    modId = afterMod:sub(1, javaStart - 1):gsub("%s+$", "")  -- Trim trailing space
                else
                    modId = afterMod:gsub("%s+$", "")  -- Just trim trailing space
                end

                if modId and modId ~= "" and not seen[modId] then
                    seen[modId] = true
                    table.insert(modIds, modId)
                end
            end
        end
    end
    return modIds
end


function errorMagnifier.onListMouseDown()
    return false
end

function errorMagnifier.onListMouseUp(self, x, y)
    local scrollBarWidth = 0
    if self.vscroll and self.vscroll:isVisible() then
        scrollBarWidth = 13
    end
    local rowWidth = self.width - scrollBarWidth

    for i, item in ipairs(self.items) do
        local itemTop = (i - 1) * self.itemheight
        local itemBottom = itemTop + self.itemheight
        
        local mouseYScrollAdjusted = y
        
        if mouseYScrollAdjusted >= itemTop and mouseYScrollAdjusted < itemBottom then
            local padding = 6
            local itemPadding = 4
            local rowHeight = self.itemheight - itemPadding
            local btnSize = math.min(24, rowHeight - 4)
            local btnX = rowWidth - btnSize - padding + 6
            local btnY = itemTop + rowHeight - btnSize - padding + 4
            
            if x >= btnX and x <= btnX + btnSize and mouseYScrollAdjusted >= btnY and mouseYScrollAdjusted <= btnY + btnSize then
                local data = item.item
                if data then
                    local textToCopy = ""
                    if data.isError then
                        local count = data.count or 1
                        textToCopy = "```\n[x" .. count .. "]\n" .. (data.text or "") .. "\n```"
                    elseif data.modId and data.modId ~= "help" then
                        textToCopy = "```\n[" .. data.modId .. " - Mod Report]\n"

                        if data.hasReport then
                            errorMagnifier.refreshSingleReport(data.modId)
                            local freshReport = errorMagnifier.cachedReports[data.modId]
                            if freshReport then
                                textToCopy = textToCopy .. freshReport.content .. "\n"
                            end
                        end

                        local modErrors = errorMagnifier.getErrorsForMod(data.modId)
                        if #modErrors > 0 then
                            textToCopy = textToCopy .. "\n--- Associated Errors (" .. #modErrors .. ") ---\n"
                            for _, err in ipairs(modErrors) do
                                textToCopy = textToCopy .. "\n[x" .. err.count .. "]\n" .. err.text .. "\n"
                            end
                        elseif not data.hasReport then
                            textToCopy = textToCopy .. "\nNo report data or errors found.\n"
                        end
                        textToCopy = textToCopy .. "```"
                    end
                    
                    if textToCopy ~= "" then
                        Clipboard.setClipboard(textToCopy)
                        errorMagnifier.lastCopiedKey = data.isError and data.index or data.modId
                        errorMagnifier.lastCopiedTime = getTimestampMs()
                        print("[ErrorMagnifier] Copied to clipboard!")
                        getSoundManager():playUISound("UISelectListItem")
                    end
                end
                return true
            end
            break
        end
    end

    return ISScrollingListBox.onMouseUp(self, x, y)
end


function errorMagnifier.MainWindow:onTabClick(button)
    errorMagnifier.currentTab = button.internal
    errorMagnifier.lastCopiedKey = nil
    self:updateTabAppearance()
    
    if errorMagnifier.currentTab == "errors" then
        self.scrollPanel.itemheight = 100
        errorMagnifier.refreshErrorDisplay()
    else
        self.scrollPanel.itemheight = 32
        errorMagnifier.collectAllReports()
        errorMagnifier.refreshReportDisplay()
    end
end


function errorMagnifier.MainWindow:updateTabAppearance()
    local activeColor = {r = 0.67, g = 0.12, b = 0.12, a = 1}
    local inactiveColor = {r = 0.2, g = 0.2, b = 0.2, a = 0.8}
    
    if errorMagnifier.currentTab == "errors" then
        self.errorsTabBtn.backgroundColor = activeColor
        self.reportsTabBtn.backgroundColor = inactiveColor
        if self.clearBtn then self.clearBtn:setVisible(true) end
        if self.openLogsBtn then self.openLogsBtn:setVisible(true) end
    else
        self.errorsTabBtn.backgroundColor = inactiveColor
        self.reportsTabBtn.backgroundColor = activeColor
        if self.clearBtn then self.clearBtn:setVisible(false) end
        if self.openLogsBtn then self.openLogsBtn:setVisible(false) end
    end
    
    self.errorsTabBtn:setTitle("Errors (" .. #errorMagnifier.parsedErrorsKeyed .. ")")

    local modCount = 0
    local seenMods = {}
    for modId in pairs(errorMagnifier.modReports) do
        seenMods[modId] = true
        modCount = modCount + 1
    end
    for _, modId in ipairs(errorMagnifier.getModIdsFromErrors()) do
        if not seenMods[modId] then
            modCount = modCount + 1
        end
    end
    self.reportsTabBtn:setTitle("Mods (" .. modCount .. ")")
end


function errorMagnifier.MainWindow:onRefresh()
    if errorMagnifier.currentTab == "errors" then
        errorMagnifier.refreshErrorDisplay()
    else
        errorMagnifier.collectAllReports()
        errorMagnifier.refreshReportDisplay()
    end
    self:updateTabAppearance()
end


function errorMagnifier.MainWindow:onCopyAll()
    local text = ""
    if #errorMagnifier.parsedErrorsKeyed <= 0 then return end
    
    if errorMagnifier.currentTab == "errors" then
        for i, errorText in ipairs(errorMagnifier.parsedErrorsKeyed) do
            local count = errorMagnifier.parsedErrors[errorText] or 1
            text = text .. "=== Error #" .. i .. " (x" .. count .. ") ===\n"
            text = text .. errorText .. "\n\n"
        end
    else
        local allMods = {}
        local seenMods = {}
        
        for modId, reportData in pairs(errorMagnifier.cachedReports) do
            seenMods[modId] = true
            allMods[modId] = {hasReport = true, displayName = reportData.displayName}
        end
        
        for _, modId in ipairs(errorMagnifier.getModIdsFromErrors()) do
            if not seenMods[modId] then
                allMods[modId] = {hasReport = false, displayName = modId}
            end
        end
        
        for modId, info in pairs(allMods) do
            text = text .. "=== " .. info.displayName .. " [" .. modId .. "] ===\n"
            
            if info.hasReport then
                errorMagnifier.refreshSingleReport(modId)
                local reportData = errorMagnifier.cachedReports[modId]
                if reportData then
                    text = text .. reportData.content .. "\n"
                end
            end
            
            local modErrors = errorMagnifier.getErrorsForMod(modId)
            if #modErrors > 0 then
                text = text .. "--- Errors (" .. #modErrors .. ") ---\n"
                for _, err in ipairs(modErrors) do
                    text = text .. "[x" .. err.count .. "] " .. err.text .. "\n"
                end
            end
            text = text .. "\n"
        end
    end
    
    if text ~= "" then
        Clipboard.setClipboard(text)
        print("[ErrorMagnifier] Copied to clipboard!")
    end
end


function errorMagnifier.MainWindow:onClear()
    if errorMagnifier.currentTab == "errors" then
        errorMagnifier.parsedErrors = {}
        errorMagnifier.parsedErrorsKeyed = {}
        errorMagnifier.errorTimestamps = {}
        errorMagnifier.errorCount = getLuaDebuggerErrors():size()
        errorMagnifier.refreshErrorDisplay()
    else
        errorMagnifier.cachedReports = {}
        errorMagnifier.refreshReportDisplay()
    end
    self:updateTabAppearance()
end


function errorMagnifier.MainWindow:onMouseWheel(del)
    self.scrollPanel:onMouseWheel(del)
    return true
end


function errorMagnifier.MainWindow:prerender()
    ISCollapsableWindow.prerender(self)
end


function errorMagnifier.MainWindow:render()
    ISCollapsableWindow.render(self)
end


function errorMagnifier.MainWindow:close()
    self:setVisible(false)
    self:removeFromUIManager()
end


function errorMagnifier.refreshErrorDisplay()
    if not errorMagnifier.MainWindow.instance or not errorMagnifier.MainWindow.instance.scrollPanel then return end
    
    local scrollPanel = errorMagnifier.MainWindow.instance.scrollPanel
    scrollPanel:clear()
    
    if #errorMagnifier.parsedErrorsKeyed == 0 then
        scrollPanel:addItem("No errors detected!", {isError = true, text = "No errors detected!\n\nErrors will appear here when they occur.", count = 0, index = 0, timestamp = ""})
    else
        for i, errorText in ipairs(errorMagnifier.parsedErrorsKeyed) do
            local count = errorMagnifier.parsedErrors[errorText] or 1
            local timestamp = errorMagnifier.errorTimestamps[errorText] or ""
            scrollPanel:addItem("Error " .. i, {isError = true, text = errorText, count = count, index = i, timestamp = timestamp})
        end
    end
end


function errorMagnifier.refreshReportDisplay()
    if not errorMagnifier.MainWindow.instance or not errorMagnifier.MainWindow.instance.scrollPanel then return end
    
    local scrollPanel = errorMagnifier.MainWindow.instance.scrollPanel
    scrollPanel:clear()
    
    local allMods = {}
    
    for modId, reportData in pairs(errorMagnifier.cachedReports) do
        local errorCount = #errorMagnifier.getErrorsForMod(modId)
        allMods[modId] = {
            hasReport = true,
            displayName = reportData.displayName,
            errorCount = errorCount
        }
    end
    
    local errorModIds = errorMagnifier.getModIdsFromErrors()
    for _, modId in ipairs(errorModIds) do
        if not allMods[modId] then
            local errorCount = #errorMagnifier.getErrorsForMod(modId)
            allMods[modId] = {
                hasReport = false,
                displayName = modId,
                errorCount = errorCount
            }
        end
    end
    
    local hasItems = false
    for modId, info in pairs(allMods) do
        hasItems = true
        scrollPanel:addItem(info.displayName, {
            isError = false,
            modId = modId,
            hasReport = info.hasReport,
            displayName = info.displayName,
            errorCount = info.errorCount
        })
    end
    
    if not hasItems then
        scrollPanel:addItem("No mods", {
            isError = false,
            modId = "help",
            hasReport = false,
            displayName = "No mods with errors or reports",
            errorCount = 0
        })
    end
end


errorMagnifier.Button = nil
function errorMagnifier:EMButtonOnClick()
    if errorMagnifier.MainWindow.instance and errorMagnifier.MainWindow.instance:isVisible() then
        errorMagnifier.MainWindow.instance:close()
    else
        errorMagnifier.showMainWindow()
    end
end


function errorMagnifier.showMainWindow()
    local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()
    local winWidth = math.min(800, screenWidth * 0.6)
    local winHeight = math.min(600, screenHeight * 0.7)
    local x = (screenWidth - winWidth) / 2
    local y = (screenHeight - winHeight) / 2
    
    if not errorMagnifier.MainWindow.instance then
        errorMagnifier.MainWindow.instance = errorMagnifier.MainWindow:new(x, y, winWidth, winHeight)
        errorMagnifier.MainWindow.instance:initialise()
        errorMagnifier.MainWindow.instance:instantiate()
    end
    
    errorMagnifier.MainWindow.instance:addToUIManager()
    errorMagnifier.MainWindow.instance:setVisible(true)
    errorMagnifier.MainWindow.instance:bringToTop()
    
    if errorMagnifier.currentTab == "errors" then
        errorMagnifier.refreshErrorDisplay()
    else
        errorMagnifier.collectAllReports()
        errorMagnifier.refreshReportDisplay()
    end
    
    errorMagnifier.MainWindow.instance:updateTabAppearance()
end


function errorMagnifier.hideErrorMag()
    if errorMagnifier.MainWindow.instance then
        errorMagnifier.MainWindow.instance:close()
    end
    if errorMagnifier.Button then
        errorMagnifier.Button:setVisible(false)
    end
    errorMagnifier.hiddenMode = true
end


function errorMagnifier.onResolutionChange()
    local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()
    local errorMagTexture = getTexture("common/media/textures/magGlassError.png")
    local eW, eH = errorMagTexture:getWidth(), errorMagTexture:getHeight()
    local x = screenWidth - eW - 4
    local y = MainScreen.instance and MainScreen.instance.resetLua and MainScreen.instance.resetLua.y - 2 or (screenHeight - eH - 4)

    if errorMagnifier.Button then
        errorMagnifier.Button:setX(x)
        errorMagnifier.Button:setY(y)
    end
end


function errorMagnifier.openLogsInExplorer()
    local cacheDir = Core.getMyDocumentFolder()
    if isDesktopOpenSupported() then showFolderInDesktop(cacheDir)
    else openUrl(cacheDir)
    end
end


function errorMagnifier.setErrorMagnifierButton()
    local errorMagTexture = getTexture("common/media/textures/magGlassError.png")
    local eW, eH = errorMagTexture:getWidth(), errorMagTexture:getHeight()

    local screenWidth, screenHeight = getCore():getScreenWidth(), getCore():getScreenHeight()

    local x = screenWidth - eW - 4
    local y = MainScreen.instance and MainScreen.instance.resetLua and MainScreen.instance.resetLua.y - 2 or (screenHeight - eH - 4)

    if getWorld():getGameMode() == "Multiplayer" then
        y = y - 22
    end

    errorMagnifier.Button = errorMagnifier.Button or ISButton:new(x, y + 10, 22, 22, "", nil, errorMagnifier.EMButtonOnClick)
    errorMagnifier.Button.onRightMouseUp = errorMagnifier.hideErrorMag
    errorMagnifier.Button:setImage(errorMagTexture)
    errorMagnifier.Button:setDisplayBackground(false)
    errorMagnifier.Button:setAnchorLeft(false)
    errorMagnifier.Button:setAnchorTop(false)
    errorMagnifier.Button:setAnchorRight(true)
    errorMagnifier.Button:setAnchorBottom(true)
    errorMagnifier.Button:initialise()
    errorMagnifier.Button:addToUIManager()
    errorMagnifier.Button:setAlwaysOnTop(true)

    local inGame = (MainScreen.instance and MainScreen.instance.inGame == true)
    errorMagnifier.Button:setVisible(not inGame)
end


local MainScreen_onEnterFromGame = MainScreen.onEnterFromGame
function MainScreen:onEnterFromGame()
    MainScreen_onEnterFromGame(self)
    if errorMagnifier.Button then
        errorMagnifier.Button:setVisible(true)
    end
end


local MainScreen_onReturnToGame = MainScreen.onReturnToGame
function MainScreen:onReturnToGame()
    MainScreen_onReturnToGame(self)
    if errorMagnifier.hiddenMode or #errorMagnifier.parsedErrorsKeyed <= 0 then
        errorMagnifier.hideErrorMag()
    end
end


function errorMagnifier:getErrorOntoClipboard(errorIndex)
    local errorText = errorMagnifier.parsedErrorsKeyed[errorIndex]
    if errorText then
        local count = errorMagnifier.parsedErrors[errorText] or 1
        Clipboard.setClipboard("```\n[x" .. count .. "]\n" .. errorText .. "\n```")
        print("[ErrorMagnifier] Copied error #" .. errorIndex .. " to clipboard!")
    end
end

return errorMagnifier
