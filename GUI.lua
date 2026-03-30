-- (obviously) this file handles all of the GUI

DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked
---@diagnostic disable: undefined-global

-- GUI things & shorthands
local MH -- match history
local GD -- game details
local ST -- settings (assigned later to DRUDB.settings)
local GS = DRU.gamestate
local g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t" -- gold icon

local is_button_initialized = false
local is_menu_initialized = false
local button
local textbox
local tabs = {}
local tab_frames = {}

-- constants
local PAGE_LEN = 8 -- amount of games displayed per page in match history
local TOP_GAME_POS = -28 -- the y_pos of the top game of the page
local COLORS = {WIN = {normal = {0.1, 0.6, 0.1, 0.60}, hover = {0.2, 0.85, 0.2, 0.75}}, 
                LOSS = {normal = {0.6, 0.1, 0.1, 0.60}, hover = {0.85, 0.2, 0.2, 0.75}}}

-- functions
local make_page
local edit_page
local init_hist_entry
local edit_hist_entry
local change_page
local display_game
local add_row
local calc_page_ends
local make_tab
local set_tab
local goldify -- different than the DRU.G

-- text
local stats_text = [[
Total Games Played: %d
Win Rate: %s
Games Won: %d
Games Lost: %d

Total Gold Earned: %s
Biggest Win: %s
Biggest Loss: %s

Longest Win Streak: %d
Longest Loss Streak: %d
Longest Streak of 2's: %d
Worst Roll: %s
]]

local finance_text = [[
Work in Progress :)
]]

local game_info_text = [[
Opponent: %s
Result: %s
Your Wager: %s
%s's Wager: %s
]]

-- confirmation popup for deleting match history
StaticPopupDialogs["DRU_CONFIRM_WIPE"] = {
    text = "Are you sure you want to delete ALL of your games, rolls and statistics?",
    button1 = "Yes",
    button2 = "No",
    OnAccept = function() DRU.WipeDB() end,
    timeout = 0, 
    whileDead = true, 
    hideOnEscape = false
}

-- anything which needs DRUDB should be listed as a function here.
function DRU.InitUI(in_game, my_turn)
    ST = DRUDB.settings
    if ST.dr_button then
        DRU.InitButton()
        DRU.ButtonUpdate(in_game, my_turn)
        DRU.ToggleTextbox(ST.textbox)
    end
    
    if ST.dr_menu then
        DRU.InitMenu()
        edit_page(0) -- load the 0th page
        DRU.UpdatePageUI()
        DRU.UpdateStats()
    end

    -- DRU.InitRollBox()
end

