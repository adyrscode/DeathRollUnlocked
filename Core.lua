-- this file manages the core gameplay loop of deathrolling.

-- prefix for our own addon channel
local prefix = "deathroll_data"
DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked -- anytime a function has DRU. in front of it, that means it has to be called from another file at some point
DRU.DEBUG = false -- remember to always set this to false and disable the testing.lua in toc before pushing

-- players and their rolls
DRU.me = UnitName("player")
local target_name = nil

-- game states
DRU.gamestate = {in_game = false, curr_game = nil, my_turn = false, curr_opp = nil, my_wager = 0, opp_wager = 0, last_roller = nil, last_roll = 0}
local random_rolls = {}
local gs = DRU.gamestate
local my_request_pending = false
local player_targeted = false

-- functions
local do_roll
local attempt_game_start
local start_game
local target_check
local end_game
local scam_check
local scam_alert
local send_addon_data
local result_check
local party_check
local chat_roll_check
local roll_check
local wager_check
local opp_wager_check
local stringify

local addon_loader = CreateFrame("Frame")
addon_loader:RegisterEvent("ADDON_LOADED")
addon_loader:SetScript("OnEvent", function(self, event, addon_name)
    if addon_name == "DeathRollUnlocked" then -- every function here needs SavedVariables to be fully loaded and ready before initializing.
        DRU.GetGameState()
        DRU.DB_Init()
        DRU.Settings_Init()
        DRU.UI_Init(gs.in_game, gs.my_turn)
    end
end)

-- listening frame for receiving addon messages
C_ChatInfo.RegisterAddonMessagePrefix(prefix)
local channel_listener = CreateFrame("Frame")
channel_listener:RegisterEvent("CHAT_MSG_ADDON")
channel_listener:SetScript("OnEvent", function(self, event, prefix, message, channel, temp_sender)
    if prefix == "deathroll_data" then -- if the addonmessage is from deathroll_data
        local msg_type, opp_roll_str, opp_max_roll_str, opp_wager_str = strsplit(":", message)
        local sender = temp_sender:match("^[^-]+") or temp_sender -- take realm name out
        
        local opp_max_roll = tonumber(opp_max_roll_str)
        local opp_roll = tonumber(opp_roll_str)
        local opp_wager = tonumber(opp_wager_str)

        if msg_type == "GameRequest" then
            if opp_roll == 1 then
                DRU.print(string.format("%s wanted to deathroll you for %s starting from %d, but they immediately lost!", sender, stringify(opp_wager), opp_max_roll))
                DRU.HistoryChange("FastWin", sender, opp_roll, opp_max_roll, time(), nil, sender, opp_wager)
            else
                DRU.print(string.format("%s wants to deathroll you for %s starting from %d!", sender, stringify(opp_wager), opp_max_roll))
                DRU.HistoryChange("NewRequest", sender, opp_roll, opp_max_roll, time(), nil, sender, opp_wager)
            end

        elseif msg_type == "RemoveRequest" then -- removes player from requests
            DRU.HistoryChange("RemoveRequest", sender)
            DRU.print(string.format("%s canceled their pending deathroll.", sender))
            
        elseif msg_type == "AcceptRequest" then -- confirms msg we accept their game
            DRU.print(string.format("%s accepts your deathroll!", sender))
            if opp_wager > gs.my_wager then
                DRU.print(string.format("%s bets %d against your %dg!", sender, opp_wager, gs.my_wager))
            end
            DRU.AddWager(opp_wager, "Opp")

        elseif msg_type == "ForceRemoveRequest" then -- for if they don't officially accept our roll but /roll the right thing
            DRU.HistoryChange("RemoveRequest", sender)
            
        elseif msg_type == "CancelGame" then -- cancel request receive
            DRU.print(string.format("%s has canceled the deathroll.", sender))
            DRU.HistoryChange("EndGame", nil, nil, nil, nil, "Cancel")
            end_game()
        end
    end
end)

