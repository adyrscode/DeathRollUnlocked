-- this file manages the core gameplay loop of deathrolling.

-- prefix for our own addon channel
local prefix = "deathroll_data"
DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked

-- players and their rolls
DRU.me = UnitName("player")
local target_name = nil

-- game states
DRU.gamestate = {in_game = false, curr_game = nil, my_turn = false, curr_opp = nil, last_roller = nil, last_roll = 0}
local gs = DRU.gamestate
local my_request_sent = false
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
local scam_checker
local scam_alert
local button_click
local send_addon_data

local addon_loader = CreateFrame("Frame") -- addon loading stuff
addon_loader:RegisterEvent("ADDON_LOADED")
addon_loader:SetScript("OnEvent", function(self, event, addon_name)
    if addon_name == "DeathRollUnlocked" then
        if not DRUDB or DRUDB == nil or type(DRUDB) ~= "table" then
            DRUDB = {}
        end
        DRUDB.global_stats = DRUDB.global_stats or {total_wins = 0, total_losses = 0}
        DRUDB.games = DRUDB.games or {}
        DRUDB.requests = DRUDB.requests or {}
        DRU.GetGameState()
    end
end)

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
local button = CreateFrame("Button", nil, parentFrame, "UIPanelButtonTemplate")
button:SetSize(100, 30)
button:SetPoint("BOTTOM", parentFrame, "CENTER", 0, 0)
button:SetText("Start Roll!") -- TODO
button:SetScript("OnMouseDown", OnDragStart) -- button middle mouse button can move the frame
button:SetScript("OnMouseUp", OnDragStop)
button:SetScript("OnClick", function(self, button)
    button_click()
end)

-- create the textbox
local textbox = CreateFrame("EditBox", nil, parentFrame, "InputBoxTemplate")
textbox:SetSize(94, 30)                     -- width x height
textbox:SetPoint("CENTER", parentFrame, "CENTER", 3, -8)  -- position inside the frame
textbox:SetAutoFocus(false)                  -- don’t auto-focus when shown
textbox:SetNumeric(true) -- only allow numbers to be typed
textbox:SetScript("OnEnterPressed", function(self) -- if enter is pressed
    button_click()
end)
    
-- listening frame for receiving addon messages
C_ChatInfo.RegisterAddonMessagePrefix(prefix)
local channel_listener = CreateFrame("Frame")
channel_listener:RegisterEvent("CHAT_MSG_ADDON")
channel_listener:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix == "deathroll_data" then -- if the addonmessage is from deathroll_data
        local msg_type, opp_request_roll_str, opp_request_max_roll_str = strsplit(":", message)
        local short_sender = sender:match("^[^-]+") or sender -- take realm name out
        
        if msg_type == "GameRequest" then -- game reqeust
            local opp_request_max_roll = tonumber(opp_request_max_roll_str)
            local opp_request_roll = tonumber(opp_request_roll_str)
            print(string.format("[DRU] %s wants to deathroll you starting from %d!", short_sender, opp_request_max_roll))
            DRU.HistoryChange("NewRequest", short_sender, opp_request_roll, opp_request_max_roll, time())
                
        elseif msg_type == "RemoveRequest" then -- removes player from list
            DRU.HistoryChange("RemoveRequest", short_sender)
            print(string.format("[DRU] %s canceled their roll.", short_sender))
            
        elseif msg_type == "AcceptRequest" then -- confirms we accept their game
            print(string.format("[DRU] %s accepts your deathroll!", short_sender))
            
        elseif msg_type == "CancelGame" then
            print(string.format("[DRU] %s has requested to cancel the deathroll.\nType /drcancel to agree, or keep rolling to deny.", short_sender))
            cancel_confirmation = true
            
        elseif msg_type == "CancelConfirm" then
            print(string.format("[DRU] %s agreed to cancel the deathroll.", short_sender))
            cancel_confirmation = false
            DRU.HistoryChange("EndGame", nil, nil, nil, nil, "Cancel")
            end_game()
            
        elseif msg_type == "CancelDeny" then
            print(string.format("[DRU] %s denied your request to cancel the deathroll.", short_sender))
            cancel_lock = true
        end
    end
end)

