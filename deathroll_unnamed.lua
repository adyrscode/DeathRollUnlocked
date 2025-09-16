SLASH_RELOADUI1 = "/rl" -- quick reload
SlashCmdList.RELOADUI = ReloadUI

-- prefix for our own addon channel
local prefix = "deathroll_data"

-- functions
local start_game
local end_game
local textbox_start_roll
local scam_alert
local list_add
local button_click
local send_addon_data
local add_request

-- lists of rolls and rollers
local rolls = {} -- list of all rolls
local requests = {} -- list of roll requests
local chat_roller = nil
local rolled_number = 0
local rolled_min_number
local rolled_max_number = 0
local wait_for_my_roll = false
local scammer = nil

-- in game, current opponent and their rolls specifically 
local starting_roll = 0 -- our first roll?
local my_roll = 0 -- what we rolled
local in_game = false -- are we in a game right now
local my_turn = true -- is it our turn
local curr_opp = nil -- opponent of current game
local curr_opp_roll = 0 -- what did our opponent roll
local opp_request = nil
local opp_request_roll = 0

-- targeting stuff
local player_targeting -- function to check 2 variables:
local player_targeted = false -- do we have a valid player targeted? (not ourselves, not an npc)
local target_name = nil -- name of our target

-- textbox stuff
local textbox_roll = 0 -- what is our textbox input roll

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

        if msg_type == "GameRequest" then -- if the message is to start a game
            local opp_request_max_roll = tonumber(opp_request_max_roll_str)
            local opp_request_roll = tonumber(opp_request_roll_str)
            local short_sender = sender:match("^[^-]+") or sender -- take realm name out
            print(string.format("%s wants to deathroll you starting from %d!", short_sender, opp_request_max_roll))
            add_request(short_sender, opp_request_roll, opp_request_max_roll)
        end
    end
end)

-- wrapper function for sending messages through addon channel
function send_addon_data(message, channel, target, sender)
    if not message or message == "" then -- safety check!
        print("[DRERR]: send_addon_data had no message and was not sent.")
    elseif channel == "WHISPER" and target then
        C_ChatInfo.SendAddonMessage(prefix, message, "WHISPER", target)
    end
end

-- add a game request to a table
function add_request(opp_request, opp_request_roll, opp_request_max_roll)
    requests[opp_request] = {roll = opp_request_roll}
end

function textbox_start_roll()
    if textbox:GetText() ~= "" then -- if the textbox does NOT have NOTHING
        local textbox_str = textbox:GetText() -- get the string
        textbox_roll = tonumber(textbox_str) -- make it a number
        
        if textbox_roll > 999999 or textbox_roll == 1 then -- min and max rolls are invalid
            print("Please enter a valid roll.")
            textbox:SetFocus()
            
        else
            textbox:SetText("")
            textbox:ClearFocus()
            starting_roll = textbox_roll
            curr_opp = target_name
            wait_for_my_roll = true
            start_game() -- remember to end game if it's denied, times out or if we cancel our request!
        end
    else
        print("Please enter a roll.")
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
        scammer = chat_roller
        scam_alert("min_not_one", chat_roller, rolled_min_number)

    elseif in_game and chat_roller == UnitName("player") then -- if we're in game and the roller is myself
        if my_turn == false then -- if it's not our turn then we're scamming
            scam_alert("wrong_turn", chat_roller)
        elseif rolled_number == 1 then -- if we rolled 1 we lost
            print("You lost!")
            list_add()
            end_game()

        else     -- otherwise the game continues
            my_roll = rolled_number
            if wait_for_my_roll == true then
                send_addon_data("GameRequest:" .. my_roll .. ":" .. textbox_roll, "WHISPER", target_name) -- type, maxroll, myroll, target, maxroll again
                wait_for_my_roll = false
            end
            list_add()
            my_turn = false
        end

    elseif in_game and curr_opp == chat_roller then -- if we're in game and the roller is our opponent
        if my_turn then
            scam_alert("wrong_turn", curr_opp)

        else
            if rolled_max_number ~= my_roll then
                scam_alert("wrong_max", curr_opp, rolled_max_number, my_roll)

            elseif rolled_number == 1 then
                print("You won!")
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
            print("It's not your turn.")

        elseif my_turn == true then
            ChatFrame1EditBox:SetText(string.format("/roll %d", curr_opp_roll))
            ChatEdit_SendText(ChatFrame1EditBox)  
        end

    elseif in_game == false then -- if we're not in game
        if player_targeted then
            if next(requests) ~= nil then -- if there's something in the request list it takes prio
                for opp_request in pairs(requests) do
                    if opp_request == target_name then
                        curr_opp = opp_request
                        starting_roll = requests[opp_request].roll
                        start_game()
                    else
                        textbox_start_roll()
                    end
                end
            else
                textbox_start_roll()
            end

        elseif player_targeted == false then
            print("Please target a player to start a deathroll.")
        end
    end
