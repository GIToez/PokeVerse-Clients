-- Constants
local UPDATE_INTERVAL = 1
local TIME_DELTA = 1440 * UPDATE_INTERVAL / 3600
local POKEVERSE_MINUTE_PER_SECOND = 2.5

local LIGHT_STATES = {}
LIGHT_STATES.DAY = 0
LIGHT_STATES.NIGHT = 1
LIGHT_STATES.SUNSET = 3
LIGHT_STATES.SUNRISE = 4

local SUNSET = 1305
local SUNRISE = 430

-- Vars
local window, time, timeNow, lightState, lightStateImage, event
local enabled = true

-- Methods
local function updateLight(state)
    if (state ~= lightState) then
        lightState = state
        if (lightState == LIGHT_STATES.SUNSET) then
            lightStateImage:setImageSource('/images/ui/clock-moon')
            lightStateImage:setTooltip(tr('Night'))
        else
            lightStateImage:setImageSource('/images/ui/clock-sun')
            lightStateImage:setTooltip(tr('Day'))
        end
    end
end

function setTime(worldTime)
    timeNow = worldTime

    if (worldTime >= SUNSET or worldTime < SUNRISE) then
        updateLight(LIGHT_STATES.SUNSET)
    else
        updateLight(LIGHT_STATES.SUNRISE)
    end

    local hours = 0
    while (worldTime > 60) do
        hours = hours + 1
        worldTime = worldTime - 60
    end

    time:setText(string.format("%02d:%02d", hours, worldTime))
end

function setDisplay(v)
    enabled = v
    window:setVisible(enabled and g_game.isOnline())
end

local function increaseMinute()
    if (not timeNow) then
        return
    end

    timeNow = timeNow + 1
    if (timeNow > 1440) then
        timeNow = timeNow - 1440
    end
    setTime(timeNow)
end

local function reset()
    removeEvent(event)
    event = nil

    timeNow = nil
    lightState = nil
end

local function fitWidth()
    local image, location = window:recursiveGetChildById('timeImage'), window:recursiveGetChildById('location')
    window:setWidth(image:getWidth() + time:getMarginLeft() + time:getWidth() + location:getMarginLeft()
        + location:getWidth() + 2)
end

-- on the top menu bar while it shows in game, else under the HUD at the top of the map
local function place()
    if not window then
        return
    end
    local topMenu = modules.client_topmenu and modules.client_topmenu.getTopMenu and modules.client_topmenu.getTopMenu()
    window:breakAnchors()
    if topMenu and topMenu:isVisible() then
        window:setParent(topMenu)
        window:addAnchor(AnchorLeft, 'leftButtonsPanel', AnchorRight)
        window:addAnchor(AnchorVerticalCenter, 'parent', AnchorVerticalCenter)
        window:setMarginLeft(10)
        window:setMarginTop(0)
    else
        window:setParent(modules.game_interface.getRootPanel())
        window:addAnchor(AnchorTop, 'pokeHud', AnchorBottom)
        window:addAnchor(AnchorHorizontalCenter, 'pokeHud', AnchorHorizontalCenter)
        window:setMarginLeft(0)
        window:setMarginTop(-14)
    end
    window:setVisible(enabled and g_game.isOnline())
end

function setLocation(text)
    window:recursiveGetChildById('location'):setText(text)
    fitWidth()
end

function getLocation()
    if not window then
        return ''
    end
    local label = window:recursiveGetChildById('location')
    return label and label:getText() or ''
end

local function onTopMenuVisibility(widget, visible)
    if g_game.isOnline() and (visible or window:getParent() == widget) then
        place()
    end
end

-- Hooks
function onOnline()
    place()
    -- the top menu shows or hides for the view mode right after the game starts
    scheduleEvent(place, 200)
end

function onOffline()
    if window then
        window:hide()
    end
end

function onLightHour(lightHour)
  setTime(lightHour)
end

function onInit()
    window = g_ui.loadUI('time', modules.game_interface.getRootPanel())
    time = window:recursiveGetChildById('timeLabel')
    time:setText("00:00")
    lightStateImage = window:recursiveGetChildById('timeImage')
    window:hide()
    local topMenu = modules.client_topmenu and modules.client_topmenu.getTopMenu and modules.client_topmenu.getTopMenu()
    if topMenu then
        connect(topMenu, { onVisibilityChange = onTopMenuVisibility })
    end

    connect(g_game, {
        onGameStart = onOnline,
        onGameEnd = onOffline,
        onLightHour = onLightHour
    })

    if (g_game.isOnline()) then
        onOnline()
    end

    event = cycleEvent(increaseMinute, POKEVERSE_MINUTE_PER_SECOND * 1000)
end

function onTerminate()
    local topMenu = modules.client_topmenu and modules.client_topmenu.getTopMenu and modules.client_topmenu.getTopMenu()
    if topMenu then
        disconnect(topMenu, { onVisibilityChange = onTopMenuVisibility })
    end
    disconnect(g_game, {
        onGameStart = onOnline,
        onGameEnd = onOffline,
        onLightHour = onLightHour
    })

    removeEvent(event)
    event = nil

    if (window) then
        window:destroy()
        window = nil
    end

    time = nil
    timeNow = nil
    lightState = nil
    lightStateImage = nil
end