function DRU.InitMenu()
    -- menu window
    DRU.menu = CreateFrame("Frame", "DeathRollFrame", UIParent)
    DRU.menu:SetFrameStrata("LOW")
    DRU.menu:SetSize(290, 300)
    DRU.menu:SetPoint("CENTER", 200, 0)
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
    DRU.menu.title:SetText("DeathRoll Unlocked")

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

    -- History
    tab_frames[1] = CreateFrame("Frame", nil, contentArea)
    tab_frames[1]:SetAllPoints(contentArea)
    tab_frames[1].text = tab_frames[1]:CreateFontString(nil,"OVERLAY","GameFontNormal")
    tab_frames[1].text:SetPoint("TOPLEFT", 6, -30)
    tab_frames[1].text:SetJustifyH("LEFT")
    tab_frames[1].text:SetJustifyV("TOP")
    tab_frames[1].text:SetText("")

    -- match history page display
    MH = CreateFrame("Frame", nil, tab_frames[1]) -- parent of the match history list view
    MH:SetPoint("TOPLEFT", tab_frames[1], "TOPLEFT", 7, 0)
    MH:SetSize(263, 240)
    MH.page_num = 0

    -- this is if u want to see the area of the MH
    -- local bg = match_history_frame:CreateTexture(nil, "BACKGROUND")
    -- bg:SetAllPoints(match_history_frame)
    -- bg:SetColorTexture(1, 0, 0, 0.5)

    -- arrows & page number
    MH.left_arr = CreateFrame("Button", nil, MH, "UIPanelButtonTemplate")
    MH.left_arr:SetPoint("BOTTOMLEFT", -2, 0)
    MH.left_arr:SetSize(28, 28)
    MH.left_arr:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    MH.left_arr:SetScript("OnClick", function() change_page(-1) end)

    MH.right_arr = CreateFrame("Button", nil, MH, "UIPanelButtonTemplate")
    MH.right_arr:SetPoint("BOTTOMRIGHT")
    MH.right_arr:SetSize(28, 28)
    MH.right_arr:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    MH.right_arr:SetScript("OnClick", function() change_page(1) end)

    MH:EnableMouseWheel(true)
    MH:SetScript("OnMouseWheel", function(self, delta) 
        delta = (delta > 0) and -1 or 1 -- i have to inverse the delta because scrolling down is a negative number
        change_page(delta)
    end)
    MH.page_num_display = MH:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    MH.page_num_display:SetScale(1.5)
    MH.page_num_display:SetPoint("BOTTOM", 0, 4)

    -- search box
    MH.search_box = CreateFrame("EditBox", nil, MH, "SearchBoxTemplate") -- search bar
    MH.search_box:SetSize(260, 30)
    MH.search_box:SetPoint("TOPLEFT", MH, "TOPLEFT", 4, 2)
    MH.search_box:SetAutoFocus(false)
    MH.search_box.Instructions:SetText("Search for opponents")
    MH.search_box:HookScript("OnTextChanged", function() edit_page(0) end)

    MH.no_games = MH:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    MH.no_games:SetPoint("CENTER", MH, "CENTER", 0, 10)
    MH.no_games:SetTextColor(0.8, 0.8, 0.8)
    MH.no_games:SetText("You have no matches to display yet.")

    MH.page = CreateFrame("Frame", nil, MH)
    MH.page.games = {}

    make_page()

    -- game details display
    GD = CreateFrame("Frame", nil, tab_frames[1]) -- parent of game details view
    GD:SetPoint("TOPLEFT", tab_frames[1], "TOPLEFT", 7, -3)
    GD:SetSize(263, 240)
    GD:Hide()

    GD.back_arr = CreateFrame("Button", nil, GD, "UIPanelButtonTemplate")
    GD.back_arr:SetPoint("TOPLEFT", 0, 0)
    GD.back_arr:SetSize(28, 28)
    GD.back_arr:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
    GD.back_arr:SetScript("OnClick", function()
        GD:Hide()
        MH:Show()
    end)

    GD.info = CreateFrame("Frame", nil, GD)
    GD.info:SetPoint("TOPRIGHT", GD, "TOPRIGHT", 0, -2)
    GD.info:SetSize(230, 100)
    GD.info.text_1 = GD.info:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    GD.info.text_1:SetJustifyH("LEFT")
    GD.info.text_1:SetJustifyV("TOP") 
    GD.info.text_1:SetPoint("TOPLEFT", GD.info, "TOPLEFT")
    GD.info.text_2 = GD.info:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    GD.info.text_2:SetPoint("TOPLEFT", GD, "TOPLEFT", 0, -55)
    GD.info.text_2:SetText("Rolls")

    GD.scroll = CreateFrame("ScrollFrame", nil, GD, "UIPanelScrollFrameTemplate")
    GD.scroll:SetPoint("TOPLEFT", GD, "TOPLEFT", 0, -80)
    GD.scroll:SetSize(250, 155)

    GD.roll_frame = CreateFrame("Frame", nil, GD.scroll)
    GD.roll_frame:SetSize(230, 155)
    GD.scroll:SetScrollChild(GD.roll_frame)
    GD.rolls = {}

    -- GD.scroll.bg = GD.scroll:CreateTexture(nil, "BACKGROUND")
    -- GD.scroll.bg:SetAllPoints(GD.scroll)
    -- GD.scroll.bg:SetColorTexture(1, 0, 0, 0.5)

    -- Statistics
    tab_frames[2] = CreateFrame("Frame", nil, contentArea)
    local stats = tab_frames[2]
    stats:SetAllPoints(contentArea)
    stats.text = stats:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    stats.text:SetPoint("TOPLEFT", 6, -6)
    stats.text:SetJustifyH("LEFT")
    stats.text:SetJustifyV("TOP")
    stats.text:SetScale(1.2)
    stats.text_2 = stats:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    stats.text_2:SetPoint("BOTTOMLEFT", 6, 0)
    stats.text_2:SetText("Statistics are account-wide.")
    stats.text_2:SetTextColor(0.6, 0.6, 0.6)
    stats.text_2:SetScale(1.2)
    stats:Hide()

    -- Finances
    tab_frames[3] = CreateFrame("Frame", nil, contentArea)
    local finances = tab_frames[3]
    finances:SetAllPoints(contentArea)
    finances.text = tab_frames[3]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    finances.text:SetPoint("CENTER", 0, 20)
    finances.text:SetJustifyH("LEFT")
    finances.text:SetJustifyV("TOP") 
    finances.text:SetText(finance_text)
    finances.text:SetTextColor(0.6, 0.6, 0.6)
    finances:Hide()

    -- create tab buttons
    tabs[1] = make_tab("History")
    tabs[2] = make_tab("Statistics")
    tabs[3] = make_tab("Finances")

    for i, b in ipairs(tabs) do
    b:SetScript("OnClick", function() set_tab(i) end)
    end
    set_tab(1) -- default to History
    is_menu_initialized = true
