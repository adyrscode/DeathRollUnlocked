SLASH_RELOADUI1 = "/rl" -- quick reload
SlashCmdList.RELOADUI = ReloadUI

-- prefix for our own addon channel
local prefix = "deathroll_data"


-- players and their rolls
local me = UnitName("player")
local starting_roll = 0 -- your first roll in the game
local my_roll = 0 -- result of my roll
local textbox_roll = 0 -- textbox input roll
local rolls = {} -- list of all rolls
local requests = {} -- list of roll requests
local target_request = false
local request_accepted = false
local cancel_confirmation = false
local cancel_lock = false

local chat_roller = nil
local curr_opp = nil -- opponent of current game
local curr_opp_roll = 0 -- what did our opponent roll

local rolled_min_number
local rolled_max_number = 0
local rolled_number = 0

-- targeting stuff
local player_targeting -- function to check 2 variables:
local player_targeted = false -- do we have a valid player targeted? (not ourselves, not an npc)
local target_name = nil -- name of our target

-- game states
local in_game = false -- are we in a game right now
local my_turn = true -- is it our turn
local wait_for_my_roll = false
local cancel_timer = false -- timer which prevents cancel abuse

-- functions
local do_roll
local start_game
local end_game
local textbox_start_roll
local scam_alert
local list_add
local button_click
local send_addon_data
local add_request
local request_check

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
button:SetText("Start Roll!")
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
local addon_listener = CreateFrame("Frame")
addon_listener:RegisterEvent("CHAT_MSG_ADDON")
addon_listener:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix == "deathroll_data" then -- if the addonmessage is from deathroll_data
        local msg_type, opp_request_roll_str, opp_request_max_roll_str = strsplit(":", message)
        local short_sender = sender:match("^[^-]+") or sender -- take realm name out

        if msg_type == "GameRequest" then -- game reqeust
            local opp_request_max_roll = tonumber(opp_request_max_roll_str)
            local opp_request_roll = tonumber(opp_request_roll_str)
            print(string.format("[DR+] %s wants to deathroll you starting from %d!", short_sender, opp_request_max_roll))
            add_request(short_sender, opp_request_roll, opp_request_max_roll)

        elseif msg_type == "RemoveRequest" then -- removes player from list
            requests[short_sender] = nil
            print(string.format("[DR+] %s canceled their roll.", short_sender))

        elseif msg_type == "AcceptRequest" then -- confirms we accept their game
            print(string.format("[DR+] %s accepts your deathroll!", short_sender))
            request_accepted = true

        elseif msg_type == "CancelGame" then
            print(string.format("[DR+] %s has requested to cancel the deathroll.\nType /drcancel to agree or /drcontinue to deny.", short_sender))
            cancel_confirmation = true

        elseif msg_type == "CancelConfirm" then
            print(string.format("[DR+] %s agreed to cancel the deathroll.", short_sender))
            cancel_confirmation = false
            end_game()

        elseif msg_type == "CancelDeny" then
            print(string.format("[DR+] %s denied your request to cancel the deathroll.", short_sender))
            cancel_lock = true
        end
    end
end)

-- wrapper function for sending messages through addon channel
function send_addon_data(message, channel, target, sender)
    if not message or message == "" then -- safety check!
        print("[DR+] send_addon_data had no message and was not sent.")
    elseif channel == "WHISPER" and target then
        C_ChatInfo.SendAddonMessage(prefix, message, "WHISPER", target)
        cancel_timer = true
        C_Timer.After(10, function()
            cancel_timer = false
        end)
    end
end

-- add a game request to a table
function add_request(opp_request, opp_request_roll, opp_request_max_roll)
    requests[opp_request] = {opp_request_roll = opp_request_roll, opp_request_max_roll = opp_request_max_roll}
end

