local smartWalkDirs = {}
local smartWalkDir = nil
local walkEvent = nil
local lastTurn = 0
local nextWalkDir = nil
local lastCancelWalkTime = 0


local keys = {
    { "Up",      North },
    { "Right",   East },
    { "Down",    South },
    { "Left",    West },
    { "Numpad8", North },
    { "Numpad9", NorthEast },
    { "Numpad6", East },
    { "Numpad3", SouthEast },
    { "Numpad2", South },
    { "Numpad1", SouthWest },
    { "Numpad4", West },
    { "Numpad7", NorthWest },
}

local turnKeys = {
    { "Control+Up",    North },
    { "Control+Right", East },
    { "Control+Down",  South },
    { "Control+Left",  West },
}

-- PokeVerse: the letter keys are Keybinds (Settings > Controls), only bound with chat off; the
-- arrows, numpad and Ctrl+arrows above stay fixed. Diagonals have no default key.
local KEYBIND_CATEGORY = 'Movement'

local walkKeybinds = {
    { 'Walk north',      North,     'W' },
    { 'Walk east',       East,      'D' },
    { 'Walk south',      South,     'S' },
    { 'Walk west',       West,      'A' },
    { 'Walk north-east', NorthEast, '' },
    { 'Walk north-west', NorthWest, '' },
    { 'Walk south-east', SouthEast, '' },
    { 'Walk south-west', SouthWest, '' },
}

local turnKeybinds = {
    { 'Turn north', North, 'Ctrl+W' },
    { 'Turn east',  East,  'Ctrl+D' },
    { 'Turn south', South, 'Ctrl+S' },
    { 'Turn west',  West,  'Ctrl+A' },
}

local floorKeybinds = {
    { 'Fly up a floor (/up)',     '/up',   'Q' },
    { 'Fly down a floor (/down)', '/down', 'Z' },
}

local function chatOffKey(key)
    return { [CHAT_MODE.ON] = '', [CHAT_MODE.OFF] = key }
end

WalkController = Controller:new()

--- Stops the smart walking process.
local function stopSmartWalk()
    smartWalkDirs = {}
    smartWalkDir = nil
end

--- Cancels the current walk event if active.
local function cancelWalkEvent()
    if walkEvent then
        removeEvent(walkEvent)
        walkEvent = nil
    end
    nextWalkDir = nil
end

--- Generalized floor change check.
local function canChangeFloor(pos, deltaZ)
    if deltaZ == 0 then
        return false
    end
    local player = g_game.getLocalPlayer()
    if not player then
        return false
    end

    local toPos = {x = pos.x, y = pos.y, z = pos.z + deltaZ}
    local toTile = g_map.getTile(toPos)
    if not toTile then
        return false
    end

    if deltaZ > 0 then
        -- Going DOWN
        return toTile:isWalkable() and (toTile:hasElevation(3) or toTile:hasFloorChange())
    end
    -- deltaZ < 0
    -- Going UP: check if current tile has elevation (stairs to climb) AND destination is walkable
    local fromTile = g_map.getTile(player:getPosition())
    return fromTile and fromTile:hasElevation(3) and toTile:isWalkable()
end

--- Makes the player walk in the given direction.
local function walk(dir)
    local player = g_game.getLocalPlayer()
    if not player or g_game.isDead() or player:isDead() then
        return
    end

    if player:isWalkLocked() then
        nextWalkDir = nil
        return
    end

    if g_game.isFollowing() then
        g_game.cancelFollow()
    end

    local isAutoWalking = player:isAutoWalking()
    if isAutoWalking or player:isServerWalking() then
        g_game.stop()
        if isAutoWalking then
            player:stopAutoWalk()
        end
        player:lockWalk(player:getStepDuration() + 50)
        return
    end

    if not player:canWalk() then
        nextWalkDir = dir
        return
    end

    nextWalkDir = nil

    if g_game.getFeature(GameAllowPreWalk) then
        local toPos = Position.translatedToDirection(player:getPosition(), dir)
        local toTile = g_map.getTile(toPos)
        if not toTile or not toTile:isWalkable() then
            if not canChangeFloor(toPos, 1) and not canChangeFloor(toPos, -1) then
                return false
            end
        else
            player:preWalk(dir)
        end
    end

    modules.game_interface.lastManualWalk = g_clock.millis()
    g_game.walk(dir)
    return true
end

