-- this file manages the core gameplay loop of deathrolling.

-- prefix for our own addon channel
local prefix = "deathroll_data"
DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked -- anytime a function has DRU. in front of it, that means it has to be called from another file at some point

-- players and their rolls
DRU.me = UnitName("player")
local target_name = nil

-- game states
DRU.gamestate = {in_game = false, curr_game = nil, my_turn = false, curr_opp = nil, my_wager = 0, opp_wager = 0, last_roller = nil, last_roll = 0}
local gs = DRU.gamestate
local my_request_pending = false
local cancel_timer = false -- timer which prevents cancel abuse (TODO)
local cancel_confirmation = false
local cancel_lock = false
local player_targeted = false

-- functions
local target_check -- function to check 2 variables
local do_roll
local start_game
local end_game
local scam_check
local scam_alert
local send_addon_data
local result_check

local addon_loader = CreateFrame("Frame") -- addon loading stuff
addon_loader:RegisterEvent("ADDON_LOADED")
addon_loader:SetScript("OnEvent", function(self, event, addon_name)
    if addon_name == "DeathRollUnlocked" then
        if not DRUDB or DRUDB == nil or type(DRUDB) ~= "table" then
            DRUDB = {}
        end
        DRUDB.global_stats = DRUDB.global_stats or {total_wins = 0, total_losses = 0, total_gold = 0}
        DRUDB.games = DRUDB.games or {}
        DRUDB.requests = DRUDB.requests or {}
        DRU.GetGameState()
        DRU.button_update(gs.in_game, gs.my_turn) -- in_game or not in_game?
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
        local opp_wager = tonumber(opp_wager_str) -- str will be used for print, opp_wager will be used for data storage
        opp_wager_str = (tostring(opp_wager).."g")

        if msg_type == "GameRequest" then

            if opp_wager == 0 then 
                opp_wager_str = "fun" 
            end

            if opp_roll == 1 then
                print(string.format("|cffffff00DRU:|r %s wanted to deathroll you for %s starting from %d, but they immediately lost!", sender, opp_wager_str, opp_max_roll))
                DRU.HistoryChange("FastWin", sender, opp_roll, opp_max_roll, time(), nil, nil, opp_wager)
            else
                print(string.format("|cffffff00DRU:|r %s wants to deathroll you for %s starting from %d!", sender, opp_wager_str, opp_max_roll))
                DRU.HistoryChange("NewRequest", sender, opp_roll, opp_max_roll, time(), nil, nil, opp_wager)
            end
        elseif msg_type == "RemoveRequest" then -- removes player from requests
            DRU.HistoryChange("RemoveRequest", sender)
            print(string.format("|cffffff00DRU:|r %s canceled their roll.", sender))
            
        elseif msg_type == "AcceptRequest" then -- confirms msg we accept their game
            print(string.format("|cffffff00DRU:|r %s accepts your deathroll!", sender))
            DRU.AddWager(opp_wager, "Opp")
            
        elseif msg_type == "CancelGame" then -- cancel request receive
            print(string.format("|cffffff00DRU:|r %s has requested to cancel the deathroll.\nType /drcancel to agree, or /drcontinue to deny.", sender))
            cancel_confirmation = true
            
        elseif msg_type == "CancelConfirm" then -- cancel confirmation receive
            print(string.format("|cffffff00DRU:|r %s agreed to cancel the deathroll.", sender))
            cancel_confirmation = false
            DRU.HistoryChange("EndGame", nil, nil, nil, nil, "Cancel")
            end_game()
            
        elseif msg_type == "CancelDeny" then -- cancel denial receive
            print(string.format("|cffffff00DRU:|r %s denied your request to cancel the deathroll.", sender))
            cancel_lock = true
        end
    end
end)

