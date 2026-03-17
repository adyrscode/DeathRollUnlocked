DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked
DRU.settings = {}

function DRU.Settings_Init()
    DRU.settingsCategory = Settings.RegisterVerticalLayoutCategory("DeathRoll Unlocked")

    -- template setting
    local example_setting = "example_setting"
    local defaultValue = true

    Settings.RegisterAddOnSetting(DRU.settingsCategory, example_setting, example_setting, DRU.settings, type(defaultValue), "Example Setting", defaultValue)
    Settings.CreateCheckbox(DRU.settingsCategory, Settings.GetSetting(example_setting), "Temporary example setting. Does not work currently.")
    Settings.RegisterAddOnCategory(DRU.settingsCategory)
end