function textbox_start_roll()
    if textbox:GetText() ~= "" then -- if the textbox does NOT have NOTHING
        local textbox_str = textbox:GetText() -- get the string
        textbox_roll = tonumber(textbox_str) -- make it a number
        
        if textbox_roll > 999999 or textbox_roll == 1 then -- min and max rolls are invalid
            print("[DR+] Please enter a valid roll.")
            textbox:SetFocus()
            
        else
            textbox:SetText("")
            textbox:ClearFocus()
            starting_roll = textbox_roll
            curr_opp = target_name
            wait_for_my_roll = true
            start_game()
        end
    else
        print("[DR+] Please enter a roll.")
        textbox:SetFocus()
    end
end

-- listening for system messages
local roll_listener = CreateFrame("Frame")
roll_listener:RegisterEvent("CHAT_MSG_SYSTEM")  -- system messages, like rolls
roll_listener:SetScript("OnEvent", function(self, event, msg, sender, ...)
    local temp_chat_roller, rolled_number_str, rolled_min_str, rolled_max_str = string.match(msg, "^(.-) rolls (%d+) %((%d)-(%d+)%)$") -- is it a roll?
    rolled_number = tonumber(rolled_number_str) -- change roll to number
    rolled_max_number = tonumber(rolled_max_str) 
    rolled_min_number = tonumber(rolled_min_str) 
    chat_roller = temp_chat_roller -- we have to do this because fuck programming
    
    if rolled_min_number ~= 1 then -- if minimum roll is not 1
        if in_game and my_turn and chat_roller == curr_opp and request_accepted then -- if it's a wrong turn it must also be called out.
            scam_alert("wrong_turn + min_not_one", curr_opp, nil, rolled_min_number)
        elseif in_game and my_turn == false and chat_roller == me and request_accepted then -- if it's a wrong turn it must also be called out.
            scam_alert("wrong_turn + min_not_one", me, nil, rolled_min_number)
        else
            scam_alert("min_not_one", chat_roller, nil, rolled_min_number)
        end

    elseif in_game and chat_roller == me then -- if we're in game and the roller is myself
        if my_turn == false then -- if it's not our turn then we're scamming
            scam_alert("wrong_turn", chat_roller)

        elseif curr_opp_roll ~= 0 and rolled_max_number ~= curr_opp_roll then -- did we roll the right roll?
            scam_alert("wrong_max", me, rolled_max_number, curr_opp_roll)

        elseif rolled_number == 1 then -- if we rolled 1 we lost
            print("[DR+] You lost!")
            list_add()
            end_game()

        else     -- otherwise the game continues
            my_roll = rolled_number
            if wait_for_my_roll == true then
                send_addon_data("GameRequest:" .. my_roll .. ":" .. rolled_max_number, "WHISPER", target_name) -- type, maxroll, myroll, target
                wait_for_my_roll = false
            end
            list_add()
            my_turn = false
        end

    elseif in_game and curr_opp == chat_roller and request_accepted then -- if we're in game and the roller is our opponent
        if my_turn then
            scam_alert("wrong_turn", curr_opp)

        else
            if rolled_max_number ~= my_roll then
                scam_alert("wrong_max", curr_opp, rolled_max_number, my_roll)

            elseif rolled_number == 1 then
                print("[DR+] You won!")
                list_add()
                end_game()

            else -- otherwise the game continues
                list_add()
                curr_opp_roll = rolled_number
                my_turn = true
            end
        end

    else -- if it's not an illegal roll, it's not ours or part of our game, fuck it just add it to the list anyway. 
        list_add()
    end
end)

-- button functionality
function button_click()
    player_targeting() -- every time we click the button, we check the state of player targeting.
    if in_game == true then
        textbox:SetText("") -- if we're in game we don't care what the textbox has.
        textbox:ClearFocus()

        if my_turn == false then
            print("[DR+] It's not your turn.")

        elseif my_turn == true then
            do_roll()
        end

    elseif in_game == false then -- if we're not in game
        if player_targeted then

            request_check()
            if target_request == true then
                if textbox:GetText() == "" then
                    request_accepted = true
                    start_game()
                else
                    print(string.format("[DR+] %s already has a roll request pending. Type /dr to roll their %d?", requests(tostring[target_name]), requests[target_name].opp_request_roll))
                end

            else
                textbox_start_roll()
            end
        else
            print("[DR+] Please target a player to start a deathroll.")
        end
    end