-- wrapper function for sending messages through addon channel
function send_addon_data(message, channel, target, sender)
    if not message or message == "" then -- safety check!
        print("[DRU] send_addon_data had no message and was not sent.")
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
    
        local history_type = nil
        local print_type = ""
        local result = nil
        local roller, roll_str, min_roll_str, max_roll_str = string.match(msg, "^(.-) rolls (%d+) %((%d+)-(%d+)%)$") -- transform from string to information
        local roll = tonumber(roll_str) -- change roll to number
        local max_roll = tonumber(max_roll_str) 
        local min_roll = tonumber(min_roll_str) 
        
        if my_request_sent and roller == DRU.me then -- sent & pending are different states because reasons
            my_request_sent = false
            my_request_pending = true
            player_targeted, target_name = target_check()
            send_addon_data("GameRequest:" .. roll .. ":" .. max_roll, "WHISPER", target_name)
            history_type = "NewGame"
            
        elseif my_request_pending then -- TODO: what if they roll 1 instantly?
            if roller == gs.curr_opp and max_roll == gs.last_roll then -- TODO
                history_type = "Roll"
                my_request_pending = false
            end
            
        elseif gs.in_game and (roller == DRU.me) or (roller == gs.curr_opp) then
            local scam, scam_type, exp_roll = scam_checker(min_roll, max_roll, roller)
            if scam then
                scam_alert(scam_type, roller, min_roll, max_roll, exp_roll)
            else
                if roll == 1 then
                    if roller == DRU.me then
                        result = "MyLoss"
                        print_type = "[DRU] You lost!"
                    else
                        result = "MyWin"
                        print_type = "[DRU] You won!"
                    end
                history_type = "EndGame"
                end_game()
                else
                    history_type = "Roll"
                end
            end
        end
    print(print_type)
    DRU.HistoryChange(history_type, roller, roll, max_roll, time(), result, target_name)
end)

function start_game(starting_roll, source)
    player_targeted, target_name = target_check()
    
    if not player_targeted then
        print("[DRU] Please target a player to start a deathroll, type /drgames to see who wants to roll you.")
        
    else -- player targeted
        local target_request_pending, time, _, target_roll, target_max_roll = DRU.RequestCheck(target_name)
        
        if (my_request_pending or my_request_sent) and target_request_pending then
            print("[DRU] You both have a roll request pending. Type /drcancel to cancel your roll request.")
            if source == "Button" then
                textbox:SetText("")
                textbox:ClearFocus()
            end
            
        elseif my_request_pending or my_request_sent then
            print("[DRU] You can't start another deathroll while you have a roll request pending.")
            if source == "Button" then
                textbox:SetText("")
                textbox:ClearFocus()
            end
            
        elseif target_request_pending then
            if starting_roll == 0 or starting_roll == target_roll then
                do_roll("AcceptRequest", target_name, target_roll)
                DRU.HistoryChange("MoveRequest", target_name, target_roll, target_max_roll, time, nil, target_name)
                DRU.HistoryChange("RemoveRequest", target_name, target_roll, target_max_roll, time, nil, target_name)
            else
                print(string.format("[DRU] %s already has a roll request pending. Type /dr to roll their %d.", target_name, target_roll))
                if source == "Button" then
                    textbox:SetText("")
                    textbox:ClearFocus()
                end
            end
            
        else -- no requests
            if starting_roll == 0 then
                print("[DRU] Please enter a roll.")
                if source == "Button" then
                    textbox:SetFocus()
                end
            else   
                if starting_roll < 2 or starting_roll > 1000000 then -- min and max rolls are invalid
                    if source == "Button" then
                        textbox:SetText("")
                        textbox:SetFocus()
                    end
                    print("[DRU] Please enter a valid roll.")
                else
                    do_roll("SendRequest", target_name, starting_roll)
                    if source == "Button" then
                        textbox:SetText("")
                        textbox:ClearFocus()
                    end
                end
            end
        end
    end
end

-- button functionality
function button_click()
    DRU.GetGameState()
    if gs.in_game then
        local curr_opp = DRU.GetCurrOpp()
        local _, last_roll = DRU.GetRoll()
        if gs.my_turn == false then
            print("[DRU] It's not your turn.")
        elseif gs.my_turn == true then
            textbox:SetText("") -- if we're in game we don't care what the textbox has.
            textbox:ClearFocus()
            do_roll("Roll", curr_opp, last_roll)
        end
        
    else -- not in game
        local roll = tonumber(textbox:GetText()) or 0
        start_game(roll, "Button")
    end
end

SLASH_DEATHROLL1 = "/dr"
SLASH_DEATHROLL2 = "/deathroll"
SlashCmdList["DEATHROLL"] = function(msg) -- msg is whatever player types after cmd
    DRU.GetGameState()
    if gs.in_game then
        local curr_opp = DRU.GetCurrOpp()
        local _, last_roll = DRU.GetRoll()
        if gs.my_turn == false then
            print("[DRU] It's not your turn.")
        else
            if msg ~= "" and tonumber(msg) ~= last_roll then
                print("[DRU] That's not the right roll.")
            else
                do_roll("Roll", curr_opp, last_roll)
            end
        end
    else
        local roll = tonumber(msg) or 0
        start_game(roll, "Command")
    end