end

function DRU.ToggleMenu(value)
    if not is_menu_initialized then
        DRU.InitMenu()
    end

    if value then
        DRU.menu:Show()
        edit_page(0) -- load the 0th page
        DRU.UpdatePageUI()
        DRU.UpdateStats()
    else
        DRU.menu:Hide()
    end
end

function make_tab(name) -- this is done by chatGPT i hate UI programming
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

function DRU.UpdateMenu()
    edit_page(0)
    DRU.UpdatePageUI()
    DRU.UpdateStats()
end

function DRU.UpdatePageUI(is_first_page, is_last_page)
    MH.page_num_display:SetText(tostring(MH.page_num + 1))
    if is_first_page == nil then -- on startup this gets no args so we calc the page ends
        is_first_page, is_last_page = calc_page_ends()
    end

    if is_first_page then
        MH.left_arr:Disable()
        MH.left_arr:DesaturateHierarchy(1)
    else
        MH.left_arr:Enable()
        MH.left_arr:DesaturateHierarchy(0)
    end

    if is_last_page then
        MH.right_arr:Disable()
        MH.right_arr:DesaturateHierarchy(1)
    else
        MH.right_arr:Enable()
        MH.right_arr:DesaturateHierarchy(0)    
    end
end

function calc_page_ends() -- calculates if we are on the first and/or last page of our match history
    local total_games = DRU.GetTotalGameAmount()
    if total_games == 0 then -- edge case because math below doesn't work with 0
        MH.no_games:Show() -- since we're already checking for 0 games here, throw the no_games text here as well.
        return true, true
    else
        MH.no_games:Hide()
    end

    local is_first_page, is_last_page = false, false
    local curr_page = MH.page_num
    local last_page = math.floor((total_games - 1) / PAGE_LEN)

    if curr_page == 0 then is_first_page = true end
    if curr_page == last_page then is_last_page = true end

    return is_first_page, is_last_page
end

function change_page(dir) -- changes page; -1 == prev, 1 == next
    local is_first_page, is_last_page = calc_page_ends()

    if (is_first_page and dir == -1) or (is_last_page and dir == 1) then
        return
    end

    MH.page_num = MH.page_num + dir
    edit_page(MH.page_num)
    DRU.UpdatePageUI()
end

function init_hist_entry(y_pos, num) -- creates 1 game entry "preset" at given y_pos
    MH.page.games[num] = CreateFrame("Button", nil, MH.page)
    local game = MH.page.games[num]

    game:SetPoint("TOPLEFT", MH, "TOPLEFT", 0, y_pos)
    game:SetSize(263, 20)

    game.bg = game:CreateTexture(nil, "BACKGROUND")
    game.bg:SetAllPoints(game)

    game.gold = game:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    game.gold:SetPoint("RIGHT")
    game.gold:SetScale(1)

    game.opp = game:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    game.opp:SetPoint("LEFT", 5, 0)
    game.opp:SetScale(1)

    game:SetScript("OnClick", function() display_game(DRU.GetGameByID(game.id)) end) -- when u click a game in the list
