DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked

-- constants
local PAGE_LEN = 7 -- amount of games displayed per page in match history - 1.
local TOP_GAME_POS = -28 -- the y_pos of the top game of the page
local COLORS = {WIN = {normal = {0.1, 0.6, 0.1, 0.60}, hover = {0.2, 0.85, 0.2, 0.75}}, 
                LOSS = {normal = {0.6, 0.1, 0.1, 0.60}, hover = {0.85, 0.2, 0.2, 0.75}}}

-- functions
local make_page
local edit_page
local init_hist_entry
local edit_hist_entry
local update_page_info
local arrow
local disable_arrow

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

-- anything which needs DRUDB should be listed as a function here.
function DRU.UI_Init(in_game, my_turn)
    DRU.UpdateStats()
    DRU.button_update(in_game, my_turn)
    make_page()
    edit_page(0) -- load the 0th page
    update_page_info()
end

-- menu window
DRU.menu = CreateFrame("Frame", "MyAddonFrame", UIParent)
DRU.menu:SetSize(290, 300)
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

local function make_tab(name) -- this is done by chatGPT i hate UI programming
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

local match_hist = CreateFrame("Frame", nil, tabFrames[1]) -- parent of the match history list view
match_hist:SetPoint("TOPLEFT", tabFrames[1], "TOPLEFT", 7, 0)
match_hist:SetSize(263, 240)
match_hist.page_num = 0

function DRU.UpdateMatchHistory()
    
end

-- this is if u want to see the area of the match_history_frame
-- local bg = match_history_frame:CreateTexture(nil, "BACKGROUND")
-- bg:SetAllPoints(match_history_frame)
-- bg:SetColorTexture(1, 0, 0, 0.5)

-- arrows & page number
match_hist.left_arr = CreateFrame("Button", nil, match_hist, "UIPanelButtonTemplate")
match_hist.left_arr:SetPoint("BOTTOMLEFT")
match_hist.left_arr:SetSize(28, 28)
match_hist.left_arr:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
match_hist.left_arr:SetScript("OnClick", function() arrow(-1) end)

match_hist.right_arr = CreateFrame("Button", nil, match_hist, "UIPanelButtonTemplate")
match_hist.right_arr:SetPoint("BOTTOMRIGHT")
match_hist.right_arr:SetSize(28, 28)
match_hist.right_arr:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
match_hist.right_arr:SetScript("OnClick",function() arrow(1) end)

function arrow(dir)
    match_hist.page_num = match_hist.page_num + dir
    edit_page(match_hist.page_num)
    update_page_info()
end

match_hist.page_num_display = match_hist:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
match_hist.page_num_display:SetScale(1.5)
match_hist.page_num_display:SetPoint("BOTTOM", 0, 4)

function update_page_info()
    match_hist.page_num_display:SetText(tostring(match_hist.page_num + 1))

    if match_hist.page_num == 0 then
        match_hist.left_arr:Disable()
        match_hist.left_arr:DesaturateHierarchy(1)
    else
        match_hist.left_arr:Enable()
        match_hist.left_arr:DesaturateHierarchy(0)
    end

    local total_games = DRU.GetTotalGameAmount()
    local last_page = math.floor(total_games / PAGE_LEN)
    if match_hist.page_num == last_page then
        match_hist.right_arr:Disable()
        match_hist.right_arr:DesaturateHierarchy(1)
    else
        match_hist.right_arr:Enable()
        match_hist.right_arr:DesaturateHierarchy(0)    
    end
end

