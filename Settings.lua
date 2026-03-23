DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked

local create_new_setting
local create_new_button
local ST

-- name, display_name, default_value, tooltip, callback
local settings_list
local button_list

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

    button_list = 
    {
{"Clear Match History", "Clears your entire (ACCOUNT-WIDE) match history and resets all your statistics. Cannot be undone.", DRU.ConfirmWipe}
    }
    
    DRU.settingsPanel = CreateFrame("Frame")
    DRU.settingsCategory = Settings.RegisterCanvasLayoutCategory(DRU.settingsPanel, "DeathRoll Unlocked")
    
    for _, setting in ipairs(settings_list) do
        create_new_setting(unpack(setting))
    end

    for _, button in ipairs(button_list) do
        create_new_button(unpack(button))
    end

    Settings.RegisterAddOnCategory(DRU.settingsCategory)
end


local next_y = -10
function create_new_setting(name, display_name, default_value, tooltip, callback_func)
    Settings.RegisterAddOnSetting(DRU.settingsCategory, name, name, DRUDB.settings, type(default_value), display_name, default_value)
    local settings_obj = Settings.GetSetting(name)

    local checkbox = CreateFrame("CheckButton", nil, DRU.settingsPanel, "UICheckButtonTemplate")
    checkbox:SetPoint("TOPLEFT", DRU.settingsPanel, "TOPLEFT", 10, next_y)
    checkbox:SetChecked(settings_obj:GetValue())

    checkbox.text:SetText(display_name)
    checkbox.text:SetScale(1.2)

    checkbox:SetScript("OnClick", function(self)
        local value = self:GetChecked()
        settings_obj:SetValue(value)
        if callback_func then callback_func(value) end
    end)

    if tooltip then
        checkbox:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            GameTooltip:Show()
        end)
        checkbox:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    next_y = next_y - 30
    return checkbox
end

function create_new_button(display_name, tooltip, callback_func)
    local button = CreateFrame("Button", nil, DRU.settingsPanel, "UIPanelButtonTemplate")
    button:SetPoint("TOPLEFT", DRU.settingsPanel, "TOPLEFT", 10, next_y)
    button:SetText(display_name)
    button:SetWidth(button:GetTextWidth() + 30)
    button:SetHeight(25)

    button:SetScript("OnClick", function()
        if callback_func then callback_func() end
    end)

    if tooltip then
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltip, 1, 1, 1)
            GameTooltip:Show()
        end)
        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    next_y = next_y - 30
    return button
end