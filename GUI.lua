DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked

-- text
local stats_text = [[
Total Games Played: %d
Win Rate: %s
Games Won: %d
Games Lost: %d
Total Gold Earned: %dg
Worst Roll: %s
Longest Streak of 2's: %d
]]

local finance_text = [[
Work in Progress :)
]]

function DRU.UI_Init(in_game, my_turn) -- anything which needs DRUDB should be listed as a function here.
    DRU.UpdateStats()
    DRU.button_update(in_game, my_turn)
end

-- menu window
DRU.menu = CreateFrame("Frame", "MyAddonFrame", UIParent)
DRU.menu:SetSize(290, 260)
DRU.menu:SetPoint("CENTER")
DRU.menu:EnableMouse(true)
DRU.menu:SetMovable(true)
DRU.menu:RegisterForDrag("LeftButton")
DRU.menu:SetScript("OnDragStart", function(self) self:StartMoving() end)
DRU.menu:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

-- background
DRU.menu.bg = DRU.menu:CreateTexture(nil, "BACKGROUND")
DRU.menu.bg:SetAllPoints(DRU.menu)
DRU.menu.bg:SetColorTexture(0, 0, 0, 0.6)

-- title bar
local titleBar = DRU.menu:CreateTexture(nil, "ARTWORK")
titleBar:SetPoint("TOPLEFT", DRU.menu, "TOPLEFT")
titleBar:SetPoint("TOPRIGHT", DRU.menu, "TOPRIGHT")
titleBar:SetHeight(24)
titleBar:SetColorTexture(0.1, 0.1, 0.13, 0.95)
DRU.menu.title = DRU.menu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
DRU.menu.title:SetPoint("LEFT", titleBar, "CENTER", -80, 0)
DRU.menu.title:SetText("Deathroll Unlocked")