-- wrapper function for sending messages through addon channel
function send_addon_data(message, channel, target, sender)
    if not message or message == "" then -- safety check!
        print("|cffffff00DRU:|r send_addon_data had no message and was not sent.")
    elseif channel == "WHISPER" and target then
        C_ChatInfo.SendAddonMessage(prefix, message, "WHISPER", target)
    end
end

-- listening for system messages
local roll_parser = CreateFrame("Frame")
roll_parser:RegisterEvent("CHAT_MSG_SYSTEM")  -- system messages, like rolls
roll_parser:SetScript("OnEvent", function(self, event, msg, sender, ...)
    if not msg:find("rolls", 1, true) then return end -- if not roll then discard
        DRU.GetGameState()
    
        local history_type = nil -- in what way to add roll to history
        local print_result = "" -- lose/win prints
        local result = nil -- added to history
        local roller, roll_str, min_roll_str, max_roll_str = string.match(msg, "^(.-) rolls (%d+) %((%d+)-(%d+)%)$") -- transform from string to information
        local roll = tonumber(roll_str)
        local min_roll = tonumber(min_roll_str) 
        local max_roll = tonumber(max_roll_str) 
        
        if my_request_pending and roller == DRU.me then 
            send_addon_data("GameRequest:" .. roll .. ":" .. max_roll .. ":" .. gs.my_wager, "WHISPER", target_name) -- has to be here because it needs to know the roll before sending
            player_targeted, target_name = target_check()
            result, print_result, history_type = result_check(roll, roller)
            my_request_pending = false
            
        elseif gs.in_game and (roller == DRU.me) or (roller == gs.curr_opp) then
            local scam, scam_type, exp_roll = scam_check(min_roll, max_roll, roller)
            local roll_index = DRU.GetRollIndex()
            if scam and roll_index ~= 1 then -- if only 1 roll that means roll hasn't been accepted yet so scam checks don't apply and are not processed anyway
                scam_alert(scam_type, roller, min_roll, max_roll, exp_roll)
            else
                result, print_result, history_type = result_check(roll, roller)
            end
        else
            return
        end

    print(print_result)
    DRU.HistoryChange(history_type, roller, roll, max_roll, time(), result, target_name, gs.my_wager) -- we only ever need to pass my wager here i think
    if result == nil then DRU.GetGameState() else end
    DRU.button_update(gs.in_game, gs.my_turn)
    if history_type == "FastLoss" or history_type == "EndGame" then
        end_game()
    end
end)