end

function edit_hist_entry(id, opp, result, gold, num) -- edits ui elements of game entry in match history list
    local game = MH.page.games[num]

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
    local opp_search = MH.search_box:GetText()

    local page_data = DRU.GetMatchHistoryPage(page, PAGE_LEN, opp_search)
    for i = 1, PAGE_LEN do
        if page_data[i] then
            local id, opp, result, gold = unpack(page_data[i])
            edit_hist_entry(id, opp, result, gold, i)
            MH.page.games[i]:Show()
        else
            MH.page.games[i]:Hide()
        end
    end
end

function make_page() -- wrapper for for loop
    for i = 1, PAGE_LEN do
        if i ~= 1 then TOP_GAME_POS = TOP_GAME_POS - 23 end
        init_hist_entry(TOP_GAME_POS, i) -- using the numerator of the for loop to index the list of games
    end
end

function DRU.UpdateCurrPage() -- on page 1, the live udpate works, but on any other page it doesn't.
    edit_page(MH.page_num)
end

function add_row(roll_line, max_roll_line, pos, i) -- adds a roll to the scroll frame. if the text in the pos already exists, only edit the text and don't waste resources creating a new frame.
    if not GD.rolls[i] then
        GD.rolls[i] = GD.roll_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        GD.rolls[i]:SetJustifyH("LEFT")
        GD.rolls[i]:SetJustifyV("TOP")
        GD.rolls[i]:SetPoint("TOPLEFT", GD.roll_frame, "TOPLEFT", 0, pos)
    end
    GD.rolls[i]:SetText(roll_line)
    GD.rolls[i]:Show()
end

function display_game(game)
    MH:Hide()
    GD:Show()

    local opp = game.info.opp or "None"
    local result = game.info.result or "None"
    local my_wager = (tostring(game.info.my_wager)..g)
    local opp_wager = (tostring(game.info.opp_wager)..g)
    local rolls = game.rolls

    GD.info.text_1:SetText(string.format(game_info_text, opp, result, my_wager, opp, opp_wager))

    local pos = 0
    local last_row = 0
    for i, roll_table in ipairs(rolls) do
        local roller = roll_table[2]
        if roller == DRU.me then roller = "You" end
        local max_roll = roll_table[4]
        local max_roll_line = string.format("(1-%d)")
        local roll = tostring(roll_table[3])
        if roll == "1" then roll = string.format(roll.. " and lost.") end
        if i == 1 then roll = string.format(roll.." |cffaaaaaa(1-%d)|r", max_roll) end

        local roll_line = string.format("%s rolled %s", roller, roll)
        add_row(roll_line, max_roll_line, pos, i)
        pos = pos - 13
        last_row = i
    end

    for i = last_row + 1, #GD.rolls do -- hide all the rows after the last one
        GD.rolls[i]:Hide()
    end

    -- nah nvm
    -- if GD.scroll:GetVerticalScrollRange() == 0 then
    --     GD.scroll:Hide()
    -- end
end

function set_tab(id)
    for i, b in ipairs(tabs) do
        b.active = (i == id)
        if b.active then b.bg:SetColorTexture(0.22,0.22,0.25,1) else b.bg:SetColorTexture(0.08,0.08,0.09,0.95) end
        if tab_frames[i] then
            if i == id then tab_frames[i]:Show() else tab_frames[i]:Hide() end
        end
    end
end

function DRU.UpdateStats()
    local total, win_rate, wins, losses, total_gold, worst_roll, two_streak, win_streak, loss_streak, most_won, most_lost = DRU.GetStats()

    tab_frames[2].text:SetText(string.format(stats_text, total, win_rate, wins, losses, goldify(total_gold), goldify(most_won), goldify(most_lost), win_streak, loss_streak, two_streak, worst_roll))
end

function DRU.InitRollBox()
    DRU.roll_box = CreateFrame("Button", "DeathRollFrame", UIParent, "")
    DRU.roll_box:SetSize(300, 300)
    DRU.roll_box:SetPoint("CENTER")