-- wrapper function for sending messages through addon channel
function send_addon_data(message, channel, target, sender)
    if not message or message == "" then -- safety check!
        if DRU.DEBUG then print("send_addon_data had no message and was not sent.") end
    elseif channel == "WHISPER" and target then
        C_ChatInfo.SendAddonMessage(prefix, message, "WHISPER", target)
    end
end

-- listening for system messages
local roll_listener = CreateFrame("Frame")
roll_listener:RegisterEvent("CHAT_MSG_SYSTEM")  -- system messages, like rolls
roll_listener:SetScript("OnEvent", function(self, event, msg, sender, ...)
    if not msg:find("rolls", 1, true) then return end -- if not roll then discard
    DRU.ParseRoll(msg)
end)

function DRU.ParseRoll(msg)
    DRU.GetGameState()

    local history_type = nil -- in what way to add roll to history
    local print_result = "" -- lose/win prints
    local result = nil -- added to history
    local roller, roll_str, min_roll_str, max_roll_str = string.match(msg, "^(.-) rolls (%d+) %((%d+)-(%d+)%)$") -- transform from string to information
    local roll = tonumber(roll_str)
    local min_roll = tonumber(min_roll_str)
    local max_roll = tonumber(max_roll_str)

    if my_request_pending and roller == DRU.me then
        player_targeted, target_name = target_check()
        send_addon_data("GameRequest:" .. roll .. ":" .. max_roll .. ":" .. gs.my_wager, "WHISPER", target_name) -- has to be here because it needs to know the roll before sending
        DRU.LuckCheck(roll, max_roll, roller) -- check if the roll was special in some way for stat keeping
        result, print_result, history_type = result_check(roll, roller)
        my_request_pending = false
        
    elseif gs.in_game and ((roller == DRU.me) or (roller == gs.curr_opp)) then
        local is_scam, scam_type, exp_roll = scam_check(min_roll, max_roll, roller)
        local roll_index = DRU.GetRollIndex()
        if is_scam then
            if roll_index ~= 1 then -- the second roll should not be explicitely counted as a scam roll, because we cannot verify that the roll was purposed for our request with certainty.
                scam_alert(scam_type, roller, min_roll, max_roll, exp_roll)
            end
            if DRU.DEBUG then print("Right opp, wrong roll. Returning...") end
            return
        else
            if (roll_index == 1) and (roller ~= DRU.me) then -- on their response to our first roll, check if their wager is lower
                C_Timer.After(1, function() opp_wager_check() end)
            end

            result, print_result, history_type = result_check(roll, roller)
            DRU.LuckCheck(roll, max_roll, roller)

            if roll_index == 1 then -- if it's the second roll we make sure their request is removed to get around /roll abuse
                send_addon_data("ForceRemoveRequest:" .. roll .. ":" .. max_roll .. ":" .. gs.my_wager, "WHISPER", target_name)
            end
        end

    else -- it's a roll for which we do not know the purpose
        if roller ~= DRU.me then
            C_Timer.After(1, function() -- wait 1 second for any possible requests to process
                local found = DRU.RequestCheck(roller)
                if not found then
                    if DRU.DEBUG then print("Adding random roll to table...") end
                    random_rolls[roller] = {time(), roller, roll, max_roll} -- save with roller as key so only the most recent roll is known
                return
                end
            end)
        end
    end

    DRU.print(print_result)
    DRU.HistoryChange(history_type, roller, roll, max_roll, time(), result, target_name, gs.my_wager) -- we only ever need to pass my wager here bc opp wager is stored via the addon channel
    if result == nil then DRU.GetGameState() else end
    DRU.ButtonUpdate(gs.in_game, gs.my_turn)
    if (history_type == "FastLoss") or (history_type == "EndGame") then
        end_game()
    end
end

