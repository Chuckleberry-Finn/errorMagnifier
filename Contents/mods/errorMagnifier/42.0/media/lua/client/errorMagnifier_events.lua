local errorMagnifier = require "errorMagnifier_Main"
if not errorMagnifier then return end


Events.OnLoad.Add(errorMagnifier.setErrorMagnifierButton)
Events.OnMainMenuEnter.Add(errorMagnifier.setErrorMagnifierButton)

-- Compare error count every tick to detect new errors
local function compareErrorCount()
    if errorMagnifier and errorMagnifier.errorCount ~= getLuaDebuggerErrors():size() then
        errorMagnifier.parseErrors()
        
        -- Flash the button or show notification when new errors appear
        if errorMagnifier.Button and not errorMagnifier.Button:isVisible() and not errorMagnifier.hiddenMode then
            errorMagnifier.Button:setVisible(true)
        end
    end
end

Events.OnTickEvenPaused.Add(compareErrorCount)
Events.OnFETick.Add(compareErrorCount)

Events.OnResolutionChange.Add(errorMagnifier.onResolutionChange)


if getDebug() and errorMagnifier.spamErrorTest then

    if errorMagnifier.showOnDebug then
        local bump = errorMagnifier.EMButtonOnClick
        errorMagnifier.EMButtonOnClick = function()
            local errors = getLuaDebuggerErrors()
            if errors:size() <= 0 then
                getSpecificPlayer("mango") -- Intentionally cause an error for testing
            end
            bump(errorMagnifier)
        end
    end

    local function ERRORS()
        Events.OnPlayerMove.Add(function() local testString = "test" .. true end)
        Events.OnPlayerMove.Add(function() if 1 <= "a" then print("miracles happen") end end)
        Events.OnPlayerMove.Add(function() local paradox = 1 + "a" end)
        Events.OnPlayerMove.Add(function() string.match(nil, "paradox") end)
        Events.OnPlayerMove.Add(function() local paradox = 1 - "a" end)
        Events.OnPlayerMove.Add(function() DebugLogStream.printException() end)
        Events.OnPlayerMove.Add(function() local paradox = 1 / "a" end)
        Events.OnPlayerMove.Add(function() local paradox = true + 1 end)
        Events.OnPlayerMove.Add(function() getSpecificPlayer("apple") end)
    end
    Events.OnMainMenuEnter.Add(ERRORS)
end





if getDebug() then
    -- EXAMPLE: debug dump for ErrorMagnifier itself
    errorMagnifier.registerDebugDump("errorMagnifier", function()
        return {
            errorCount = errorMagnifier.errorCount,
            uniqueErrors = #errorMagnifier.parsedErrorsKeyed,
            registeredMods = (function()
                local count = 0
                for _ in pairs(errorMagnifier.modDumps) do count = count + 1 end
                return count
            end)(),
            hiddenMode = errorMagnifier.hiddenMode,
            currentTab = errorMagnifier.currentTab,
            windowVisible = errorMagnifier.MainWindow.instance and errorMagnifier.MainWindow.instance:isVisible() or false,
        }
    end, "errorMagnifier")
end