end

function start_game() -- function should activate if a game starts
    print(string.format("Deathrolling %s!", curr_opp))
    ChatFrame1EditBox:SetText(string.format("/roll %d", starting_roll))-- sets the text
    ChatEdit_SendText(ChatFrame1EditBox)    -- sends it
    in_game = true 
    button:SetText("Roll!")
end

function end_game() -- should activate if a game ends; resets globals to default
    curr_opp = nil
    my_roll = 0
    curr_opp_roll = 0
    in_game = false
    my_turn = true
    button:SetText("Start Roll!")
end

function list_add()
    if chat_roller and rolled_number then
        if not rolls[chat_roller] then -- if roller is not in roll list
        rolls[chat_roller] = {} -- add them
        end
        table.insert(rolls[chat_roller], rolled_number) -- add rolls to existing name
    else
        print("[DR ERROR] List_add called with nil values!")
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
        print(string.format("%s's minimum roll was %d instead of 1. They are scamming someone!", scammer, value))
    elseif scam_type == "wrong_max" then
        print(string.format("%s rolled for %d instead of %d. They are scamming!", scammer, value, expected_roll))
    elseif scam_type == "wrong_turn" then
        print(string.format("%s rolled out of turn!", scammer))
    end
end

SLASH_DEATHROLL1 = "/dr"
SLASH_DEATHROLL2 = "/deathroll"
SlashCmdList["DEATHROLL"] = function(msg) -- msg is whatever player types after cmd
    starting_roll = tonumber(msg) -- convert to number

    if my_turn == false then
        print("It's not your turn.")

    elseif not starting_roll then  -- smartly checks if roll value is a number
        print("Please type a valid number to roll.")
        return

    elseif UnitIsPlayer("target") and not UnitIsUnit("target", "player") then -- if someone is targeted and it's not yourself then
        if my_turn == false then
            print("It's not your turn.")
        else
            target_name = UnitName("target")
            curr_opp = target_name
            start_game()
        end

    else
        print("Please target a player to roll.")
    end
end

-- commands!
SLASH_DEATHROLLBUTTON1 = "/dr button"
SLASH_DEATHROLLBUTTON2 = "/deathroll button"
SLASH_DEATHROLLBUTTON3 = "/drbutton"
SLASH_DEATHROLLBUTTON4 = "/deathrollbutton"
SlashCmdList["DEATHROLLBUTTON"] = function() -- hide and show the button
    if parentFrame:IsShown() then
        parentFrame:Hide()
    else parentFrame:Show()
    end
end

SLASH_DEATHROLLCANCEL1 = "/dr cancel"
SlashCmdList["DEATHROLLCANCEL"] = function()
    if in_game then
        print("Deathroll canceled.")
        end_game()
    else
        print("You're not in a deathroll right now.")
    end
end

SLASH_DEATHROLLREQUEST1 = "/dr requests"
SLASH_DEATHROLLREQUEST2 = "/dr request"
SlashCmdList["DEATHROLLDREQUEST"] = function()

end

SLASH_DEATHROLLDEBUG1 = "/drd"
SlashCmdList["DEATHROLLDEBUG"] = function()
    print("===== Death Roll Debug =====")
    print("Target Name: " .. tostring(target_name))
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