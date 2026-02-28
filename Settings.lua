DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked
DRU.settings = {}

function DRU.Settings_Init()
    DRU.settingsCategory = Settings.RegisterVerticalLayoutCategory("DeathRoll Unlocked")

    -- template setting
    local save_history = "save_history"
    local defaultValue = true

    Settings.RegisterAddOnSetting(DRU.settingsCategory, save_history, save_history, DRU.settings, type(defaultValue), "Save Roll History", defaultValue)
    Settings.CreateCheckbox(DRU.settingsCategory, Settings.GetSetting(save_history), "Temporary example setting. Does not work currently.")
    Settings.RegisterAddOnCategory(DRU.settingsCategory)
end