end

function request_check()
    if next(requests) ~= nil then -- if there's something in the request list it takes prio
        for opp_request in pairs(requests) do
            if opp_request == target_name then -- if they're in our request list, accept the roll
                target_request = true
            else
                target_request = false -- remember to turn off in other places
            end
        end
    end
end

function do_roll()
    ChatFrame1EditBox:SetText(string.format("/roll %d", curr_opp_roll))
    ChatEdit_SendText(ChatFrame1EditBox)  
end

function start_game() -- function should activate if a game starts
    if target_request == true then
        send_addon_data("AcceptRequest", "WHISPER", target_name)
        curr_opp = target_name
        starting_roll = requests[target_name].opp_request_roll
        if curr_opp then -- we need to check if curr_opp is not already nil i guess
            requests[curr_opp] = nil -- remove them from the list
        end
    else 
        curr_opp = target_name
    end
    print(string.format("[DR+] Deathrolling %s!", curr_opp))
    ChatFrame1EditBox:SetText(string.format("/roll %d", starting_roll))-- sets the text
    ChatEdit_SendText(ChatFrame1EditBox)    -- sends it
    in_game = true 
    button:SetText("Roll!")
end

function end_game() -- should activate if a game ends; resets globals to default
    curr_opp = nil
    my_roll = 0
    curr_opp_roll = 0
    starting_roll = 0
    in_game = false
    my_turn = true
    target_request = false
    request_accepted = false
    cancel_lock = false
    button:SetText("Start Roll!")
end

function list_add()
    if chat_roller and rolled_number then
        if not rolls[chat_roller] then -- if roller is not in roll list
        rolls[chat_roller] = {} -- add them
        end
        table.insert(rolls[chat_roller], rolled_number) -- add rolls to existing name
    else
        print("[DR+] List_add called with nil values!")
    end
end

function player_targeting()
    if UnitIsPlayer("target") and not UnitIsUnit("target", "player") then -- if a player is targeted and it's not ourselves
        player_targeted = true
        target_name = UnitName("target")
    else 
        player_targeted = false
        target_name = nil
    end
end

function scam_alert(scam_type, scammer, value, expected_roll)
    if scam_type == "min_not_one" then
        print(string.format("[DR+] %s's minimum roll was %d instead of 1. They are scamming!", scammer, expected_roll))
    elseif scam_type == "wrong_max" then
        print(string.format("[DR+] %s rolled for %d instead of %d. They are scamming!", scammer, value, expected_roll))
    elseif scam_type == "wrong_turn" then
        print(string.format("[DR+] %s rolled out of turn!", scammer))
    elseif scam_type == "wrong_turn + min_not_one" then
        print(string.format("[DR+] %s rolled out of turn AND their minimum roll was %d instead of 1. They are scamming!", scammer, expected_roll))
    end
end

-- commands!
SLASH_DEATHROLL1 = "/dr"
SLASH_DEATHROLL2 = "/deathroll"
SlashCmdList["DEATHROLL"] = function(msg) -- msg is whatever player types after cmd
    player_targeting()
    if in_game then
        if my_turn == false then
            print("[DR+] It's not your turn.")
        elseif msg ~= "" and tonumber(msg) ~= curr_opp_roll then
            print("[DR+] That's not the right roll.")
        else
            do_roll()
        end

    else
        if player_targeted == false then
            print("[DR+] Please target a player to deathroll. Type /drgames to see who wants to roll you.") -- second part is a lie lol
        elseif player_targeted then
            request_check()
            if target_request == true then
                if msg == "" then
                    request_accepted = true
                    start_game()
                elseif tonumber(msg) == requests[target_name].opp_request_roll then
                    request_accepted = true
                    start_game()
                else
                    print(string.format("[DR+] %s already has a roll request pending. Type /dr to roll their %d?", requests[target_name], requests[target_name].opp_request_roll))
                end

            else
                local chat_box = tonumber(msg) -- convert to number
                if not chat_box then 
                    print("[DR+] Please type a valid number to roll.")
                else
                    starting_roll = chat_box
                    curr_opp = target_name
                    wait_for_my_roll = true
                    start_game()
                end
            end

        end
    end