-- search box
match_hist.search_box = CreateFrame("EditBox", nil, match_hist, "InputBoxTemplate") -- search bar
match_hist.search_box:SetSize(175, 30)
match_hist.search_box:SetPoint("TOPLEFT", match_hist, "TOPLEFT", 4, 2)
match_hist.search_box:SetAutoFocus(false)
match_hist.search_box:SetScript("OnEnterPressed", function(self) -- if enter is pressed, search:
end)
match_hist.search_box_text = match_hist.search_box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") -- hint text for search bar
match_hist.search_box_text:SetPoint("LEFT", match_hist.search_box, "LEFT")
match_hist.search_box_text:SetText("Search for opponents")
match_hist.search_box_text:SetTextColor(0.6, 0.6, 0.6)
match_hist.search_box:SetScript("OnEditFocusGained", function(self)
    match_hist.search_box_text:Hide()
end)
match_hist.search_box:SetScript("OnEditFocusLost", function(self)
    local text = match_hist.search_box:GetText()
    if text == "" then
        match_hist.search_box_text:Show()
    end
end)

match_hist.page = CreateFrame("Frame", nil, match_hist)
match_hist.page.games = {}

function init_hist_entry(y_pos, num) -- creates 1 game entry "preset" at given y_pos
    match_hist.page.games[num] = CreateFrame("Button", nil, match_hist.page)
    local game = match_hist.page.games[num]

    game:SetPoint("TOPLEFT", match_hist, "TOPLEFT", 0, y_pos)
    game:SetSize(263, 20)

    game.bg = game:CreateTexture(nil, "BACKGROUND")
    game.bg:SetAllPoints(game)

    game.gold = game:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    game.gold:SetPoint("LEFT")

    game.opp = game:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    game.opp:SetPoint("CENTER")

    game:SetScript("OnClick", function() print(game.id) end)
end

function edit_hist_entry(id, opp, result, gold, num) -- edits ui elements of game entry in match history list
    local game = match_hist.page.games[num]

    game.gold:SetText(gold)
    game.opp:SetText(opp)
    game.id = id -- every game listed keeps track of their own game id

    local color_set
    if result == "Win" then
        color_set = COLORS.WIN
    else
        color_set = COLORS.LOSS
    end

    game.bg:SetColorTexture(unpack(color_set.normal))
    game:SetScript("OnEnter", function(self) self.bg:SetColorTexture(unpack(color_set.hover)) end)
    game:SetScript("OnLeave", function(self)
    if self.active then self.bg:SetColorTexture(unpack(color_set.hover)) else self.bg:SetColorTexture(unpack(color_set.normal)) end
    end)
end

function edit_page(page) -- wrapper for for loop
    local page_data = DRU.GetMatchHistoryPage(page, PAGE_LEN)
    for i = 1, PAGE_LEN + 1 do
        if page_data[i] then
            local id, opp, result, gold = unpack(page_data[i])
            edit_hist_entry(id, opp, result, gold, i)
            match_hist.page.games[i]:Show()
        else
            match_hist.page.games[i]:Hide()
        end
    end
end

function make_page() -- wrapper for for loop
    for i = 1, PAGE_LEN + 1 do
        if i ~= 1 then TOP_GAME_POS = TOP_GAME_POS - 23 end
        init_hist_entry(TOP_GAME_POS, i) -- using the numerator of the for loop to index the list of games
    end
end

SLASH_DEATHROLLTRY1 = "/drtry" -- dev tool
SlashCmdList["DEATHROLLTRY"] = function()
    local game = match_hist.page.games[4]
    game.gold:SetText("Hi")
end

local game_details = CreateFrame("Frame", nil, tabFrames[1]) -- parent of game details view
game_details:Hide()



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



-- Finances
tabFrames[3] = CreateFrame("Frame", nil, contentArea)
tabFrames[3]:SetAllPoints(contentArea)
tabFrames[3].text = tabFrames[3]:CreateFontString(nil,"OVERLAY","GameFontNormal")
tabFrames[3].text:SetPoint("TOPLEFT", 6, -6)
tabFrames[3].text:SetJustifyH("LEFT")
tabFrames[3].text:SetJustifyV("TOP") 
tabFrames[3].text:SetText(finance_text)
tabFrames[3]:Hide()

-- create tab buttons
tabs[1] = make_tab("History")
tabs[2] = make_tab("Statistics")
tabs[3] = make_tab("Finances")

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