function start_game(starting_roll, wager, source)
    player_targeted, target_name = target_check()
    
    if not player_targeted then
        print("|cffffff00DRU:|r Please target a player to start a deathroll, type /drgames to see who wants to roll you.")
        
    else -- player targeted
        local target_request_pending, _, _, target_roll, _, target_wager = DRU.RequestCheck(target_name)
        
        if my_request_pending and target_request_pending then
            print("|cffffff00DRU:|r Somehow, you both have a roll request pending. Type /drcancel to cancel your roll request.")
            if source == "Button" then
                DRU.textbox:SetText("")
                DRU.textbox:ClearFocus()
            end
            
        elseif my_request_pending then
            print("|cffffff00DRU:|r You can't start another deathroll while you have a roll request pending.")
            if source == "Button" then
                DRU.textbox:SetText("")
                DRU.textbox:ClearFocus()
            end
            
        elseif target_request_pending then
            if starting_roll == 0 or starting_roll == target_roll then
                if wager < target_wager and wager ~= 0 then -- TODO: ask opponent if they agree to uneven bet
                    print("|cffffff00DRU:|r You can't bet less than your opponent. Please try again.")
                    return
                elseif wager == 0 then -- TODO: add consent
                    wager = target_wager
                    do_roll("AcceptRequest", target_name, target_roll, wager)
                    DRU.HistoryChange("MoveRequest", target_name) -- only need to pass player argument to know who's request to move
                    DRU.HistoryChange("RemoveRequest", target_name)
                    DRU.AddWager(wager, "Me")
                elseif wager > target_wager then
                    print(string.format("|cffffff00DRU:|r You are betting %dg against %s's %dg!", wager, target_name, target_wager))
                    do_roll("AcceptRequest", target_name, target_roll, wager)
                    DRU.HistoryChange("MoveRequest", target_name) -- only need to pass player argument to know who's request to move
                    DRU.HistoryChange("RemoveRequest", target_name)
                    DRU.AddWager(wager, "Me")
                end

            else
                print(string.format("|cffffff00DRU:|r %s already has a roll request pending. Type /dr to roll their %d.", target_name, target_roll))
                if source == "Button" then
                    DRU.textbox:SetText("")
                    DRU.textbox:ClearFocus()
                end
            end
            
        else -- no requests
            if starting_roll == 0 then
                print("|cffffff00DRU:|r Please enter a roll.")
                if source == "Button" then
                    DRU.textbox:SetFocus()
                end
            else   
                if type(starting_roll) ~= "number" or starting_roll < 2 or starting_roll > 1000000 then -- min and max rolls are invalid
                    if source == "Button" then
                        DRU.textbox:SetText("")
                        DRU.textbox:SetFocus()
                    end
                    print("|cffffff00DRU:|r Please enter a valid roll.")

                elseif type(wager) ~= "number" or wager < 0 or wager > 9999999 then
                    if source == "Button" then
                        DRU.textbox:SetText("")
                        DRU.textbox:SetFocus()
                    end
                    print("|cffffff00DRU:|r Please enter a valid wager.")

                else
                    DRU.gamestate.my_wager = wager
                    do_roll("SendRequest", target_name, starting_roll)
                    if source == "Button" then
                        DRU.textbox:SetText("")
                        DRU.textbox:ClearFocus()
                    end
                end
            end
        end
    end
end

-- button functionality
function DRU.button_click()
    DRU.GetGameState()
    if gs.in_game then
        if gs.my_turn == false then
            print("|cffffff00DRU:|r It's not your turn.")
        elseif gs.my_turn == true then
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
        start_game(tonumber(roll), tonumber(wager), "Button")
    end
end

SLASH_DEATHROLL1 = "/dr"
SLASH_DEATHROLL2 = "/deathroll"
SlashCmdList["DEATHROLL"] = function(msg) -- msg is whatever player types after cmd
    DRU.GetGameState()
    if gs.in_game then
        if gs.my_turn == false then
            print("|cffffff00DRU:|r It's not your turn.")
        else
            if msg ~= "" and tonumber(msg) ~= gs.last_roll then
                print("|cffffff00DRU:|r That's not the right roll.")
            else
                do_roll("Roll", gs.curr_opp, gs.last_roll)
            end
        end
    else -- not in game
        local roll, wager
        if msg == "" then 
            roll, wager = 0, 0 
        else
            roll, wager = strsplit(" ", msg)
            roll = roll or 0
            wager = wager or 0
        end
        start_game(tonumber(roll), tonumber(wager), "Command")
    end
end

function do_roll(type, target_name, roll, wager)
    if type == "Roll" then
    elseif type == "SendRequest" then
        my_request_pending = true
        DRU.button_update(gs.in_game, gs.my_turn)
        print(string.format("|cffffff00DRU:|r Deathrolling %s!", target_name))
        
    elseif type == "AcceptRequest" then
        send_addon_data(string.format("AcceptRequest:nil:nil:"..wager), "WHISPER", target_name)
        DRU.button_update(gs.in_game, gs.my_turn)
        print(string.format("|cffffff00DRU:|r Deathrolling %s!", target_name))
    end
    
    if cancel_confirmation then
        print("|cffffff00DRU:|r Cancellation request denied.")
        send_addon_data("CancelDeny", "WHISPER", target_name)
        cancel_confirmation = false
    end
    ChatFrame1EditBox:SetText(string.format("/roll %d", roll))
    ChatEdit_SendText(ChatFrame1EditBox)  
