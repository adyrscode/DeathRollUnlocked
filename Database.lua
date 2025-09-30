-- this file manages the database, game and roll history.

local DRU = DeathRollUnlocked

function DRU.HistoryChange(type, player, roll, max_roll, time, result, opp) -- adds rolls to ongoing games or adds requests (can also cancel roll)
    DRUDB.games = DRUDB.games or {} -- extra checks
    DRUDB.global_stats = DRUDB.global_stats or {}
    DRUDB.requests = DRUDB.requests or {}
    local _, curr_game = DRU.GameCheck()

    if type == "NewRequest" then
        DRUDB.requests = {[player] = {time, player, roll, max_roll}}
    
    elseif type == "MoveRequest" then
        table.insert(DRUDB.games, {stats = {player}, rolls = {DRUDB.requests[player]}})
    
    elseif type == "RemoveRequest" then
        DRUDB.requests[player] = nil

    elseif type == "NewGame" then
        table.insert(DRUDB.games, {stats = {opp}, rolls = {{time, player, roll, max_roll}}})

    elseif type == "Roll" then
        if curr_game == nil then
            return
        else
            table.insert(curr_game.rolls, {time, player, roll, max_roll})
        end

    elseif type == "EndGame" then
        if curr_game == nil then -- i hate need check nil
            return
        
        elseif result == "MyWin" then
            if DRUDB.global_stats.total_wins == nil then DRUDB.global_stats.total_wins = 0 end
            DRUDB.global_stats["total_wins"] = DRUDB.global_stats["total_wins"] + 1
            table.insert(curr_game.stats, "MyWin")

        elseif result == "MyLoss" then
            if DRUDB.global_stats.total_losses == nil then DRUDB.global_stats.total_losses = 0 end
            DRUDB.global_stats["total_losses"] = DRUDB.global_stats["total_losses"] + 1
            table.insert(curr_game.stats, "MyLoss")
            
        elseif result == "Cancel" then -- if it's a cancellation the game is removed
            table.remove(DRUDB.games, #DRUDB.games) -- if i don't do it like this it doesn't work and idk why lol
            return
        end
    table.insert(curr_game.rolls, {time, player, roll, max_roll}) -- if it's ending the game we always add the roll
    end
end

function DRU.RequestCheck(target_name) -- checks if target selected is in request list, and gives back all bool, time, player, roll, maxroll
    if not DRUDB.requests or next(DRUDB.requests) == nil then
        return false, 0, nil, 0, 0 
    else 
        for player in pairs(DRUDB.requests) do
            if player == target_name then
                return true, DRUDB.requests[target_name][1], target_name, DRUDB.requests[target_name][3], DRUDB.requests[target_name][4] -- 3 and 4 are indexes of the player's roll table
            else
                return false, 0, nil, 0, 0
            end
        end
    end
end

function DRU.GetRoll(player) -- get player's last roll. if no player is specified, get last roll.
    DRUDB.games = DRUDB.games or {}
    local curr_game = DRUDB.games[#DRUDB.games]
    local curr_opp = DRU.GetCurrOpp()
    if curr_game == nil then
        return nil
    end

    if player == nil then -- if no player specified just get the most recent roll
        return curr_game.rolls[#curr_game.rolls][2], curr_game.rolls[#curr_game.rolls][3], curr_game.rolls[#curr_game.rolls][4]

    else -- otherwise check which of the last 2 rolls is the correct player CURRENTLY DOES NOT WORK LOL
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

function DRU.TurnCheck()
    local in_game = DRU.GameCheck()
    local last_roller = DRU.GetRoll()
    if not in_game then
        return nil
    else
        if last_roller ~= DRU.me then
            return true
        else
            return false
        end
    end
end

function DRU.GameCheck() -- checks if last roll was 1 to determine if we are currently in a game or not. also returns game table
    local _, last_roll = DRU.GetRoll()
    if last_roll == 1 or last_roll == nil then
        return false, nil
    else
        return true, DRUDB.games[#DRUDB.games]
    end
end

function DRU.GetLastGame() -- returns most recent game, ongoing or not
    return DRUDB.games[#DRUDB.games]
end

function DRU.GetCurrOpp()
    local curr_game = DRUDB.games[#DRUDB.games]
    if curr_game == nil then
        return nil
    else
        local curr_opp = curr_game.stats[1]
        return curr_opp
    end
end

SLASH_DEATHROLLGAMES1 = "/drgame"
SLASH_DEATHROLLGAMES2 = "/drgames"
SlashCmdList["DEATHROLLGAMES"] = function()
    if next(DRUDB.requests) ~= nil then
        for player, rolls in pairs(DRUDB.requests) do
            print(string.format("[DRU] %s started from %d and rolled %d.\n", player, rolls[3], rolls[4]))
        end
    else
        print("[DRU] You have no deathroll requests right now.")
    end
end

SLASH_DEATHROLLCLEAR1 = "/drclear"
SlashCmdList["DEATHROLLCLEAR"] = function()
    table.wipe(DRUDB.games)
    DRUDB.global_stats["total_wins"] = 0
    DRUDB.global_stats["total_losses"] = 0
    print("[DRU] Game history cleared.")
end

SLASH_DEATHROLLWIPE1 = "/drwipe"
SlashCmdList["DEATHROLLWIPE"] = function()
    table.wipe(DRUDB)
    print("[DRU] DrDB has been wiped.")
end