function attempt_game_start(my_max_roll, my_wager, source)
    local is_valid_target, target_name, err_msg = target_check()
    if not is_valid_target then
        if DRU.DEBUG then print("Invalid target.") end
        DRU.print(err_msg)
        return
    end

    chat_roll_check(my_max_roll, target_name) -- if roll and target matches, the chat roll is added to requests
    local is_target_request_pending, _, _, target_roll, _, target_wager = DRU.RequestCheck(target_name) -- see if there's any requests that our roll is the response to

    local is_valid_roll, err_msg = roll_check(my_max_roll, target_roll, target_name, is_target_request_pending, target_wager)
    if not is_valid_roll then
        if DRU.DEBUG then print("Invalid roll.") end
        DRU.print(err_msg)
        return
    end

    local is_valid_wager, my_new_wager, err_msg = wager_check(my_wager, target_wager, target_name, is_target_request_pending) -- redefine my_wager because we auto-match target's wager if we bet 0.
    if not is_valid_wager then
        if DRU.DEBUG then print("Invalid wager.") end
        DRU.print(err_msg)
        return
    end

    if DRU.DEBUG then print("All checks passed. Starting game...") end
    local game_type = "SendRequest"
    if is_target_request_pending then
        game_type = "AcceptRequest"
        DRU.HistoryChange("MoveRequest", target_name) -- only need to pass player argument to know who's request to move
        DRU.HistoryChange("RemoveRequest", target_name)
        DRU.AddWager(my_new_wager, "Me")
        my_max_roll = target_roll
    end

    DRU.gamestate.my_wager = my_new_wager
    do_roll(game_type, target_name, my_max_roll, my_new_wager)
end

function roll_check(my_roll, exp_roll, target_name, pending_request, target_wager) -- returns x, y, z
    local result = true
    local err_msg = ""

    if pending_request then
        if (my_roll ~= exp_roll) and (my_roll ~= 0) then
            result = false
            err_msg = string.format("%s already has a roll request pending, starting from %d for %s.", target_name, exp_roll, stringify(target_wager))
        end

    else
        if type(my_roll) ~= "number" or my_roll < 2 or my_roll > 1000000 then -- min and max rolls are invalid
            result = false
            err_msg = "Please enter a valid roll."
        end
    end

    if DRU.DEBUG then print("roll_check:",result, err_msg) end
    return result, err_msg
end

function wager_check(my_wager, target_wager, target_name, pending_request)
    local err_msg = ""
    local result = true

    if (my_wager < 0) or (my_wager > 9999999) or (type(my_wager) ~= "number") then
        result = false
        err_msg = "Please enter a valid wager."
    end

    if pending_request then
        if (my_wager < target_wager) and (my_wager ~= 0) then
            result = false
            err_msg = string.format("You can't bet less than your opponent (%dg). Please try again.", target_wager)
        elseif (my_wager == 0) and target_wager then
            my_wager = target_wager
        elseif my_wager > target_wager then
            err_msg = string.format("You are betting %dg against %s's %dg!", my_wager, target_name, target_wager)
        end
    end

    if DRU.DEBUG then print("wager_check:", result, err_msg) end
    return result, my_wager, err_msg
end

-- button functionality
function DRU.button_click()
    DRU.GetGameState()
    if gs.in_game then
        if gs.my_turn == false then
            DRU.print("It's not your turn.")
        else
            DRU.textbox:SetText("") -- if we're in game we don't care what the textbox has.
            DRU.textbox:ClearFocus()
            do_roll("Roll", gs.curr_opp, gs.last_roll)
        end
        
    else -- not in game
        local roll, wager
        if DRU.textbox:GetText() == "" then 
            roll, wager = 0, 0 
        else
            roll, wager = strsplit(" ", DRU.textbox:GetText())
            roll = roll or 0
            wager = wager or 0
        end
        attempt_game_start(tonumber(roll), tonumber(wager), "Button")
    end
end

function do_roll(type, target_name, roll, wager)
    if type == "Roll" then
        -- do nothing special in particular

    elseif type == "SendRequest" then
        my_request_pending = true -- now we wait for roll_parser() to see our roll so we can send the game request
        DRU.ButtonUpdate(gs.in_game, gs.my_turn)
        DRU.print(string.format("Deathrolling %s for %s!", target_name, stringify(wager)))
        
    elseif type == "AcceptRequest" then
        send_addon_data(string.format("AcceptRequest:nil:nil:"..wager), "WHISPER", target_name)
        DRU.ButtonUpdate(gs.in_game, gs.my_turn)
        DRU.print(string.format("Deathrolling %s for %s!", target_name, stringify(wager)))
    end
    
    ChatFrame1EditBox:SetText(string.format("/roll %d", roll))
    ChatEdit_SendText(ChatFrame1EditBox)