end

function do_roll(type, target_name, roll)
    if type == "Roll" then
    elseif type == "SendRequest" then
        my_request_sent = true
        button:SetText("Roll!")
        print(string.format("[DRU] Deathrolling %s!", target_name))
        
    elseif type == "AcceptRequest" then
        send_addon_data("AcceptRequest", "WHISPER", target_name)
        button:SetText("Roll!")
        print(string.format("[DRU] Deathrolling %s!", target_name))
    end
    
    if cancel_confirmation then
        print("[DRU] Cancellation request denied.")
        send_addon_data("CancelDeny", "WHISPER", target_name)
        cancel_confirmation = false
    end
    ChatFrame1EditBox:SetText(string.format("/roll %d", roll))
    ChatEdit_SendText(ChatFrame1EditBox)  
end

function end_game() -- should activate if a game ends; resets globals to default
    my_request_sent = false
    my_request_pending = false
    cancel_lock = false
    cancel_confirmation = false
    button:SetText("Start Roll!")
end

function target_check()
    if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then -- if a player is targeted and it's not ourselves
        return true, UnitName("target")
    else 
        return false, nil
    end
end

-- checks for turns, min and max rolls.
function scam_checker(min_roll, max_roll, roller) -- TODO: smart combinations of scams
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
        print(string.format("[DRU] %s's minimum roll was %d instead of 1. They are scamming!", scammer, min_roll))
    elseif scam_type == "wrong_max" then
        print(string.format("[DRU] %s rolled for %d instead of %d. They are scamming!", scammer, max_roll, exp_roll))
    elseif scam_type == "wrong_turn" then
        print(string.format("[DRU] %s rolled out of turn!", scammer))
    elseif scam_type == "wrong_turn + wrong_min" then
        print(string.format("[DRU] %s rolled out of turn AND their minimum roll was %d instead of 1. They are scamming!", scammer, exp_roll))
    end
end

SLASH_RELOADUI1 = "/rl" -- quick reload
SlashCmdList.RELOADUI = ReloadUI

SLASH_DEATHROLLCANCEL1 = "/drcancel"
SlashCmdList["DEATHROLLCANCEL"] = function() -- TODO: how to prevent cancel abuse?
    if cancel_confirmation == true then
        send_addon_data("CancelConfirm", "WHISPER", gs.curr_opp)
        DRU.HistoryChange("EndGame", nil, nil, nil, nil, "Cancel")
        print(string.format("[DRU] Deathroll with %s canceled.", gs.curr_opp))
        end_game()
    elseif cancel_lock == true then
        print("[DRU] You can't request to cancel again.")
        
    elseif my_request_pending then
        if cancel_timer == true then
            print("[DRU] You can't cancel your request yet.")
        else
            send_addon_data("RemoveRequest", "WHISPER", gs.curr_opp) 
            DRU.HistoryChange("EndGame", nil, nil, nil, nil, "Cancel")
            print("[DRU] Deathroll request canceled.")
            end_game()
        end
        
    else            
        if gs.in_game then -- if we're midgame they need to agree to for cancellation though
            send_addon_data("CancelGame", "WHISPER", gs.curr_opp)
            cancel_lock = true
            print(string.format("[DRU] Cancellation request sent to %s", gs.curr_opp))
        else
            print("[DRU] You're not in a deathroll right now.")
        end
    end
end

SLASH_DEATHROLLCONTINUE1 = "/drcontinue"
SlashCmdList["DEATHROLLCONTINUE"] = function()
    if not gs.in_game then
        print("[DRU] You're not in a deahtroll right now.")
    else
        if cancel_confirmation == false then
            print("[DRU] There hasn't been a cancellation request.")
        else
            print("[DRU] Cancellation request denied.")
            send_addon_data("CancelDeny", "WHISPER", gs.curr_opp)
            cancel_confirmation = false
        end
    end
end

SLASH_DEATHROLLBUTTON1 = "/drbutton"
SLASH_DEATHROLLBUTTON2 = "/deathrollbutton"
SlashCmdList["DEATHROLLBUTTON"] = function() -- hide and show the button
    if parentFrame:IsShown() then
        parentFrame:Hide()
    else parentFrame:Show()
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
    print("My Request Sent: " .. tostring(my_request_sent))
    print("My Request Pending: " .. tostring(my_request_pending))
    print("Target Name: " .. tostring(target_name))
    print("Current Opponent: " .. tostring(gs.curr_opp))
    -- print("Current Opponent Roll: " .. tostring(curr_opp_roll))
    print("=========================")
end