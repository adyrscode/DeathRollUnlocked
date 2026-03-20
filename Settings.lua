DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked

local create_new_setting
local ST

-- name, display_name, default_value, tooltip, callback
local settings_list

function DRU.InitSettings()
    DRUDB.settings = DRUDB.settings or {}
    ST = DRUDB.settings
    settings_list = 
    {
{"dr_button", "DeathRoll Button", true, "Toggles the deathrolling button (can also be toggled with /drbutton or /drb).", DRU.ToggleButton},
{"dr_menu", "DeathRoll Menu", true, "Toggles the deathrolling menu (can also be toggled with /drmenu or /drm).", DRU.ToggleMenu},
{"textbox", "Roll/Wager Box", true, "Toggles the textbox under the deathrolling button where you can enter your roll and wager.", DRU.ToggleTextbox},
{"prints", "Chat Messages", true, "Toggles the addons' information and alerts in chat. Recommended to keep enabled, as this includes error messages.", nil}
    }
    
    DRU.settingsCategory = Settings.RegisterVerticalLayoutCategory("DeathRoll Unlocked")
    
    for _, setting in ipairs(settings_list) do
        create_new_setting(unpack(setting))
    end

    Settings.RegisterAddOnCategory(DRU.settingsCategory)
end

function create_new_setting(name, display_name, default_value, tooltip, callback_func)
    Settings.RegisterAddOnSetting(DRU.settingsCategory, name, name, DRUDB.settings, type(default_value), display_name, default_value)
    Settings.CreateCheckbox(DRU.settingsCategory, Settings.GetSetting(name), tooltip)
    local settings_obj = Settings.GetSetting(name)
    settings_obj:SetValueChangedCallback(function(_, value)
        if callback_func then callback_func(value) end
    end)
end