end

function target_check() -- checks if player targeted, if they're in our group, and if they're connected.
    local err_msg = ""
    local targeted = UnitIsPlayer("target")
    local target = UnitName("target")
    local result = true
    local group = nil

    if targeted and (target ~= DRU.me) then
        local total_members = GetNumGroupMembers()

        if IsInGroup() then group = "party"
        elseif IsInRaid() then group = "raid"
        end

        -- my amazing generic for loop for both raids and parties mmmmm yeah
        local found = false
        for i = 1, total_members do
            local name = UnitName(group..i) -- UnitName("party1") is the first member in your party
            if name == target then
                found = true
                break
            end
        end
        if found == false then 
            result = false
            err_msg = string.format("%s is not in your party! They won't be able to see your roll. Get in a party together before deathrolling.", target)
        end

        if found then -- only check this if target is in our group; otherwise the client cannot know if the target is connected or not
            if UnitIsConnected(target) == false then
                result = false
                err_msg = string.format("%s is not online right now.", target)
            end
        end

    else -- no target
        result = false
        err_msg = "Please target a player to start a deathroll. Type /drgames to see who wants to roll you."
    end

    return result, target, err_msg
end

function chat_roll_check(starting_roll, target)
    for _, roll_table in pairs(random_rolls) do -- now we check if our roll happens to be a response to a random /roll in chat
        if (roll_table[3] == starting_roll) and (roll_table[2] == target) then
            if DRU.debug then print("Detected random roll as starting roll.") end
            DRU.HistoryChange("NewRequest", roll_table[2], roll_table[3], roll_table[4], time(), nil, roll_table[2], 0)
            random_rolls[roll_table] = nil
            return true
        end
    end
    return false
end

function result_check(roll, roller)
    if roll == 1 then
        if my_request_pending and roller == DRU.me then
            return "Loss", "You lost immediately!", "FastLoss"
        elseif roller == DRU.me then
            return "Loss", "You lost!", "EndGame"
        else
            return "Win", "You won!", "EndGame"
        end

    elseif my_request_pending then
        return nil, "", "NewGame"
    else
        return nil, "", "Roll"
    end
end

function end_game() -- should activate if a game ends; resets globals to default
    my_request_pending = false
    DRU.StreakCheck()
    DRU.ButtonUpdate(gs.in_game, gs.my_turn)
end

-- checks for turns, min and max rolls.
function scam_check(min_roll, max_roll, roller) -- TODO: smart combinations of scams
    if (gs.my_turn and roller ~= DRU.me) or (not gs.my_turn and roller == DRU.me) then
        return true, "wrong_turn"
    elseif min_roll ~= 1 then
        return true, "wrong_min"
    elseif max_roll ~= gs.last_roll and gs.last_roll ~= 1 then
        return true, "wrong_max", gs.last_roll
    else
        return false
    end
end

function scam_alert(scam_type, scammer, min_roll, max_roll, exp_roll)
    if scam_type == "wrong_min" then
        DRU.print(string.format("%s's minimum roll was %d instead of 1. They are scamming!", scammer, min_roll))
    elseif scam_type == "wrong_max" then
        DRU.print(string.format("%s rolled for %d instead of %d. They are scamming!", scammer, max_roll, exp_roll))
    elseif scam_type == "wrong_turn" then
        DRU.print(string.format("%s rolled out of turn!", scammer))
    elseif scam_type == "wrong_turn + wrong_min" then
        DRU.print(string.format("%s rolled out of turn AND their minimum roll was %d instead of 1. They are scamming!", scammer, exp_roll))
    end
end

