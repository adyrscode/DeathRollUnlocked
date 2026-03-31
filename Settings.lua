DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked

local create_new_setting
local create_new_button
local create_tutorial_text
local create_heading
local create_text
local ST
local t -- everything to do with the wall of text

local deathroll_tutorial = [[
Deathrolling is a gambling minigame between 2 players. They both agree on a |cffffff00wager|r and a |cffffff00starting roll|r. Players take turns rolling each others rolls until one of them hits 1. That player loses.

A typical deathroll looks like:
Bob and Alice agree to deathroll for |cffffff0010 gold|r, starting from |cffffff00100|r.
Alice begins and rolls |cffffff0056|r out of |cffffff00100|r.
Bob then rolls Alice's roll and rolls |cffffff0022|r out of |cffffff0056|r.
Alice rolls |cffffff009|r out of |cffffff0022|r.
Bob gets unlucky and rolls |cffffff001 out of 9|r. He has lost the deathroll and gives |cffffff0010 gold|r to Alice.
]]
local DRU_tutorial = [[
Target the player you want to roll and use |cffffff00/dr <roll> <wager>|r to start a deathroll.
You can also enter |cffffff00<roll> <wager>|r into the box under the button and press it.

When you're in a game, you can just use |cffffff00/dr|r or use the button to automatically roll.

You can also choose to over/underbet them by using |cffffff00/dr <opponent's roll> <different wager>|r (make sure to enter their roll, not the starting roll.)
To cancel a roll at any point, use |cffffff00/drcancel|r.

To see your match history and statistics, you can look at the |cffffff00DRU Menu|r. Click on a game to see all the details of the deathroll.
Use |cffffff00/drmenu|r or |cffffff00/drm|r to toggle the menu's visibility.

To see who wants to deathroll you, use |cffffff00/drgames|r (These are only requests from people who also have the addon).
To clear your request list, use |cffffff00/drclear|r.

Type |cffffff00/drhelp|r to see these commands at any point.
]]

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
{"textbox", "Roll/Wager Box", true, "Toggles the textbox below the deathrolling button where you can enter your roll and wager.", DRU.ToggleTextbox},
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

    create_tutorial_text()

    Settings.RegisterAddOnCategory(DRU.settingsCategory)
end

function create_tutorial_text()
    DRU.settingsPanel.tutorial = CreateFrame("Frame", "DeathRollFrame", DRU.settingsPanel)
    t = DRU.settingsPanel.tutorial
    t:SetSize(375, 550)
    t:SetPoint("TOPLEFT", DRU.settingsPanel, "TOP", -50, 0)

    -- t.bg = t:CreateTexture(nil, "BACKGROUND")
    -- t.bg:SetAllPoints(t)
    -- t.bg:SetColorTexture(1, 1, 1)

    t.headings = {}
    t.texts = {}

    create_heading("How to Deathroll:", 0, 0)
    create_text(deathroll_tutorial, 0, -30)

    create_heading("How to use DeathRoll Unlocked:", 0, -t.texts[1]:GetHeight() - 50) -- mm what nice future proofing :)
    create_text(DRU_tutorial, 0, -t.texts[1]:GetHeight() - 80)
end

function create_heading(text, x, y)
    local n = #t.headings + 1
    t.headings[n] = t:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    t.headings[n]:SetText("|cffffff00"..text.."|r")
    t.headings[n]:SetPoint("TOPLEFT", t, "TOPLEFT", x ,y)
    t.headings[n]:SetJustifyV("TOP")
    t.headings[n]:SetJustifyH("LEFT")
end

function create_text(text, x ,y)
    local n = #t.texts + 1
    t.texts[n] = t:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t.texts[n]:SetText(text)
    t.texts[n]:SetPoint("TOPLEFT", t, "TOPLEFT", x, y)
    t.texts[n]:SetJustifyV("TOP")
    t.texts[n]:SetJustifyH("LEFT")
    t.texts[n]:SetWidth(t:GetWidth())
    t.texts[n]:SetWordWrap(true)
    t.texts[n]:SetSpacing(2)
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
    button:SetHeight(30)

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