end

SLASH_DEATHROLLCANCEL1 = "/dr cancel"
SLASH_DEATHROLLCANCEL2 = "/drcancel"
SlashCmdList["DEATHROLLCANCEL"] = function()
    if cancel_confirmation == true then
        print(string.format("[DR+] Deathroll with %s canceled.", curr_opp))
        send_addon_data("CancelConfirm", "WHISPER", target_name)
        end_game()
    elseif cancel_lock == true then
        print("[DR+] You can't request to cancel again.")

    else
        if in_game and request_accepted == false then -- we've started a game but opp hasn't accepted yet, then we can just cancel dr.
            if cancel_timer == true then
                print("[DR+] You can't cancel your request yet.")
            else
                print("[DR+] Deathroll request canceled.")
                send_addon_data("RemoveRequest", "WHISPER", target_name)
                end_game()
            end
            
        elseif in_game and request_accepted then -- if we're midgame they need to agree to for cancellation though
            send_addon_data("CancelGame", "WHISPER", target_name)
            print(string.format("[DR+] Cancellation request sent to %s", curr_opp))
        else
            print("[DR+] You're not in a deathroll right now.")
        end
    end
end

SLASH_DEATHROLLCONTINUE1 = "/drcontinue"
SlashCmdList["DEATHROLLCONTINUE"] = function()
    print("[DR+] Cancellation request denied.")
    send_addon_data("CancelDeny", "WHISPER", target_name)
    cancel_confirmation = false
end

SLASH_DEATHROLLGAMES1 = "/drgame"
SLASH_DEATHROLLGAMES2 = "/drgames"
SlashCmdList["DEATHROLLGAMES"] = function()
    if next(requests) ~= nil then
        for opp_request, data in pairs(requests) do
            print(string.format("[DR+] %s started from %d and rolled %d.\n", opp_request, data.opp_request_max_roll, data.opp_request_roll))
        end
    else
        print("[DR+] You have no deathroll requests right now.")
    end
end

SLASH_DEATHROLLBUTTON1 = "/drbutton"
SLASH_DEATHROLLBUTTON2 = "/deathrollbutton"
SLASH_DEATHROLLBUTTON3 = "/dr button"
SLASH_DEATHROLLBUTTON4 = "/deathroll button"
SlashCmdList["DEATHROLLBUTTON"] = function() -- hide and show the button
    if parentFrame:IsShown() then
        parentFrame:Hide()
    else parentFrame:Show()
    end
end

SLASH_DEATHROLLDEBUG1 = "/drd"
SlashCmdList["DEATHROLLDEBUG"] = function()
    print("===== Death Roll Debug =====")
    print("Player Targeted: " .. tostring(player_targeted))
    print("Target Name: " .. tostring(target_name))
    print("Target Request: " .. tostring(target_request))
    print("Request Accepted: " .. tostring(request_accepted))
    print("Total Rolls Recorded: " .. tostring(#rolls))
    print("Chat Roller: " .. tostring(chat_roller))
    print("Rolled Number: " .. tostring(rolled_number))
    print("Rolled Max Number: " .. tostring(rolled_max_number))
    print("Starting Roll: " .. tostring(starting_roll))
    print("Our Roll: " .. tostring(my_roll))
    print("In Game: " .. tostring(in_game))
    print("My Turn: " .. tostring(my_turn))
    print("Current Opponent: " .. tostring(curr_opp))
    print("Current Opponent Roll: " .. tostring(curr_opp_roll))
    print("Textbox Roll: " .. tostring(textbox_roll))
    print("Interface: " .. tostring(select(4, GetBuildInfo())))
    print("=========================")
end