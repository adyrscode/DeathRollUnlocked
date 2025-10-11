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

-- show by default
DRU.menu:Show()

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