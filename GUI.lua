local DRU = DeathRollUnlocked

-- menu window
DRU.menu = CreateFrame("Frame", "MyAddonFrame", UIParent)
DRU.menu:SetSize(360, 260)
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
titleBar:SetHeight(24)
titleBar:SetColorTexture(0.1, 0.1, 0.13, 0.95)
DRU.menu.title = DRU.menu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
DRU.menu.title:SetPoint("LEFT", titleBar, "LEFT", 0, 0)
DRU.menu.title:SetText("Deathroll Unlocked")

-- close button
local close = CreateFrame("Button", nil, DRU.menu, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", DRU.menu, "TOPRIGHT", 0, 0)
close:SetScript("OnClick", function() DRU.menu:Hide() end)

-- Button (click)
local btn = CreateFrame("Button", nil, DRU.menu, "UIPanelButtonTemplate")
btn:SetSize(96, 24)
btn:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 8, -8)
btn:SetText("Click Me")
btn:SetScript("OnClick", function() print("|cffffff00DRU:|r Button clicked!") end)

-- Checkbutton + label
local cb = CreateFrame("CheckButton", nil, DRU.menu, "UICheckButtonTemplate")
cb:SetPoint("LEFT", btn, "RIGHT", 12, 0)
local cbLabel = DRU.menu:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cbLabel:SetPoint("LEFT", cb, "RIGHT", -3, 0)
cbLabel:SetText("Enable")
cb:SetScript("OnClick", function(self)
  print("|cffffff00DRU:|r checkbox =", tostring(self:GetChecked()))
end)

-- Right-clickable area (simple button so we get clicks)
local rc = CreateFrame("Button", nil, DRU.menu)
rc:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -16)
rc:SetSize(160, 40)
rc.bg = rc:CreateTexture(nil, "BACKGROUND")
rc.bg:SetAllPoints(rc)
rc.bg:SetColorTexture(0.15, 0.15, 0.18, 0.9)
rc.text = rc:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
rc.text:SetPoint("CENTER")
rc.text:SetText("Right-click me")
rc:RegisterForClicks("LeftButtonUp", "RightButtonUp")
rc:SetScript("OnClick", function(_, button)
  if button == "RightButton" then
    print("|cffffff00DRU:|r Right-click detected!")
  else
    print("|cffffff00DRU:|r Left-click detected!")
  end
end)

-- Tab content frames
local contentArea = CreateFrame("Frame", nil, DRU.menu)
contentArea:SetPoint("TOPLEFT", rc, "BOTTOMLEFT", 0, -12)
contentArea:SetPoint("BOTTOMRIGHT", DRU.menu, "BOTTOMRIGHT", -12, 12)

local tab1 = CreateFrame("Frame", nil, contentArea)
tab1:SetAllPoints(contentArea)
tab1.text = tab1:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tab1.text:SetPoint("TOPLEFT", tab1, "TOPLEFT", 6, -6)
tab1.text:SetText("Tab 1: general info\n- Example line 1\n- Example line 2")

local tab2 = CreateFrame("Frame", nil, contentArea)
tab2:SetAllPoints(contentArea)
tab2.text = tab2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
tab2.text:SetPoint("TOPLEFT", tab2, "TOPLEFT", 6, -6)
tab2.text:SetText("Tab 2: other options\n- More info here")
tab2:Hide()

-- Simple tab buttons (no PanelTemplates)
local tabs = {}
local function makeTab(id, label, leftOffset)
  local b = CreateFrame("Button", nil, DRU.menu)
  b:SetSize(80, 22)
  b:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", leftOffset, -6)
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  b.text:SetPoint("CENTER")
  b.text:SetText(label)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints(b)
  b.bg:SetColorTexture(0.08, 0.08, 0.09, 0.95)
  return b
end

tabs[1] = makeTab(1, "Tab 1", 200)
tabs[2] = makeTab(2, "Tab 2", 200 + 82)

local function SetTab(id)
  if id == 1 then
    tab1:Show(); tab2:Hide()
    tabs[1].bg:SetColorTexture(0.22,0.22,0.25,1)
    tabs[2].bg:SetColorTexture(0.08,0.08,0.09,0.95)
  else
    tab1:Hide(); tab2:Show()
    tabs[2].bg:SetColorTexture(0.22,0.22,0.25,1)
    tabs[1].bg:SetColorTexture(0.08,0.08,0.09,0.95)
  end
end

tabs[1]:SetScript("OnClick", function() SetTab(1) end)
tabs[2]:SetScript("OnClick", function() SetTab(2) end)
SetTab(1)

-- show by default
DRU.menu:Hide()

-- Create draggable parent frame
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