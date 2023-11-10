local errorMagnifier = require "errorMagnifier_Main"
if not errorMagnifier then return end

Events.OnLoad.Add(errorMagnifier.setErrorMagnifierButton)
Events.OnGameBoot.Add(errorMagnifier.setErrorMagnifierButton)

---pass checks every tick
local function compareErrorCount() if errorMagnifier and errorMagnifier.errorCount ~= getLuaDebuggerErrors():size() then errorMagnifier.parseErrors() end end
Events.OnTickEvenPaused.Add(compareErrorCount)
Events.OnFETick.Add(compareErrorCount)


local modCountSystem = require "chuckleberryFinnModding_modCountSystem"
if modCountSystem then modCountSystem.pullAndAddModID()
else print("ERR: MISSING MOD: `ChuckleberryFinnAlertSystem` (Workshop ID: `3077900375`)") end


--TODO: DISABLE BEFORE RELEASE
if getDebug() and errorMagnifier.spamErrorTest then

    if errorMagnifier.showOnDebug then
        local bump = errorMagnifier.EMButtonOnClick
        errorMagnifier.EMButtonOnClick = function()
            local errors = getLuaDebuggerErrors()
            if errors:size() <= 0 then getSpecificPlayer("mango") end
            bump(errorMagnifier)
        end
    end

    local function ERRORS()
        Events.OnPlayerMove.Add( function() local testString = "test"..true end)
        Events.OnPlayerMove.Add( function() if 1 <= "a" then print("miracles happen") end end)
        Events.OnPlayerMove.Add( function() local paradox = 1+"a" end)
        Events.OnPlayerMove.Add( function() string.match(nil,"paradox") end)
        Events.OnPlayerMove.Add( function() local paradox = 1-"a" end)
        Events.OnPlayerMove.Add( function() DebugLogStream.printException() end)
        Events.OnPlayerMove.Add( function() local paradox = 1/"a" end)
        Events.OnPlayerMove.Add( function() local paradox = true+1 end)
        Events.OnPlayerMove.Add( function() getSpecificPlayer("apple") end)
    end
    Events.OnMainMenuEnter.Add(ERRORS)
end