end

function result_check(roll, roller)
    if roll == 1 then
        if my_request_pending and roller == DRU.me then
            return "Loss", "|cffffff00DRU:|r You lost immediately!", "FastLoss"
        elseif roller == DRU.me then
            return "Loss", "|cffffff00DRU:|r You lost!", "EndGame"
        else
            return "Win", "|cffffff00DRU:|r You won!", "EndGame"
        end

    elseif my_request_pending then
        return nil, "", "NewGame"
    else
        return nil, "", "Roll"
    end
end

function end_game() -- should activate if a game ends; resets globals to default
    my_request_pending = false
    cancel_lock = false
    cancel_confirmation = false
    DRU.button_update(gs.in_game, gs.my_turn)
end

function target_check()
    if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then -- if a player is targeted and it's not ourselves
        return true, UnitName("target")
    else 
        return false, nil
    end
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
        print(string.format("|cffffff00DRU:|r %s's minimum roll was %d instead of 1. They are scamming!", scammer, min_roll))
    elseif scam_type == "wrong_max" then
        print(string.format("|cffffff00DRU:|r %s rolled for %d instead of %d. They are scamming!", scammer, max_roll, exp_roll))
    elseif scam_type == "wrong_turn" then
        print(string.format("|cffffff00DRU:|r %s rolled out of turn!", scammer))
    elseif scam_type == "wrong_turn + wrong_min" then
        print(string.format("|cffffff00DRU:|r %s rolled out of turn AND their minimum roll was %d instead of 1. They are scamming!", scammer, exp_roll))
    end
end

SLASH_RELOADUI1 = "/rl" -- quick reload
SlashCmdList.RELOADUI = ReloadUI

SLASH_DEATHROLLCANCEL1 = "/drcancel"
SlashCmdList["DEATHROLLCANCEL"] = function() -- TODO: how to prevent cancel abuse?
    local insta_cancel = false
    local roll_index = DRU.GetRollIndex()
    local player = DRU.GetRoll()
    if roll_index == 1 and player == DRU.me then
        insta_cancel = true
    end

    if cancel_confirmation then
        send_addon_data("CancelConfirm", "WHISPER", gs.curr_opp)
        DRU.HistoryChange("EndGame", nil, nil, nil, nil, "Cancel")
        print(string.format("|cffffff00DRU:|r Deathroll with %s canceled.", gs.curr_opp))
        end_game()
    elseif cancel_lock then
        print("|cffffff00DRU:|r You can't request to cancel again.")
        
    elseif insta_cancel then
        if cancel_timer then
            print("|cffffff00DRU:|r You can't cancel your request yet.")
        else
            send_addon_data("RemoveRequest", "WHISPER", gs.curr_opp) 
            DRU.HistoryChange("EndGame", nil, nil, nil, nil, "Cancel")
            print("|cffffff00DRU:|r Deathroll request canceled.")
            end_game()
        end
        
    else            
        if gs.in_game then -- if we're midgame they need to agree to for cancellation though
            send_addon_data("CancelGame", "WHISPER", gs.curr_opp)
            cancel_lock = true
            print(string.format("|cffffff00DRU:|r Cancellation request sent to %s", gs.curr_opp))
        else
            print("|cffffff00DRU:|r You're not in a deathroll right now.")
        end
    end
end

SLASH_DEATHROLLCONTINUE1 = "/drcontinue"
SlashCmdList["DEATHROLLCONTINUE"] = function()
    if not gs.in_game then
        print("|cffffff00DRU:|r You're not in a deahtroll right now.")
    else
        if cancel_confirmation == false then
            print("|cffffff00DRU:|r There hasn't been a cancellation request.")
        else
            print("|cffffff00DRU:|r Cancellation request denied.")
            send_addon_data("CancelDeny", "WHISPER", gs.curr_opp)
            cancel_confirmation = false
        end
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