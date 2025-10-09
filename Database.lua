local DRU = DeathRollUnlocked

function DRU.GetGameState()
    DRUDB.games = DRUDB.games or {}
    local curr_game = DRUDB.games[#DRUDB.games]
    local last_roll = 0

    if curr_game ~= nil then
        last_roll = curr_game.rolls[#curr_game.rolls][3]
    end

    if curr_game == nil or last_roll == 1 or last_roll == nil or last_roll == 0 then -- setting curr_wager to 0 here fucks shit up, let's see if it makes for any bugs down the line
        DRU.gamestate.in_game = false
        DRU.gamestate.curr_game = nil
        DRU.gamestate.my_turn = false
        DRU.gamestate.curr_opp = nil    
        DRU.gamestate.last_roller = nil
        DRU.gamestate.last_roll = 0
    else
        DRU.gamestate.in_game = true
        DRU.gamestate.curr_game = curr_game
        DRU.gamestate.curr_opp = curr_game.info.opp
        DRU.gamestate.last_roller = curr_game.rolls[#curr_game.rolls][2]
        DRU.gamestate.last_roll = last_roll
        DRU.gamestate.curr_wager = curr_game.info.wager
        if curr_game.rolls[#curr_game.rolls][2] == DRU.me then
            DRU.gamestate.my_turn = false
        else
            DRU.gamestate.my_turn = true
        end
    end
end

function DRU.HistoryChange(type, player, roll, max_roll, time, result, opp, wager) -- adds rolls to ongoing games or adds requests (can also cancel roll)
    DRUDB.games = DRUDB.games or {} -- extra checks
    DRUDB.global_stats = DRUDB.global_stats or {}
    DRUDB.requests = DRUDB.requests or {}
    local _, curr_game = DRU.GameCheck()
    if type == nil then
        return
        
    elseif type == "NewRequest" then -- always from another player
        DRUDB.requests[player] = {info = {opp = player, result = nil, wager = wager}, rolls = {{time, player, roll, max_roll}}}
    
    elseif type == "MoveRequest" then
        table.insert(DRUDB.games, DRUDB.requests[player])
    
    elseif type == "RemoveRequest" then
        DRUDB.requests[player] = nil

    elseif type == "NewGame" then -- always started by us
        table.insert(DRUDB.games, {info = {opp = opp, result = nil, wager = wager}, rolls = {{time, player, roll, max_roll}}})

    elseif type == "Roll" then
        if curr_game == nil then
            return
        else
            table.insert(curr_game.rolls, {time, player, roll, max_roll})
        end

    elseif type == "EndGame" then
        if DRUDB.global_stats.total_gold == nil then DRUDB.global_stats.total_gold = 0 end
        if curr_game == nil then -- i hate need check nil
            return
        
        elseif result == "Win" then
            if DRUDB.global_stats.total_wins == nil then DRUDB.global_stats.total_wins = 0 end -- is this nessecary?
            DRUDB.global_stats["total_wins"] = DRUDB.global_stats["total_wins"] + 1
            DRUDB.global_stats["total_gold"] = DRUDB.global_stats["total_gold"] + wager
            curr_game.info.result = "Win"

        elseif result == "Loss" then
            if DRUDB.global_stats.total_losses == nil then DRUDB.global_stats.total_losses = 0 end
            DRUDB.global_stats["total_losses"] = DRUDB.global_stats["total_losses"] + 1
            DRUDB.global_stats["total_gold"] = DRUDB.global_stats["total_gold"] - wager
            curr_game.info.result = "Loss"
            
        elseif result == "Cancel" then -- if it's a cancellation the game is removed
            table.remove(DRUDB.games, #DRUDB.games) -- if i don't do it like this it doesn't work and idk why lol
        end
        table.insert(curr_game.rolls, {time, player, roll, max_roll}) -- if it's ending the game we always add the roll
        DRU.GetGameState() -- when a game ends we need to update gamestate
    end
end

function DRU.RequestCheck(target_name) -- checks if target selected is in request list, and gives back all bool, time, player, roll, maxroll
    if not DRUDB.requests or next(DRUDB.requests) == nil then
        return false, 0, nil, 0, 0 
    else 
        for player in pairs(DRUDB.requests) do
            if player == target_name then
                return true, unpack(DRUDB.requests[target_name].rolls[1])
            else
                return false, 0, nil, 0, 0
            end
        end
    end
end

function DRU.GameCheck() -- returns in_game, curr_game table
    local _, last_roll = DRU.GetRoll()
    if last_roll == 1 or last_roll == nil then
        return false, nil
    else
        return true, DRUDB.games[#DRUDB.games]
    end
end

function DRU.TurnCheck() -- returns my_turn
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

function DRU.GetRollIndex()
    DRUDB.games = DRUDB.games or {}
    local curr_game = DRUDB.games[#DRUDB.games]
    if curr_game and curr_game.rolls then
        return #curr_game.rolls
    end
end

function DRU.GetRoll(player) -- returns roller, roll, max_roll
    DRUDB.games = DRUDB.games or {}
    local curr_game = DRUDB.games[#DRUDB.games]
    if curr_game == nil then
        return nil, nil, nil
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

function DRU.GetCurrOpp() -- returns curr_opp
    local curr_game = DRUDB.games[#DRUDB.games]
    if curr_game == nil then
        return nil
    else
        local curr_opp = curr_game.info.opp
        return curr_opp
    end
end

function DRU.GetLastGame() -- returns most recent game, ongoing or not
    return DRUDB.games[#DRUDB.games]
end

SLASH_DEATHROLLGAMES1 = "/drgame"
SLASH_DEATHROLLGAMES2 = "/drgames"
SlashCmdList["DEATHROLLGAMES"] = function()
    if next(DRUDB.requests) ~= nil then
        for player, rolls, _ in pairs(DRUDB.requests) do
            print(string.format("|cffffff00DRU:|r %s started from %d and rolled %d.\n", player, rolls[4], rolls[3]))
        end
    else
        print("|cffffff00DRU:|r You have no deathroll requests right now.")
    end
end

SLASH_DEATHROLLCLEAR1 = "/drclear"
SlashCmdList["DEATHROLLCLEAR"] = function()
    table.wipe(DRUDB.games)
    DRUDB.global_stats["total_wins"] = 0
    DRUDB.global_stats["total_losses"] = 0
    print("|cffffff00DRU:|r Game history cleared.")
end

SLASH_DEATHROLLWIPE1 = "/drwipe"
SlashCmdList["DEATHROLLWIPE"] = function()
    table.wipe(DRUDB)
    ReloadUI()
end