-- close button
local close = CreateFrame("Button", nil, DRU.menu, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", DRU.menu, "TOPRIGHT", 0, 0)
close:SetScript("OnClick", function() DRU.menu:Hide() end)

-- settings button
local settings = CreateFrame("Button", nil, DRU.menu)
settings:SetSize(24, 24)
settings:SetPoint("TOPRIGHT", DRU.menu, "TOPLEFT", 25, 0)
settings:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
settings:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
settings:SetScript("OnClick", function() Settings.OpenToCategory(DRU.settingsCategory:GetID()) end) -- pass the id of the settings tab we have

-- Tabs: History, Statistics, Settings
local contentArea = CreateFrame("Frame", "DRU_MenuContent", DRU.menu)
contentArea:SetPoint("TOPLEFT", DRU.menu, "TOPLEFT", 5, -50)
contentArea:SetPoint("BOTTOMRIGHT", DRU.menu, "BOTTOMRIGHT", -12, 12)

local tabs = {}
local tabFrames = {}

local function makeTab(name)
  local b = CreateFrame("Button", nil, DRU.menu)
  b:SetSize(84, 22)
  if #tabs == 0 then
    b:SetPoint("TOPLEFT", DRU.menu, "TOPLEFT", 12, -28) -- first tab
  else
    b:SetPoint("LEFT", tabs[#tabs], "RIGHT", 6, 0)      -- auto-space next to previous
    b:SetPoint("TOP", tabs[#tabs], "TOP", 0, 0)
  end
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  b.text:SetPoint("CENTER")
  b.text:SetText(name)
  b.text:SetFontObject("GameFontNormal")
  local font, _, flags = b.text:GetFont()
  b.text:SetFont(font, 12, flags)

  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints(b)
  b.bg:SetColorTexture(0.08, 0.08, 0.09, 0.95)

  b:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.18,0.18,0.20,1) end)
  b:SetScript("OnLeave", function(self)
    if self.active then self.bg:SetColorTexture(0.22,0.22,0.25,1) else self.bg:SetColorTexture(0.08,0.08,0.09,0.95) end
  end)

  return b
end

-- History
tabFrames[1] = CreateFrame("Frame", nil, contentArea)
tabFrames[1]:SetAllPoints(contentArea)
tabFrames[1].text = tabFrames[1]:CreateFontString(nil,"OVERLAY","GameFontNormal")
tabFrames[1].text:SetPoint("TOPLEFT", 6, -30)
tabFrames[1].text:SetJustifyH("LEFT")
tabFrames[1].text:SetJustifyV("TOP")
tabFrames[1].text:SetText("")

local search_box = CreateFrame("EditBox", nil, tabFrames[1], "InputBoxTemplate")
search_box:SetSize(150, 30)                 
search_box:SetPoint("TOPLEFT", tabFrames[1], "TOPLEFT", 10, 0)
search_box:SetAutoFocus(false)
search_box:SetScript("OnEnterPressed", function(self) -- if enter is pressed, search:
end)

local sample_text = search_box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
sample_text:SetPoint("LEFT", search_box, "LEFT")
sample_text:SetText("Enter opponent's name")       -- this is the greyed-out placeholder text
sample_text:SetTextColor(0.6, 0.6, 0.6)
search_box:SetScript("OnEditFocusGained", function(self)
    sample_text:Hide()
end)
search_box:SetScript("OnEditFocusLost", function(self)
    local text = search_box:GetText()
    if text == "" then
        sample_text:Show()
    end
end)


-- Statistics
tabFrames[2] = CreateFrame("Frame", nil, contentArea)
tabFrames[2]:SetAllPoints(contentArea)
tabFrames[2].text = tabFrames[2]:CreateFontString(nil,"OVERLAY","GameFontNormal")
tabFrames[2].text:SetPoint("TOPLEFT", 6, -6)
tabFrames[2].text:SetJustifyH("LEFT")
tabFrames[2].text:SetJustifyV("TOP") 

function DRU.UpdateStats() -- TODO: right now every game updates all of the stats no matter what. can i individually update stats?
    local total, win_rate, wins, losses, gold, worst_roll, streak = DRU.GetStats()

    tabFrames[2].text:SetText(string.format(stats_text, total, win_rate, wins, losses, gold, worst_roll, streak))
end

tabFrames[2]:Hide()

-- finances
tabFrames[3] = CreateFrame("Frame", nil, contentArea)
tabFrames[3]:SetAllPoints(contentArea)
tabFrames[3].text = tabFrames[3]:CreateFontString(nil,"OVERLAY","GameFontNormal")
tabFrames[3].text:SetPoint("TOPLEFT", 6, -6)
tabFrames[3].text:SetJustifyH("LEFT")
tabFrames[3].text:SetJustifyV("TOP") 
tabFrames[3].text:SetText(finance_text)
tabFrames[3]:Hide()

-- create tab buttons
tabs[1] = makeTab("History")
tabs[2] = makeTab("Statistics")
tabs[3] = makeTab("Finances")

local function SetTab(id)
  for i, b in ipairs(tabs) do
    b.active = (i == id)
    if b.active then b.bg:SetColorTexture(0.22,0.22,0.25,1) else b.bg:SetColorTexture(0.08,0.08,0.09,0.95) end
    if tabFrames[i] then
      if i == id then tabFrames[i]:Show() else tabFrames[i]:Hide() end
    end
  end
end

for i, b in ipairs(tabs) do
  b:SetScript("OnClick", function() SetTab(i) end)
end

SetTab(1) -- default to History

-- show by default
DRU.menu:Show()

-- Create draggable parent frame for button
local parentFrame = CreateFrame("Frame", "DeathrollFrame", UIParent, "BackdropTemplate")
parentFrame:SetSize(100, 40)
parentFrame:SetPoint("CENTER", 300, 400)
parentFrame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
local function OnDragStart(self, button)
    if button == "MiddleButton" then
        parentFrame:StartMoving()
    end
end
local function OnDragStop(self, button)
    if button == "MiddleButton" then
        parentFrame:StopMovingOrSizing()
    end
end
parentFrame:SetBackdropColor(0, 0, 0, 0) 
parentFrame:SetBackdropBorderColor(0, 0, 0, 0)
parentFrame:SetMovable(true)
parentFrame:EnableMouse(true)
parentFrame:RegisterForDrag("MiddleButton")
parentFrame:SetScript("OnDragStart", parentFrame.StartMoving)
parentFrame:SetScript("OnDragStop", parentFrame.StopMovingOrSizing)
parentFrame:Show()
parentFrame:SetScript("OnMouseDown", OnDragStart)
parentFrame:SetScript("OnMouseUp", OnDragStop)

-- Create the Deathroll button inside the frame
DRU.button = CreateFrame("Button", nil, parentFrame, "UIPanelButtonTemplate")
local button = DRU.button
button:SetSize(100, 30)
button:SetPoint("BOTTOM", parentFrame, "CENTER", 0, 0)
button:SetScript("OnMouseDown", OnDragStart) -- button middle mouse button can move the frame
button:SetScript("OnMouseUp", OnDragStop)
button:SetScript("OnClick", function(self, button)
    DRU.button_click()
end)

-- button_text is called after we know gamestate
function DRU.button_update(in_game, my_turn)
    if in_game then
        button:SetText("Roll!")
        if not my_turn then
            button:Disable()
        else
            button:Enable()
        end
    else
        button:Enable()
        button:SetText("Start Roll!")
    end
end

-- create the textbox
DRU.textbox = CreateFrame("EditBox", nil, parentFrame, "InputBoxTemplate") -- TODO: change to 2 textboxes, 1 for roll and 1 for wager
local textbox = DRU.textbox
textbox:SetSize(94, 30)
textbox:SetPoint("CENTER", parentFrame, "CENTER", 3, -8)
textbox:SetAutoFocus(false)
textbox:SetScript("OnEnterPressed", function(self) -- if enter is pressed
    DRU.button_click()
end)

SLASH_DEATHROLLBUTTON1 = "/drbutton"
SLASH_DEATHROLLBUTTON2 = "/deathrollbutton"
SlashCmdList["DEATHROLLBUTTON"] = function() -- hide and show the button
    if parentFrame:IsShown() then
        parentFrame:Hide()
    else parentFrame:Show()
    end
end

SLASH_DEATHROLLMENU1 = "/drmenu"
SLASH_DEATHROLLMENU2 = "/drm"
SlashCmdList["DEATHROLLMENU"] = function()
  if DRU.menu:IsShown() then DRU.menu:Hide() else DRU.menu:Show() end
end