--- Adds a walk event with an optional delay.
local function addWalkEvent(dir, delay)
    if g_clock.millis() - lastCancelWalkTime > 20 then
        cancelWalkEvent()
        lastCancelWalkTime = g_clock.millis()
    end

    local action = function()
        if g_keyboard.getModifiers() == KeyboardNoModifier then
            walk(smartWalkDir or dir)
        end
    end

    walkEvent = delay ~= nil and delay > 0 and scheduleEvent(action, delay) or addEvent(action)
end

--- Initiates a smart walk in the given direction.
function smartWalk(dir)
    addWalkEvent(dir)
end

--- Changes the current walking direction.
local function changeWalkDir(dir, pop)
    -- Remove all occurrences of the specified direction
    while table.removevalue(smartWalkDirs, dir) do end

    if pop then
        if #smartWalkDirs == 0 then
            stopSmartWalk()
            return
        end
    else
        table.insert(smartWalkDirs, 1, dir)
    end

    smartWalkDir = smartWalkDirs[1]

    if modules.client_options.getOption('smartWalk') and #smartWalkDirs > 1 then
        local diagonalMap = {
            [North] = { [West] = NorthWest, [East] = NorthEast },
            [South] = { [West] = SouthWest, [East] = SouthEast },
            [West]  = { [North] = NorthWest, [South] = SouthWest },
            [East]  = { [North] = NorthEast, [South] = SouthEast }
        }

        for _, d in ipairs(smartWalkDirs) do
            if diagonalMap[smartWalkDir] and diagonalMap[smartWalkDir][d] then
                smartWalkDir = diagonalMap[smartWalkDir][d]
                break
            end
        end
    end
end

--- Handles turning the player.
local function turn(dir, repeated)
    local player = g_game.getLocalPlayer()
    if player:isWalking() and player:getDirection() == dir then
        return
    end

    cancelWalkEvent()

    local TURN_DELAY_REPEATED = 150
    local TURN_DELAY_DEFAULT = 50

    local delay = repeated and TURN_DELAY_REPEATED or TURN_DELAY_DEFAULT

    if lastTurn + delay < g_clock.millis() then
        g_game.turn(dir)
        changeWalkDir(dir)
        lastTurn = g_clock.millis()
        player:lockWalk(g_settings.getNumber("walkTurnDelay"))
    end
end

--- Binds movement keys to their respective directions.
local function bindKeys()
    modules.game_interface.getRootPanel():setAutoRepeatDelay(200)

    for _, keyDir in ipairs(keys) do bindWalkKey(keyDir[1], keyDir[2]) end
    for _, keyDir in ipairs(turnKeys) do bindTurnKey(keyDir[1], keyDir[2]) end
end

local function bindKeybinds()
    local gameRootPanel = modules.game_interface.getRootPanel()

    for _, entry in ipairs(walkKeybinds) do
        local dir = entry[2]
        Keybind.new(KEYBIND_CATEGORY, entry[1], chatOffKey(entry[3]), '')
        Keybind.bind(KEYBIND_CATEGORY, entry[1], {
            { type = KEY_DOWN, alone = true, callback = function(_, keyCode)
                g_window.setKeyDelay(keyCode, 1)
                changeWalkDir(dir)
            end },
            { type = KEY_UP, alone = true, callback = function(_, keyCode)
                g_window.setKeyDelay(keyCode, 30)
                changeWalkDir(dir, true)
            end },
            { type = KEY_PRESS, callback = function() smartWalk(dir) end },
        }, gameRootPanel)
    end

    for _, entry in ipairs(turnKeybinds) do
        local dir = entry[2]
        Keybind.new(KEYBIND_CATEGORY, entry[1], chatOffKey(entry[3]), '')
        Keybind.bind(KEYBIND_CATEGORY, entry[1], {
            { type = KEY_DOWN, callback = function() turn(dir, false) end },
            { type = KEY_PRESS, callback = function() turn(dir, true) end },
            { type = KEY_UP, callback = function()
                local player = g_game.getLocalPlayer()
                if player then player:lockWalk(200) end
            end },
        }, gameRootPanel)
    end

    for _, entry in ipairs(floorKeybinds) do
        local words = entry[2]
        Keybind.new(KEYBIND_CATEGORY, entry[1], chatOffKey(entry[3]), '')
        Keybind.bind(KEYBIND_CATEGORY, entry[1], {
            { type = KEY_DOWN, callback = function()
                if g_game.isOnline() then g_game.talk(words) end
            end },
        }, gameRootPanel)
    end
end