end



function DRU.InitButton()
    DRU.button_frame = CreateFrame("Button", "DeathRollFrame", UIParent, "BackdropTemplate")
    DRU.button_frame:SetFrameStrata("MEDIUM")
    DRU.button_frame:SetSize(100, 40)
    DRU.button_frame:SetPoint("CENTER", -100, -50)
    DRU.button_frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    local function OnDragStart(self, button)
        if button == "MiddleButton" then
            DRU.button_frame:StartMoving()
        end
    end
    local function OnDragStop(self, button)
        if button == "MiddleButton" then
            DRU.button_frame:StopMovingOrSizing()
        end
    end
    DRU.button_frame:SetBackdropColor(0, 0, 0, 0)
    DRU.button_frame:SetBackdropBorderColor(0, 0, 0, 0)
    DRU.button_frame:SetMovable(true)
    DRU.button_frame:EnableMouse(true)
    DRU.button_frame:RegisterForDrag("MiddleButton")
    DRU.button_frame:SetScript("OnDragStart", DRU.button_frame.StartMoving)
    DRU.button_frame:SetScript("OnDragStop", DRU.button_frame.StopMovingOrSizing)
    DRU.button_frame:SetScript("OnMouseDown", OnDragStart)
    DRU.button_frame:SetScript("OnMouseUp", OnDragStop)

    -- Create the Deathroll button inside the frame
    DRU.button = CreateFrame("Button", nil, DRU.button_frame, "UIPanelButtonTemplate")
    button = DRU.button
    button:SetSize(100, 30)
    button:SetPoint("BOTTOM", DRU.button_frame, "CENTER", 0, 0)
    button:SetScript("OnMouseDown", OnDragStart) -- middle mouse button can move the frame
    button:SetScript("OnMouseUp", OnDragStop)
    button:SetScript("OnClick", function(self, button)
        DRU.ButtonClick()
    end)

    -- create the textbox
    DRU.textbox = CreateFrame("EditBox", nil, DRU.button_frame, "InputBoxTemplate") -- TODO: change to 2 textboxes, 1 for roll and 1 for wager (?)
    textbox = DRU.textbox
    textbox:SetSize(94, 30)
    textbox:SetPoint("CENTER", DRU.button_frame, "CENTER", 3, -8)
    textbox:SetAutoFocus(false)
    textbox:SetScript("OnEnterPressed", function(self)
        DRU.ButtonClick()
    end)
    is_button_initialized = true
end

function DRU.ToggleButton(value)
    if not is_button_initialized then
        DRU.InitButton()
        DRU.ToggleTextbox(ST.textbox)
        DRU.ButtonUpdate(GS.in_game, GS.my_turn)
    end

    if value then
        DRU.button_frame:Show()
    else
        DRU.button_frame:Hide()
    end
end

function DRU.ButtonUpdate(in_game, my_turn)
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

function DRU.ToggleTextbox(value)
    if value then
        textbox:Show()
    else
        textbox:Hide()
    end
end

function DRU.UpdateTextbox(focus, text)
    if focus == 1 then
        textbox:SetFocus()
    elseif focus == 0 then
        textbox:ClearFocus()
    end

    textbox:SetText(text)
end

function DRU.ConfirmWipe(type)
    StaticPopup_Show("DRU_CONFIRM_WIPE")
end

function goldify(gold)
    local new_gold = (gold..g)
    return new_gold
end

SLASH_DEATHROLLBUTTON1 = "/drbutton"
SLASH_DEATHROLLBUTTON2 = "/deathrollbutton"
SLASH_DEATHROLLBUTTON3 = "/drb"
SlashCmdList["DEATHROLLBUTTON"] = function()
    DRU.ToggleButton(not ST.dr_button)
    ST.dr_button = not ST.dr_button -- if toggled by command we have to manually correct the settings
end

SLASH_DEATHROLLMENU1 = "/drmenu"
SLASH_DEATHROLLMENU2 = "/drm"
SlashCmdList["DEATHROLLMENU"] = function()
    DRU.ToggleMenu(not ST.dr_menu)
    ST.dr_menu = not ST.dr_menu
end