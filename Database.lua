-- this file manages all of the database storing, parsing and pulling
-- some side effects like UI updates are also called here, because they have to happen after the DB has been updated.

DeathRollUnlocked = DeathRollUnlocked or {}
local DRU = DeathRollUnlocked
local ST -- settings
local GS
local g = "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t"

function DRU.InitDB()
    if not DRUDB or (DRUDB == nil) or (type(DRUDB) ~= "table") then
        DRUDB = {}
    end
    DRUDB.global_stats = DRUDB.global_stats or
    {total_wins = 0, total_losses = 0, total_gold = 0, worst_roll = 0, two_streak = 0, win_streak = 0, loss_streak = 0, most_won = 0, most_lost = 0}
    DRUDB.games = DRUDB.games or {} -- match history
    DRUDB.requests = DRUDB.requests or {} -- pending requests
    DRUDB.pending_additions = DRUDB.pending_additions or {} -- games to be added after we are done with our current game (someone else tried to roll us mid-game and they lost immediately)
    ST = DRUDB.settings
    GS = DRU.gamestate
end

-- the gamestate (GS) is always decided by the information available in DRUDB 
-- the gamestate is updated/checked on load, before AND after every roll, and always after a game ends in any way.
-- this way the core logic can easily rely on the gamestate table and not have to worry about DRUDB.
function DRU.GetGameState()
    local curr_game = DRUDB.games[#DRUDB.games]

    if not DRU.IsInGame() then
        DRU.gamestate.in_game = false
        DRU.gamestate.curr_game = nil
        DRU.gamestate.my_turn = false
        DRU.gamestate.curr_opp = nil
        DRU.gamestate.last_roller = nil
        DRU.gamestate.last_roll = nil
        DRU.gamestate.my_wager = nil
        DRU.gamestate.opp_wager = nil
    else
        DRU.gamestate.in_game = true
        DRU.gamestate.curr_game = curr_game
        DRU.gamestate.curr_opp = curr_game.info["opp"] and curr_game.info.opp or nil
        DRU.gamestate.last_roller = curr_game.rolls[1] and curr_game.rolls[#curr_game.rolls][2] or nil
        DRU.gamestate.last_roll = curr_game.rolls[1] and curr_game.rolls[#curr_game.rolls][3] or nil
        DRU.gamestate.my_wager = curr_game.info["my_wager"] and curr_game.info.my_wager or 0
        DRU.gamestate.opp_wager = curr_game.info["my_wager"] and curr_game.info.opp_wager or 0
        if GS.last_roller == DRU.me then
            DRU.gamestate.my_turn = false
        else
            DRU.gamestate.my_turn = true
        end
    end
end

function DRU.HistoryChange(type, player, roll, max_roll, time, result, opp, wager, is_chat_roll) -- adds rolls to ongoing games or adds requests (can also cancel roll)
    local curr_game = DRUDB.games[#DRUDB.games]
    local is_cancelled = false
    if type == nil then
        return
        
    elseif type == "NewRequest" then -- always from another player
        DRUDB.requests[player] = {info = {opp = player, result = nil, my_wager = wager, opp_wager = wager, id = DRU.GenerateGameID()}, rolls = {{time, player, roll, max_roll}}, is_chat_roll = is_chat_roll} -- nested table for smooth & easy data transfer
        if DRU.random_rolls[player] then DRU.random_rolls[player] = nil end
    
    elseif type == "MoveRequest" then
        table.insert(DRUDB.games, DRUDB.requests[player])
    
    elseif type == "RemoveRequest" then
        DRUDB.requests[player] = nil

    elseif type == "NewGame" then -- always started by us
        table.insert(DRUDB.games, {info = {opp = opp, result = nil, my_wager = wager, opp_wager = wager, id = DRU.GenerateGameID()}, rolls = {}})

    elseif type == "Roll" then
        if curr_game ~= nil then
            table.insert(curr_game.rolls, {time, player, roll, max_roll})
        end

    -- the FastLoss can use curr_game because a new game has already been created by ParseRoll. FastWin cannot do the same because it has to create a new game on the spot.
    elseif type == "FastLoss" then -- special case for when our very first roll is immediately 1: otherwise the roll is added twice, because we have to start and end game.
        curr_game.info.result = "Loss"
        curr_game.rolls = {{time, player, roll, max_roll}}
        curr_game.info.opp_wager = 0
        -- my_wager is already added in attempt_game_start!
        DRUDB.global_stats["total_losses"] = DRUDB.global_stats["total_losses"] + 1
        DRUDB.global_stats["total_gold"] = DRUDB.global_stats["total_gold"] - curr_game.info.my_wager
        DRU.EndGame()

    elseif type == "FastWin" then -- special case for when someone rolls us and immediately rolls 1
        if GS.in_game then table.insert(DRUDB.pending_additions, {type, player, roll, max_roll, time, result, opp, wager, is_chat_roll}) return end -- save for after we're done
        table.insert(DRUDB.games, {info = {opp = opp, result = "Win", my_wager = 0, opp_wager = wager, id = DRU.GenerateGameID()}, rolls = {{time, player, roll, max_roll}}})
        DRUDB.global_stats["total_wins"] = DRUDB.global_stats["total_wins"] + 1
        DRUDB.global_stats["total_gold"] = DRUDB.global_stats["total_gold"] + DRUDB.games[#DRUDB.games].info.opp_wager
        DRUDB.games[#DRUDB.games].info.result = "Win"
        DRU.EndGame()

    elseif type == "EndGame" then
        if curr_game == nil then -- i hate need check nil
            return
        
        elseif result == "Win" then
            DRUDB.global_stats["total_wins"] = DRUDB.global_stats["total_wins"] + 1
            DRUDB.global_stats["total_gold"] = DRUDB.global_stats["total_gold"] + curr_game.info.opp_wager
            curr_game.info.result = "Win"

        elseif result == "Loss" then
            DRUDB.global_stats["total_losses"] = DRUDB.global_stats["total_losses"] + 1
            DRUDB.global_stats["total_gold"] = DRUDB.global_stats["total_gold"] - curr_game.info.my_wager
            curr_game.info.result = "Loss"
            
        elseif result == "Cancel" then -- if it's a cancellation the game is removed
            table.remove(DRUDB.games, #DRUDB.games)
            is_cancelled = true
        end

        if result ~= "Cancel" then table.insert(curr_game.rolls, {time, player, roll, max_roll}) end -- if it's ending the game we always add the roll

        DRU.EndGame(is_cancelled)
        DRU.AddPendingAdditions()
    end
end

function DRU.EndGame(is_cancelled)
    DRU.GetGameState() -- when a game ends we need to update gamestate for core.lua
    
    if not is_cancelled then -- checks for stats
        DRU.TwoStreakCheck()
        DRU.GameStreakCheck()
        DRU.BigWagerCheck()
    end

    DRU.UpdateCurrPage() -- match history GUI update
    DRU.UpdateStats() -- this is for gui. TODO: make clear in the function that it's gui related
    DRU.UpdatePageUI()
end

function DRU.RequestCheck(target_name) -- checks if target selected is in request list, and gives back all bool, time, player, roll, maxroll, wager, is_chat_roll
    if (not DRUDB.requests) or (next(DRUDB.requests) == nil) then
        return false
    else
        for player in pairs(DRUDB.requests) do
            if player == target_name then
                local time, name, roll, max_roll = unpack(DRUDB.requests[target_name].rolls[1]) -- unpack is a garbage function and can't be used in the middle of a return
                local is_chat_roll = DRUDB.requests[target_name].is_chat_roll
                return true, time, name, roll, max_roll, DRUDB.requests[target_name].info.opp_wager, is_chat_roll
            end
        end
        return false
    end
end

function DRU.AddPendingAdditions()
    for i, game in pairs(DRUDB.pending_additions) do
        DRU.HistoryChange(unpack(game))
        DRUDB.pending_additions[i] = nil
    end
end

function DRU.AddWager(wager, player)
    if DRUDB.games[#DRUDB.games] == nil then
        return
    else
        DRUDB.games[#DRUDB.games].info[player] = wager
    end
end

function DRU.TurnCheck() -- returns my_turn
    local last_roller = DRU.GetRoll()

    if not DRU.IsInGame() then
        return nil
    else
        if last_roller ~= DRU.me then
            return true
        else
            return false
        end
    end
end

function DRU.GetRollIndex()
    local curr_game = DRUDB.games[#DRUDB.games]
    if curr_game and curr_game.rolls then
        return #curr_game.rolls
    end
end

function DRU.GetRoll(player) -- returns roller, roll, max_roll
    local curr_game = DRUDB.games[#DRUDB.games]
    if not DRU.IsInGame() then
        return nil, nil, nil
    end

    if player == nil then -- if no player specified just get the most recent roll
        return curr_game.rolls[#curr_game.rolls][2], curr_game.rolls[#curr_game.rolls][3], curr_game.rolls[#curr_game.rolls][4]

    else -- otherwise check which of the last 2 rolls is the correct player CURRENTLY DOES NOT WORK AND NOT USED
        local last_2_games = {curr_game.rolls[#curr_game.rolls], curr_game.rolls[#curr_game.rolls -1]}
        for _, data in ipairs{last_2_games}  do
            if data then
                local time, roller, roll, max_roll = unpack(data)
                    if roller == player then
                        return roller, roll, max_roll
                    end
            end
        end
    end
end

function DRU.GetMatchHistoryPage(page_num, page_len, opp_search)
    local page_start = #DRUDB.games - (page_num * page_len) -- am i secretly a math genius?
    local page_end = page_start - page_len
    if page_end < 1 then page_end = 1 end
    local my_games = {}

    -- for <var> = <start>, <end>, <step> do | numeric for loop to get me the indexes of recent games
    -- backwards numeric loop to go through our game history in reverse so we can return an ordered table
    for i = page_start, page_end, -1 do
        local id = DRUDB.games[i].info.id
        local opp = DRUDB.games[i].info.opp
        local result = DRUDB.games[i].info.result
        -- local is_chat_roll = DRUDB.games[i]["is_chat_roll"] or false -- TODO: add "assumed wager" notifier if is_chat_roll
        local gold_str = ""
        local skip = false
        
        if result == "Win" then
            gold_str = ("+"..DRUDB.games[i].info.opp_wager..g)
        elseif result == "Loss" then
            gold_str = (tostring(-DRUDB.games[i].info.my_wager)..g)
        elseif result == nil then -- the game is not yet finished and we shouldn't display it
            skip = true
        end

        if not skip then
            if (opp_search == "") or (string.find(string.lower(opp), string.lower(opp_search))) then
                table.insert(my_games, {id, opp, result, gold_str})
            end
        end
    end

    return my_games
end

function DRU.GetGameByID(id) -- a safe function that returns a game based on id.
    for i, game in ipairs(DRUDB.games) do
        if game.info.id == id then
            return game
        end
    end
    if DRU.DEBUG then print(string.format("Game %d not found!", id)) end
end

function DRU.GetTotalGameAmount()
    return #DRUDB.games
end

function DRU.GetCurrOpp() -- returns curr_opp
    local curr_game = DRUDB.games[#DRUDB.games]
    if not DRU.IsInGame() then
        return nil

    else
        local last_roll = curr_game.rolls[#curr_game.rolls][3]
        if last_roll ~= 1 then
            local curr_opp = curr_game.info.opp
            return curr_opp
        else
            return nil
        end
    end
end

function DRU.GetLastGame() -- returns most recent game, ongoing or not
    return DRUDB.games[#DRUDB.games]
end

function DRU.GetCurrOppWager()
    local curr_game = DRUDB.games[#DRUDB.games]
    local wager = curr_game.info.opp_wager

    return wager
end

function DRU.GetStats() -- returns all stats for the GUI
    local wins = DRUDB.global_stats["total_wins"]
    local losses = DRUDB.global_stats["total_losses"]
    local total = wins + losses
    local gold = DRUDB.global_stats["total_gold"]
    local worst_roll = DRUDB.global_stats["worst_roll"]
    local win_rate_str = ""
    local two_streak = DRUDB.global_stats["two_streak"]
    local win_streak = DRUDB.global_stats["win_streak"]
    local loss_streak = DRUDB.global_stats["loss_streak"]
    local most_won = DRUDB.global_stats["most_won"]
    local most_lost = DRUDB.global_stats["most_lost"]
    
    if total > 0 then
        win_rate_str = string.format("%.2f%%", (wins / (wins + losses) * 100))
    else
        win_rate_str = "None"
    end
    
    if worst_roll == 0 then -- this is kinda ass but ok
        worst_roll = "None"
    else
        local temp_roll = worst_roll
        worst_roll = string.format("1 out of %d.", temp_roll, temp_roll)
    end

    return total, win_rate_str, wins, losses, gold, worst_roll, two_streak, win_streak, loss_streak, most_won, most_lost
end

function DRU.TwoStreakCheck() -- sees if there's a long streak of 2 rolls
    local last_game = DRUDB.games[#DRUDB.games]
    if not last_game then return end
    
    local streak = 0
    for _, roll in ipairs(last_game.rolls) do
        if roll[3] == 2 then
            streak = streak + 1
        end
    end
    if streak > DRUDB.global_stats["two_streak"] then
        DRUDB.global_stats["two_streak"] = streak
    end
end

function DRU.LuckCheck(roll, max_roll, roller) -- checks if roll is the unluckiest roll ever
    if roller == DRU.me then
        if roll == 1 then
            if max_roll > DRUDB.global_stats["worst_roll"] then
                DRUDB.global_stats["worst_roll"] = max_roll
            end
        end
    end
end

function DRU.GameStreakCheck() -- goes through most recent games to see if you're on a win/loss streak
    local streak_type -- a win or a loss
    local streak = 0
    
    for i = #DRUDB.games, 1, -1 do
        local game = DRUDB.games[i]
        if i == #DRUDB.games then streak_type = game.info.result end

        if game.info.result == streak_type then
            streak = streak + 1
        else
            break
        end
    end
    
    local streak_key = (streak_type == "Loss") and "loss_streak" or "win_streak"
    if streak > DRUDB.global_stats[streak_key] then
        DRUDB.global_stats[streak_key] = streak
    end
end

function DRU.BigWagerCheck()
    local game = DRUDB.games[#DRUDB.games]
    if not game then return end

    local stats_key = (game.info.result == "Win") and "most_won" or "most_lost"
    local wager_key = (game.info.result == "Win") and "opp_wager" or "my_wager"

    if abs(game.info[wager_key]) > abs(DRUDB.global_stats[stats_key]) then
        DRUDB.global_stats[stats_key] = game.info[wager_key]
    end
end

function DRU.GenerateGameID()
    return DRUDB.global_stats["total_wins"] + DRUDB.global_stats["total_losses"] + 1
end

function DRU.WipeDB()
    table.wipe(DRUDB.games)
    table.wipe(DRUDB.requests)
    table.wipe(DRUDB.pending_additions)
    for i, stat in pairs(DRUDB.global_stats) do
        DRUDB.global_stats[i] = 0
    end
    DRU.UpdateMenu()
end

function DRU.IsInGame() -- no games, no rolls or last_roll == 1 means we are not in game.
    if DRUDB.games[#DRUDB.games] == nil then
        -- if DRU.DEBUG then print("curr_game is nil") end
        return false
    elseif #DRUDB.games[#DRUDB.games].rolls == 0 then -- this is only true if we have just started a new game
        -- if DRU.DEBUG then print("no rolls but there is a game started") end
        return true
    elseif DRUDB.games[#DRUDB.games].rolls[#DRUDB.games[#DRUDB.games].rolls][3] == 1 then -- wow this syntax is atrocious. "if last roll of last game == 1"
        -- if DRU.DEBUG then print("last_roll was 1") end
        return false
    else
        -- if DRU.DEBUG then print("its all good we are in game") end
        return true
    end
end

-- COMMANDS
SLASH_DEATHROLLTRY1 = "/drtry"
SlashCmdList["DEATHROLLTRY"] = function()
    if not DRU.DEBUG then
        DRU.print("That's a dev command buddy :)")
        return
    end

    local string = "5"
    print(tonumber(string) or 6)
end

SLASH_DEATHROLLGAMES1 = "/drgame"
SLASH_DEATHROLLGAMES2 = "/drgames"
SlashCmdList["DEATHROLLGAMES"] = function()
    if next(DRUDB.requests) ~= nil then
        for player, _ in pairs(DRUDB.requests) do
            local wager = DRUDB.requests[player].info["opp_wager"]
            local wager_str = DRU.G(wager)
            DRU.print(string.format("%s started from %d and rolled %d for %s.", player, DRUDB.requests[player].rolls[1][4], DRUDB.requests[player].rolls[1][3], wager_str))
        end
        DRU.print("Type /drclear to clear your deathroll request list.")
    else
        DRU.print("You have no deathroll requests right now.")
    end
end

SLASH_DEATHROLLCLEAR1 = "/drclear"
SlashCmdList["DEATHROLLCLEAR"] = function()
    if #DRUDB.requests == 0 then
        DRU.print("You have no deathroll requests right now.")
        return
    end

    for _, request in pairs(DRUDB.requests) do
        local name = request.info.opp
        DRU.SendAddonData("CancelGame", "WHISPER", name)
    end
    table.wipe(DRUDB.requests)
    DRU.print("Deathroll request list cleared.")
end

SLASH_DEATHROLLWIPE1 = "/drwipe"
SLASH_DEATHROLLWIPE2 = "/drw"
SlashCmdList["DEATHROLLWIPE"] = function()
    if not DRU.DEBUG then
        DRU.print("That's a dev command buddy :)")
        return
    end

    table.wipe(DRUDB)
    ReloadUI()
end

SLASH_DEATHROLLDEL1 = "/drdel"
SlashCmdList["DEATHROLLDEL"] = function(msg)
    if not DRU.DEBUG then
        DRU.print("That's a dev command buddy :)")
        return
    end

    local del_amount = tonumber(msg)

    for i = 1, del_amount do
        table.remove(DRUDB.games, i)
    end
    DRU.UpdateCurrPage()
    DRU.UpdatePageUI()
end
