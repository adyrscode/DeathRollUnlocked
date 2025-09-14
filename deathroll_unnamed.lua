SLASH_RELOADUI1 = "/rl" -- quick reload
SlashCmdList.RELOADUI = ReloadUI

-- functions
local start_game
local end_game
local textbox_send

-- lists of rolls and rollers
local targetname = nil -- name of our target
local recent_roll = -1 -- most recent roll
local recent_opponent = nil -- most recent roll sender
local rolls = {} -- list of all rolls
local rolled_number = 0
local rolled_max_number = 0

-- in game, current opponent and their rolls specifically 
local starting_roll = 0 -- our first roll?
local our_roll = 0 -- what we rolled
local in_game = false -- are we in a game right now
local my_turn = true -- is it our turn
local curr_opponent = nil -- opponent of current game
local curr_opponent_roll = 0 -- what did our opponent roll

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

-- create the textbox
local textbox = CreateFrame("EditBox", nil, parentFrame, "InputBoxTemplate")
textbox:SetSize(94, 30)                     -- width x height
textbox:SetPoint("CENTER", parentFrame, "CENTER", 3, -8)  -- position inside the frame
textbox:SetAutoFocus(false)                  -- don’t auto-focus when shown
textbox:SetNumeric(true) -- only allow numbers to be typed
textbox:SetScript("OnEnterPressed", function(self) -- if enter is pressed
    textbox_send()
end)

function textbox_send()
    if in_game == false and my_turn == true then
        if textbox:GetText() ~= "" then -- if the textbox does NOT have NOTHING
            curr_opponent = UnitName("target") -- the targeted player is our opponent
            local textbox_str = textbox:GetText() -- get the string
            textbox_roll = tonumber(textbox_str)
            ChatFrame1EditBox:SetText(string.format("/roll %d", textbox_roll))
            ChatEdit_SendText(ChatFrame1EditBox) 
            textbox:SetText("")
            textbox:ClearFocus()
            start_game()
        else
            textbox:SetFocus()
            print(string.format("Please enter a number to roll."))
            return
        end
    else
        textbox:ClearFocus()
        print("It's not your turn.")
    end
end

-- listening for system messages
local roll_listener = CreateFrame("Frame")
roll_listener:RegisterEvent("CHAT_MSG_SYSTEM")  -- system messages, like rolls

    roll_listener:SetScript("OnEvent", function(self, event, msg, sender, ...)
        local chat_roller, rolled_number_str, rolled_max_str = string.match(msg, "^(.-) rolls (%d+) %(1%-(%d+)%)$") -- is it a roll?
        rolled_number = tonumber(rolled_number_str) -- change roll to number
        rolled_max_number = tonumber(rolled_max_str) -- change roll to number
        
        if chat_roller ~= UnitName("player") and rolled_number ~= 1 then -- if it's not ourselves and they didn't roll 1
            recent_roll = rolled_number -- update recent rolls and opponent
            recent_opponent = chat_roller
        end

        if not rolls[chat_roller] then -- if opponent is not in roll list
            rolls[chat_roller] = {} -- add them
        end
        table.insert(rolls[chat_roller], rolled_number) -- add rolls to existing name
        
        if my_turn == false and chat_roller == UnitName("player") then -- if it's not our turn anymore AND the roll is ours, then our roll is the roll in chat
            if rolled_number == 1 then
                end_game()
                print("You lost!")
            else    
                our_roll = rolled_number
            end
        end

        if in_game then
            if curr_opponent == chat_roller and our_roll == rolled_max_number then -- if the roll is our opponenent's and its not a scam
                if rolled_number == 1 then -- did they roll 1?
                    print(string.format("%s lost!", curr_opponent))
                    end_game()
                else
                    curr_opponent_roll = rolled_number
                    my_turn = true
                    print("Your turn!")
                end

            elseif curr_opponent == chat_roller and rolled_max_number ~= our_roll then
                print(string.format("%s rolled for %d instead of %d. They are trying to scam you!", curr_opponent, rolled_max_number, our_roll)) 
            end 
        end

        if not in_game then -- if not in game and someone rolls our roll, notify us.
            return
        end
    end)

function start_game() -- function should activate if a game starts
    print(string.format("Deathrolling %s!", curr_opponent))
    ChatFrame1EditBox:SetText(string.format("/roll %d", starting_roll))-- sets the text
    ChatEdit_SendText(ChatFrame1EditBox)    -- sends it
    my_turn = false -- it's not our turn anymore; what did we roll?
    in_game = true 
    button:SetText("Roll!")
end

function end_game() -- should activate if a game ends (or is cancelled)
    curr_opponent = nil
    in_game = false
    my_turn = true
    button:SetText("Start Roll!")
end

-- button functionality
button:SetScript("OnClick", function(self, button)
    if in_game and my_turn then
        ChatFrame1EditBox:SetText(string.format("/roll %d", curr_opponent_roll))
        ChatEdit_SendText(ChatFrame1EditBox)  
        my_turn = false

    elseif not UnitIsPlayer("target") then -- if no player is targeted
        if textbox:GetText() ~= "" then -- but there's a number in the textbox
            print("Please select a player to roll.")
            
        elseif my_turn == false then
            print("It's not your turn.")
        elseif recent_roll == -1 and textbox:GetText() == "" then -- if there's no recent roll
            print("[DR+] No rolls detected. Please select a player or wait for a roll.")
        else
            print("U sure bro?")
            starting_roll = recent_roll
            curr_opponent = recent_opponent
            start_game()
        end

    elseif UnitIsPlayer("target") and not UnitIsUnit("target", "player") then -- if a player is targeted
        targetname = UnitName("target")
        if recent_opponent == targetname then -- if the target is the same as the most recent opponent
            starting_roll = recent_roll
            curr_opponent = recent_opponent
            start_game()
        elseif my_turn == false then
            print("It's not your turn.")
        else
            textbox_send()        
        end 
    end
end)

-- commands!
SLASH_DEATHROLLBUTTON1 = "/drbutton"
SLASH_DEATHROLLBUTTON2 = "/deathrollbutton"
SlashCmdList["DEATHROLLBUTTON"] = function() -- hide and show the button
    if parentFrame:IsShown() then
        parentFrame:Hide()
    else parentFrame:Show()
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
            targetname = UnitName("target")
            curr_opponent = targetname
            start_game()
        end

    else
        print("Please target a player to roll.")
    end
end

SLASH_DEATHROLLCANCEL1 = "/drcancel"
SlashCmdList["DEATHROLLCANCEL"] = function()
    if in_game then
        print("Deathroll canceled.")
        end_game()
    else
        print("You're not in a deathroll right now.")
    end
end