local function unbindKeybinds()
    for _, list in ipairs({ walkKeybinds, turnKeybinds, floorKeybinds }) do
        for _, entry in ipairs(list) do Keybind.delete(KEYBIND_CATEGORY, entry[1]) end
    end
end

local function unbindKeys()
    for _, keyDir in ipairs(keys) do unbindWalkKey(keyDir[1]) end
    for _, keyDir in ipairs(turnKeys) do unbindTurnKey(keyDir[1]) end
end

--- Handles player teleportation events.
local function onTeleport(player, newPos, oldPos)
    if not newPos or not oldPos then
        return
    end

    local offsetX, offsetY, offsetZ =
        Position.offsetX(newPos, oldPos), Position.offsetY(newPos, oldPos), Position.offsetZ(newPos, oldPos)

    local TELEPORT_DELAY = g_settings.getNumber("walkTeleportDelay")
    local STAIRS_DELAY = g_settings.getNumber("walkStairsDelay")

    local delay = (offsetX >= 3 or offsetY >= 3 or offsetZ >= 2) and TELEPORT_DELAY or STAIRS_DELAY
    player:lockWalk(delay)
end

--- Handles the end of a walking event.
local function onWalkFinish(player)
    if nextWalkDir then
        if not g_game.getFeature(GameAllowPreWalk) then
            walk(nextWalkDir)
        else
            addWalkEvent(nextWalkDir, 50)
        end
    end
end

local function onAutoWalk(player)
end

--- Handles cancellation of a walking event.
local function onCancelWalk(player)
    player:lockWalk(50)
end

--- Initializes the WalkController.
function WalkController:onInit()
    bindKeys()
    bindKeybinds()
end

function WalkController:onTerminate()
    unbindKeys()
    unbindKeybinds()
end

--- Sets up game-related events for the WalkController.
function WalkController:onGameStart()
    self:registerEvents(g_game, {
        onGameStart = onGameStart,
        onTeleport = onTeleport,
        onAutoWalk = onAutoWalk
    })

    self:registerEvents(LocalPlayer, {
        onCancelWalk = onCancelWalk,
        onWalkFinish = onWalkFinish,
        onAutoWalk = onAutoWalk
    })

    modules.game_interface.getRootPanel().onFocusChange = stopSmartWalk
    modules.game_joystick.addOnJoystickMoveListener(function(dir) g_game.walk(dir) end)

    if not g_game.isOfficialTibia() then
        g_game.enableFeature(GameForceFirstAutoWalkStep)
    else
        g_game.disableFeature(GameForceFirstAutoWalkStep)
    end
end

--- Cleans up resources when the game ends.
function WalkController:onGameEnd()
    stopSmartWalk()
end

--- Utility functions for binding and unbinding keys.
-- Binding a key again replaces its handlers; stacked handlers walk once per handler.
function bindWalkKey(key, dir)
    local gameRootPanel = modules.game_interface.getRootPanel()
    unbindWalkKey(key)

    g_keyboard.bindKeyDown(key, function()
        g_keyboard.setKeyDelay(key, 1)
        changeWalkDir(dir)
    end, gameRootPanel, true)

    g_keyboard.bindKeyUp(key, function()
        g_keyboard.setKeyDelay(key, 30)
        changeWalkDir(dir, true)
    end, gameRootPanel, true)

    g_keyboard.bindKeyPress(key, function() smartWalk(dir) end, gameRootPanel)
end

function bindTurnKey(key, dir)
    local gameRootPanel = modules.game_interface.getRootPanel()

    g_keyboard.bindKeyDown(key, function() turn(dir, false) end, gameRootPanel)
    g_keyboard.bindKeyPress(key, function() turn(dir, true) end, gameRootPanel)
    g_keyboard.bindKeyUp(key, function()
        local player = g_game.getLocalPlayer()
        if player then player:lockWalk(200) end
    end, gameRootPanel)
end

function unbindWalkKey(key)
    local gameRootPanel = modules.game_interface.getRootPanel()
    g_keyboard.unbindKeyDown(key, gameRootPanel)
    g_keyboard.unbindKeyUp(key, gameRootPanel)
    g_keyboard.unbindKeyPress(key, gameRootPanel)
end

function unbindTurnKey(key)
    local gameRootPanel = modules.game_interface.getRootPanel()
    g_keyboard.unbindKeyDown(key, gameRootPanel)
    g_keyboard.unbindKeyPress(key, gameRootPanel)
    g_keyboard.unbindKeyUp(key, gameRootPanel)
end