function opp_wager_check() -- checks if opponents wager is less than ours at start of roll
    local wager = DRU.GetCurrOppWager()
    if wager < gs.my_wager then
        print("SHIIIAAAAATTT")
    end
end

function stringify(wager)
    if wager == 0 then wager = "fun"
    else wager = (wager.."g")
    end
    return wager
end

function DRU.print(msg)
    if (msg ~= "") and (msg ~= nil) then
        local pre = "|cffffff00DRU:|r "
        print(pre..msg)
    end
end

-- COMMANDS
SLASH_DEATHROLLTRY1 = "/drtry" -- dev tool
SlashCmdList["DEATHROLLTRY"] = function()
    target_check()
end

SLASH_DEATHROLL1 = "/dr"
SLASH_DEATHROLL2 = "/deathroll"
SlashCmdList["DEATHROLL"] = function(msg) -- msg is whatever player types after cmd
    DRU.GetGameState()
    local roll, wager
        if msg == "" then 
            roll, wager = 0, 0
        else
            roll, wager = strsplit(" ", msg)
            roll = roll or 0
            wager = wager or 0
        end
    roll = tonumber(roll)
    wager = tonumber(wager)

    if gs.in_game then
        if gs.my_turn == false then
            DRU.print("It's not your turn.")
        else
            if (roll ~= 0) and (roll ~= gs.last_roll) then
                DRU.print("That's not the right roll.")
            elseif (wager ~= 0) then
                DRU.print("You can't add a wager in the middle of a roll.")
            else
                do_roll("Roll", gs.curr_opp, gs.last_roll)
            end
        end

    else -- not in game
        attempt_game_start(tonumber(roll), tonumber(wager), "Command")
    end
end

SLASH_RELOADUI1 = "/rl" -- quick reload
SlashCmdList.RELOADUI = ReloadUI

SLASH_DEATHROLLCANCEL1 = "/drcancel"
SlashCmdList["DEATHROLLCANCEL"] = function()
    local roll_index = DRU.GetRollIndex()
    local player = DRU.GetRoll()

    if gs.in_game then
        if roll_index == 1 then
            send_addon_data("RemoveRequest", "WHISPER", gs.curr_opp)
        else
            send_addon_data("CancelGame", "WHISPER", gs.curr_opp)
        end

        DRU.print(string.format("Deathroll with %s canceled.", gs.curr_opp))
        DRU.HistoryChange("EndGame", nil, nil, nil, nil, "Cancel")
        end_game()
    else
        DRU.print("You're not in a deathroll right now.")
    end
end

SLASH_DEATHROLLDEBUG1 = "/drd"
SlashCmdList["DEATHROLLDEBUG"] = function()
    print("===== Death Roll Debug =====")
    print("Last Roller: " .. tostring(gs.last_roller))
    print("Last Roll: " .. tostring(gs.last_roll))
    -- print("Last Max Roll: " .. tostring(last_max_roll))
    print("In Game: " .. tostring(gs.in_game))
    print("My Turn: " .. tostring(gs.my_turn))
    print("My Wager: " .. tostring(gs.my_wager))
    print("Opp Wager: " .. tostring(gs.opp_wager))
    print("My Request Pending: " .. tostring(my_request_pending))
    print("Target Name: " .. tostring(target_name))
    -- print("Target Request pending: ".. tostring(target_request_pending))
    print("Current Opponent: " .. tostring(gs.curr_opp))
    -- print("Current Opponent Roll: " .. tostring(curr_opp_roll))
    print("=========================")
end

SLASH_DEATHROLLHELP1 = "/drhelp"
SlashCmdList["DEATHROLLHELP"] = function()
    print(
[[|cffffff00DRU:|r To start a deathroll, target a player and type "/dr <roll> <wager>"
Type "/drmenu" to see your match history, statistics and settings.
Type "/drgames" to see who wants to roll you.
Type "/drbutton" to enable/disable the deathrolling button.
Type "/drcancel" during a roll to ask your opponent to agree to cancel the game.
Type "/drcontinue" to decline your opponent's cancellation request.
Type "/drclear" to clear your game history.
]])
end