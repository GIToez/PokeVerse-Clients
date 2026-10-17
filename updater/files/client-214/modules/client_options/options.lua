local options = dofile("data_options")
for k, obj in pairs(options) do
    if type(obj) ~= "table" then
        options[k] = { value = obj }
    end
end

panels = {
    generalPanel = nil,
    graphicsPanel = nil,
    soundPanel = nil,
    gameMapPanel = nil,
    graphicsEffectsPanel = nil,
    interfaceHUD = nil,
    interface = nil,
    misc = nil,
    miscHelp = nil,
    keybindsPanel = nil,
    battleSoundsPanel = nil,
    iuSoundPanel = nil,
}

-- Hook into application exit to ensure settings are saved
local function onAppExit()
    g_settings.save()
end

-- Register the exit hook when the module is loaded
connect(g_app, { onExit = onAppExit })

-- LuaFormatter off
local buttons = { {
    text = "Controls",
    icon = "/modules/game_hotkeys/images/icon_keyboard",
    open = "keybindsPanel",
    mainText = "Key bindings",
    callbackFunc = function() setKeybindsFilter(nil) end,
    subCategories = { {
        text = "Item hotkeys",
        open = "keybindsPanel",
        callbackFunc = function() setKeybindsFilter('items') end
    }, {
        text = "General",
        open = "generalPanel"
    } }
}, {
    text = "Interface",
    icon = "/modules/game_hotkeys/images/icon_layout",
    open = "interface",
    subCategories = { {
        text = "HUD",
        open = "interfaceHUD"
    }, {
        text = "Console",
        open = "interfaceConsole"
    }, {
        text = "Action Bars",
        open = "actionbars"
    } }
}, {
    text = "Graphics",
    icon = "/modules/game_hotkeys/images/icon_monitor",
    open = "graphicsPanel",
    subCategories = { {
        text = "Effects",
        open = "graphicsEffectsPanel"
    } }
}, {
    text = "Sound",
    icon = "/modules/game_hotkeys/images/icon_sound",
    open = "soundPanel",
    subCategories = {{
        text = "Battle Sounds",
        open = "battleSoundsPanel"
    }, {
        text = "UI Sounds",
        open = "iuSoundPanel"
    }}
}, {
    text = "Misc.",
    icon = "/modules/game_hotkeys/images/icon_dots",
    open = "misc",
    subCategories = { {
        text = "Help",
        open = "miscHelp"
    } }
} }

-- LuaFormatter on
local selectedTab, selectedPage

local extraWidgets = {
    audioButton = nil,
    optionsButton = nil,
    logoutButton = nil,
    optionsButtons = nil
}

local protocolSoundSettingsKeys = {
    battleSoundOwnBattle = true,
    battleSoundOtherPlayers = true,
    battleSoundCreature = true,
    battleSoundOwnBattleSubChannelsAttack = true,
    battleSoundOwnBattleSoundSubChannelsHealing = true,
    battleSoundOwnBattleSoundSubChannelsSupport = true,
    battleSoundOwnBattleSoundSubChannelsWeapons = true,
    battleSoundOtherPlayersSubChannelsAttack = true,
    battleSoundOtherPlayersSubChannelsHealing = true,
    battleSoundOtherPlayersSubChannelsSupport = true,
    battleSoundOtherPlayersSubChannelsWeapons = true,
    battleSoundCreatureSubChannelsNoises = true,
    battleSoundCreatureSubChannelsNoisesDeath = true,
    battleSoundCreatureSubChannelsAttacksAndSpells = true,
    soundItems = true,
    soundFoodAndBeverages = true,
    soundMoveItem = true,
    soundEventVolume = true,
    soundAmbience = true,
    soundUI = true,
    soundUIsubChannelsInteractions = true,
    soundUIsubChannelsJoinLeaveParty = true,
    soundUIsubChannelsVipLoginLogout = true,
    soundNotificationConsoleMessages = true,
    soundNotificationUIInteractions = true,
    soundNotificationsubChannelsParty = true,
    soundNotificationsubChannelsGuild = true,
    soundNotificationsubChannelsLocalChat = true,
    soundNotificationsubChannelsPrivateMessages = true,
    soundNotificationsubChannelsNPC = true,
    soundNotificationsubChannelsGlobal = true,
    soundNotificationsubChannelsTeamFinder = true,
    soundNotificationsubChannelsRaidAnnouncements = true,
    soundNotificationsubChannelsSystemAnnouncements = true,
}

local function syncProtocolSoundSettings(key)
    if key and not protocolSoundSettingsKeys[key] then
        return
    end

    if g_sounds and g_sounds.refreshProtocolSoundSettings then
        g_sounds.refreshProtocolSoundSettings()
    end
end

local function toggleDisplays()
    if options['displayNames'].value and options['displayHealth'].value and options['displayMana'].value and options['displayHarmony'].value then
        setOption('displayNames', false)
    elseif options['displayHealth'].value then
        setOption('displayHealth', false)
        setOption('displayMana', false)
        setOption('displayHarmony', false)
    else
        if not options['displayNames'].value and not options['displayHealth'].value then
            setOption('displayNames', true)
        else
            setOption('displayHealth', true)
            setOption('displayMana', true)
            setOption('displayHarmony', true)
        end
    end
end

local function toggleOption(key)
    setOption(key, not getOption(key))
end

-- Toggles mute without discarding the user's previously saved master volume
local function toggleMute()
    local current = getOption('soundMaster')
    if current <= 1 then
        local restoreVolume = options.soundMaster.lastVolume or g_settings.getNumber('soundMasterLastVolume', 25)
        if not restoreVolume or restoreVolume <= 1 then
            restoreVolume = 25
        end
        setOption('soundMaster', restoreVolume)
    else
        options.soundMaster.lastVolume = current
        g_settings.set('soundMasterLastVolume', current)
        setOption('soundMaster', 1)
    end
end

local function setupComboBox()
    local crosshairCombo = panels.interface:recursiveGetChildById('crosshair')
    local antialiasingModeCombobox = panels.graphicsPanel:recursiveGetChildById('antialiasingMode')
    local floorViewModeCombobox = panels.graphicsEffectsPanel:recursiveGetChildById('floorViewMode')
    local framesRarityCombobox = panels.interface:recursiveGetChildById('frames')
    local vocationPresetsCombobox = panels.keybindsPanel:recursiveGetChildById('list')
    local listKeybindsPanel = panels.keybindsPanel:recursiveGetChildById('list')
    local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
    local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')

    for k, v in pairs({ { 'Disabled', 'disabled' }, { 'Default', 'default' }, { 'Full', 'full' }, { 'Animation', 'animation' } }) do
        crosshairCombo:addOption(v[1], v[2])
    end

    crosshairCombo.onOptionChange = function(comboBox, option)
        setOption('crosshair', comboBox:getCurrentOption().data)
    end

    mouseControlModeCombobox:addOption('Regular Controls', 0)
    mouseControlModeCombobox:addOption('Classic Controls', 1)
    mouseControlModeCombobox:addOption('Left Smart-Click', 2)

    lootControlModeCombobox:addOption('Loot: Right', 0)
    lootControlModeCombobox:addOption('Loot: SHIFT+Right', 1)
    lootControlModeCombobox:addOption('Loot: Left', 2)
    
    lootControlModeCombobox.onOptionChange = function(comboBox, option)
        setOption('lootControlMode', comboBox:getCurrentOption().data)
    end

    mouseControlModeCombobox.onOptionChange = function(comboBox, option)
        local selectedOption = comboBox:getCurrentOption().data
        setOption('mouseControlMode', selectedOption)
        
        -- The mouseControlMode action handler will take care of updating
        -- classicControl and smartLeftClick, and their UI visibility
    end

    for k, t in pairs({ 'None', 'Antialiasing', 'Smooth Retro' }) do
        antialiasingModeCombobox:addOption(t, k - 1)
    end

    antialiasingModeCombobox.onOptionChange = function(comboBox, option)
        setOption('antialiasingMode', comboBox:getCurrentOption().data)
    end


    for k, t in pairs({ 'Normal', 'Fade', 'Locked', 'Always', 'Always with transparency' }) do
        floorViewModeCombobox:addOption(t, k - 1)
    end

    floorViewModeCombobox.onOptionChange = function(comboBox, option)
        setOption('floorViewMode', comboBox:getCurrentOption().data)
    end

    for k, v in pairs({ { 'None', 'none' }, { 'Frames', 'frames' }, { 'Corners', 'corners' } }) do
        framesRarityCombobox:addOption(v[1], v[2])
    end

    framesRarityCombobox.onOptionChange = function(comboBox, option)
        setOption('framesRarity', comboBox:getCurrentOption().data)
    end

    local visualStyleCombobox = panels.interface:recursiveGetChildById('visualStyle')
    for _, v in ipairs({ { 'Off', 'off' }, { 'Vibrant', 'vibrant' }, { 'Toon', 'toon' } }) do
        visualStyleCombobox:addOption(tr(v[1]), v[2])
    end
    visualStyleCombobox.onOptionChange = function(comboBox, option)
        setOption('visualStyle', comboBox:getCurrentOption().data)
    end

    local profileCombobox = panels.misc:recursiveGetChildById('profile')

    for i = 1, 10 do
        profileCombobox:addOption(tostring(i), i)
    end

    profileCombobox.onOptionChange = function(comboBox, option)
        setOption('profile', comboBox:getCurrentOption().data)
    end

    local soundDeviceCombobox = panels.soundPanel:recursiveGetChildById('soundDevice')
    if soundDeviceCombobox then
        soundDeviceCombobox:clearOptions()
        soundDeviceCombobox:addOption(tr('(auto-select)'), '(auto-select)')
        if g_sounds and g_sounds.getAudioDevices then
            local devices = g_sounds.getAudioDevices()
            for _, device in ipairs(devices) do
                local displayName = device:gsub('^OpenAL Soft on%s*', '')
                soundDeviceCombobox:addOption(displayName, device)
            end
        end

        soundDeviceCombobox.onOptionChange = function(comboBox, option)
            local current = comboBox:getCurrentOption()
            if current then
                setOption('soundDevice', current.data)
            end
        end

        local currentDevice = '(auto-select)'
        if options.soundDevice and options.soundDevice.value and options.soundDevice.value ~= '' then
            currentDevice = options.soundDevice.value
        end
        soundDeviceCombobox:setCurrentOptionByData(currentDevice, true)
    end

    for _, preset in ipairs(Keybind.presets) do
        listKeybindsPanel:addOption(preset)
    end
    listKeybindsPanel.onOptionChange = function(comboBox, option)
        setOption('listKeybindsPanel', option)
    end
    panels.keybindsPanel.presets.list:setCurrentOption(Keybind.currentPreset)
end

local function setup()
    panels.gameMapPanel = modules.game_interface.getMapPanel()

    setupComboBox()

    -- Settings saved by a build without the PokeVerse defaults keep Redemption's Tibia layout
    -- (action bars, left panel); put those back to the PokeVerse defaults once
    local function resetToDefaults(keys)
        for _, k in ipairs(keys) do
            local value = options[k]
            if type(value) == 'table' then
                value = value.value
            end
            if value ~= nil then
                g_settings.set(k, value)
            end
        end
    end
    local layoutVersion = g_settings.getNumber('pokeverseLayoutVersion', 0)
    if layoutVersion < 1 then
        resetToDefaults({ 'returnDisablesChat', 'showLeftPanel' })
        -- the action bars read their visibility from settings/clientoptions.json before these options
        local actionBarKeys = {}
        for _, side in ipairs({ 'Bottom', 'Left', 'Right' }) do
            for i = 1, 3 do
                local k = 'actionBarShow' .. side .. i
                actionBarKeys[#actionBarKeys + 1] = k
                g_settings.set(k, false)
            end
        end
        local actionBar = modules.game_actionbar
        if actionBar and actionBar.ApiJson then
            for n, k in ipairs(actionBarKeys) do
                actionBar.ApiJson.setBarVisibility(n, k, false)
            end
            actionBar.ApiJson.saveData()
        else
            local file = '/settings/clientoptions.json'
            if g_resources.fileExists(file) then
                local ok, data = pcall(function() return json.decode(g_resources.readFileContents(file)) end)
                if ok and type(data) == 'table' and data.actionBarVisibility then
                    data.actionBarVisibility = nil
                    g_resources.writeFileContents(file, json.encode(data))
                end
            end
        end
    end
    -- the PokeVerse control defaults (Left Smart-Click, smart and dash walking) replace earlier ones once
    if layoutVersion < 2 then
        resetToDefaults({ 'classicControl', 'smartLeftClick', 'mouseControlMode', 'returnDisablesChat', 'smartWalk',
            'dashWalk', 'autoChaseOverride', 'moveStack', 'openMaximized', 'displayText', 'showPing', 'hotkeyDelay',
            'walkTurnDelay', 'walkTeleportDelay', 'walkStairsDelay' })
        g_settings.set('pokeverseLayoutVersion', 2)
        g_settings.save()
    end
    -- the ambience was far too loud at Redemption's 100%; anyone who never changed it gets the new default
    if layoutVersion < 3 then
        if g_settings.getNumber('soundAmbience', 100) == 100 then
            g_settings.set('soundAmbience', options.soundAmbience.value)
        end
        g_settings.set('pokeverseLayoutVersion', 3)
        g_settings.save()
    end
    -- the login music was too loud at 100%; anyone who never changed it gets the new default
    if layoutVersion < 4 then
        if g_settings.getNumber('soundMusic', 100) == 100 then
            g_settings.set('soundMusic', options.soundMusic.value)
        end
        g_settings.set('pokeverseLayoutVersion', 4)
        g_settings.save()
    end

    -- load options
    for k, obj in pairs(options) do
        -- an option may either be a bare value or a table with an 'action'
        -- an "and/or" chain cannot be used here: a default of 'false' would
        -- fall through to the table and the option would never be loaded
        local v
        if type(obj) == 'table' then
            v = obj.value
        else
            v = obj
        end

        if type(v) == 'boolean' then
            local value = g_settings.getBoolean(k, v)
            setOption(k, value, true)
        elseif type(v) == 'number' then
            local value = g_settings.getNumber(k, v)
            setOption(k, value, true)
        elseif type(v) == 'string' then
            local value = g_settings.getString(k, v)
            setOption(k, value, true)
        end
    end

    -- Every persisted option has been applied, so widgets that mirror option
    -- values outside of the options panels (e.g. the game_interface top bar
    -- arrows) can now sync themselves with the loaded state.
    if modules.game_interface and modules.game_interface.onOptionsLoaded then
        modules.game_interface.onOptionsLoaded()
    end
    
    -- Special handling for mouseControlMode to ensure it's in sync with the underlying options
    local mouseControlMode = g_settings.getNumber('mouseControlMode')
    if mouseControlMode ~= nil then
        setOption('mouseControlMode', mouseControlMode, true)
    else
        -- Derive from classicControl and smartLeftClick if mouseControlMode isn't set
        local classicControl = g_settings.getBoolean('classicControl')
        local smartLeftClick = g_settings.getBoolean('smartLeftClick')
        
        if classicControl then
            setOption('mouseControlMode', 1, true)
        elseif smartLeftClick then
            setOption('mouseControlMode', 2, true)
        else
            setOption('mouseControlMode', 0, true)
        end
    end
    
    -- Schedule combobox updates to ensure they happen after UI setup is complete
    scheduleEvent(function()
        local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
        local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
        
        if mouseControlModeCombobox then
            -- Use setCurrentOptionByData for more precise control
            for i = 0, 2 do
                if i == options.mouseControlMode.value then
                    mouseControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
        
        if lootControlModeCombobox then
            -- Use setCurrentOptionByData for more precise control
            for i = 0, 2 do
                if i == options.lootControlMode.value then
                    lootControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end

        local soundDeviceCombobox = panels.soundPanel:recursiveGetChildById('soundDevice')
        if soundDeviceCombobox and options.soundDevice and options.soundDevice.value then
            soundDeviceCombobox:setCurrentOptionByData(options.soundDevice.value, true)
        end
        
        -- Update loot control mode visibility
        if lootControlModeCombobox and mouseControlModeCombobox then
            if options.mouseControlMode.value == 1 then
                lootControlModeCombobox:setVisible(true)
            else
                lootControlModeCombobox:setVisible(false)
            end
        end
    end, 100)

    local talkOnRightClick = panels.generalPanel:recursiveGetChildById('talkOnRightClick')
    if talkOnRightClick then
        local parent = talkOnRightClick:getParent()
        parent:setVisible(false)
        parent:setHeight(0)
        parent:setMarginTop(0)
    end

end


controller = Controller:new()
controller:setUI('options')

function controller:onInit()
    for k, obj in pairs(options) do
        if type(obj) ~= "table" then
            obj = { value = obj }
            options[k] = obj
        end
        g_settings.setDefault(k, obj.value)
    end

    extraWidgets.audioButton = modules.client_topmenu.addTopRightToggleButton('audioButton', tr('Audio'),
        '/images/topbuttons/button_mute_up', toggleMute)

    extraWidgets.optionsButton = modules.client_topmenu.addTopRightToggleButton('optionsButton', tr('Options'),
        '/images/topbuttons/button_options', toggle)

    extraWidgets.logoutButton = modules.client_topmenu.addTopRightToggleButton('logoutButton', tr('Exit'),
        '/images/topbuttons/logout', toggle)

    panels.generalPanel = g_ui.loadUI('styles/controls/general', controller.ui.optionsTabContent)
    panels.keybindsPanel = g_ui.loadUI('styles/controls/keybinds', controller.ui.optionsTabContent)

    panels.graphicsPanel = g_ui.loadUI('styles/graphics/graphics', controller.ui.optionsTabContent)
    panels.graphicsEffectsPanel = g_ui.loadUI('styles/graphics/effects', controller.ui.optionsTabContent)

    panels.interface = g_ui.loadUI('styles/interface/interface', controller.ui.optionsTabContent)
    panels.interfaceConsole = g_ui.loadUI('styles/interface/console', controller.ui.optionsTabContent)
    panels.interfaceHUD = g_ui.loadUI('styles/interface/HUD', controller.ui.optionsTabContent)
    panels.actionbars = g_ui.loadUI('styles/interface/actionbars', controller.ui.optionsTabContent)

    panels.soundPanel = g_ui.loadUI('styles/sound/sound', controller.ui.optionsTabContent)
    panels.battleSoundsPanel = g_ui.loadUI('styles/sound/battleSounds', controller.ui.optionsTabContent)
    panels.iuSoundPanel = g_ui.loadUI('styles/sound/uiSounds', controller.ui.optionsTabContent)

    panels.misc = g_ui.loadUI('styles/misc/misc', controller.ui.optionsTabContent)
    panels.miscHelp = g_ui.loadUI('styles/misc/help', controller.ui.optionsTabContent)

    self.ui:hide()

    configureCharacterCategories()
    addEvent(setup)
    
    -- Add a special delayed event to update comboboxes after everything is loaded
    scheduleEvent(function()
        local mouseControlModeCombobox = panels.generalPanel:recursiveGetChildById('mouseControlMode')
        local lootControlModeCombobox = panels.generalPanel:recursiveGetChildById('lootControlMode')
        
        if mouseControlModeCombobox then
            for i = 0, 2 do
                if i == options.mouseControlMode.value then
                    mouseControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end
        
        if lootControlModeCombobox then
            for i = 0, 2 do
                if i == options.lootControlMode.value then
                    lootControlModeCombobox:setCurrentOptionByData(i)
                    break
                end
            end
        end

        local soundDeviceCombobox = panels.soundPanel:recursiveGetChildById('soundDevice')
        if soundDeviceCombobox and options.soundDevice and options.soundDevice.value then
            soundDeviceCombobox:setCurrentOptionByData(options.soundDevice.value, true)
        end
    end, 1000)  -- 1 second delay to make sure everything is loaded
    
    init_binds()

    Keybind.new("UI", "Toggle Fullscreen", "Ctrl+Shift+F", "")
    Keybind.bind("UI", "Toggle Fullscreen", {
        {
            type = KEY_DOWN,
            callback = function() toggleOption('fullscreen') end,
        }
    })
    Keybind.new("UI", "Show/hide FPS / lag indicator", "", "")
    Keybind.bind("UI", "Show/hide FPS / lag indicator", { {
        type = KEY_DOWN,
        callback = function()
            toggleOption('showPing')
            toggleOption('showFps')
        end
    } })

    Keybind.new("UI", "Show/hide Creature Names and Bars", "Ctrl+N", "")
    Keybind.bind("UI", "Show/hide Creature Names and Bars", {
        {
            type = KEY_DOWN,
            callback = toggleDisplays,
        }
    })

    Keybind.new("Sound", "Mute/unmute", "", "")
    Keybind.bind("Sound", "Mute/unmute", {
        {
            type = KEY_DOWN,
            callback = toggleMute,
        }
    })
end

function controller:onTerminate()
    -- Make sure all settings are saved before terminating
    g_settings.save()
    
    -- Disconnect from app exit
    disconnect(g_app, { onExit = onAppExit })
    
    extraWidgets.optionsButton:destroy()
    extraWidgets.audioButton:destroy()
    panels = {}
    extraWidgets = {}
    buttons = {}
    Keybind.delete("UI", "Toggle Fullscreen")
    Keybind.delete("UI", "Show/hide Creature Names and Bars")
    Keybind.delete("UI", "Show/hide FPS / lag indicator")
    Keybind.delete("Sound", "Mute/unmute")

    terminate_binds()
end

function controller:onGameStart()
    g_game.getProtocolGame():sendExtendedOpcode(ExtendedIds.DashWalking, getOption('dashWalk') and '1' or '0')
    g_game.getProtocolGame():sendExtendedOpcode(ExtendedIds.AutoLoot, getOption('autoLoot') and '1' or '0')
    if g_settings.getBoolean("autoSwitchPreset") then
        local name = g_game.getCharacterName()
        if Keybind.selectPreset(name) then
            panels.keybindsPanel.presets.list:setCurrentOption(name, true)
            updateKeybinds()
            if modules.game_actionbar and modules.game_actionbar.selectHotkeySet then
                if not modules.game_actionbar.selectHotkeySet(name) then
                    g_logger.warning(string.format("[client_options] Failed to sync action bar hotkey set '%s' on startup.", name))
                end
            end
        end
    end
    if not g_game.getFeature(GameEffectSource) then
        panels.graphicsEffectsPanel.clientEffectOpacity:show()
        panels.graphicsEffectsPanel.clientMissileOpacity:show()
        panels.graphicsEffectsPanel.GameEffectSource:hide()
    else
        g_client.setEffectAlpha(1)
        g_client.setMissileAlpha(1)
        panels.graphicsEffectsPanel.clientEffectOpacity:hide()
        panels.graphicsEffectsPanel.clientMissileOpacity:hide()
        panels.graphicsEffectsPanel.GameEffectSource:show()
    end
end

function setOption(key, value, force)
    if not modules.game_interface then
        return
    end

    local option = options[key]
    if option == nil then
        g_logger.warning(string.format("[client_options] Attempted to set unknown option: '%s'", key))
        return
    end

    if type(option) ~= 'table' then
        option = { value = option }
        options[key] = option
    end

    if not force and option.value == value then
        return
    end

    option.value = value

    if option.action then
        option.action(value, options, controller, panels, extraWidgets)
    end


    -- change value for keybind updates
    for _, panel in pairs(panels) do
        local widget = panel:recursiveGetChildById(key)
        if widget then
            if widget:getStyle().__class == 'UICheckBox' then
                widget:setChecked(value)
            elseif widget:getStyle().__class == 'UIScrollBar' then
                widget:setValue(value)
            elseif widget:recursiveGetChildById('valueBar') then
                widget:recursiveGetChildById('valueBar'):setValue(value)
            elseif widget.setCurrentOptionByData then
                widget:setCurrentOptionByData(value, true)
            end
            break
        end
    end

    g_settings.set(key, value)
    syncProtocolSoundSettings(key)
end

function setupOptionsMainButton()
    if extraWidgets.optionsButtons then
        return
    end

    extraWidgets.optionsButtons = modules.game_mainpanel.addSpecialToggleButton('optionsMainButton', tr('Options'),
        '/images/options/button_options', toggle, true)
end

function getOption(key)
    local option = options[key]
    if option == nil then
        g_logger.warning(string.format("[client_options] Attempted to get unknown option: '%s'", key))
        return nil
    end

    -- an option may either be a bare value or a table with an 'action'
    -- a plain "and/or" chain cannot be used here: a stored 'false' would fall
    -- through to 'option' and make every caller see a truthy table
    if type(option) == 'table' then
        return option.value
    end

    return option
end

function show()
    controller.ui:show()
    controller.ui:raise()
    controller.ui:focus()
    if extraWidgets.optionsButton then
        extraWidgets.optionsButton:setOn(true)
    end
end

function hide()
    stopKeyCapture()
    controller.ui:hide()
    if extraWidgets.optionsButton then
        extraWidgets.optionsButton:setOn(false)
    end
end

function saveOptions()
    g_settings.save()
end

function toggle()
    if controller.ui:isVisible() then
        hide()
        return
    end
    if not selectedTab then
        selectTab(1)
    end
    show()
    updateKeybinds()
end

function addTab(name, panel, icon)
    print("to prevent the error use Ex = g_ui.loadUI('option_healthcircle',modules.client_options:getPanel()) ")
end

function removeTab(v)
    print("to prevent the error use Ex   modules.client_options.addButton('Interface', 'HP/MP Circle', optionPanel)")
end

function onShowAdvancedOptions(widget, checked)
    -- TODO: Implement Show Advanced Options functionality in the near future
end

-- every tab opens on its own panel; the panels added with addButton follow as sub tabs
local function pagesOf(button)
    local pages = { { text = button.mainText or 'General', open = button.open, callbackFunc = button.callbackFunc } }
    for _, sub in ipairs(button.subCategories or {}) do
        table.insert(pages, sub)
    end
    return pages
end

-- the option pages are built from Qt frame panels: give them the PokeVerse card look instead,
-- hiding the four 2px edge widgets the SmallReversedQtPanel style draws its frame with
local function restyleCards(widget)
    for _, child in ipairs(widget:getChildren()) do
        if child:getStyleName() == 'SmallReversedQtPanel' and not child.pvCard then
            child.pvCard = true
            -- an image on a widget with no size (hidden cards are 0 high) resizes it to the image
            local size = child:getSize()
            child:setImageSource('/modules/game_dailytasks/images/card')
            child:setImageBorder(8)
            child:setSize(size)
            for index = 1, math.min(4, child:getChildCount()) do
                local edge = child:getChildByIndex(index)
                if edge:getStyleName() == 'UIWidget' and edge:getChildCount() == 0 then
                    edge:hide()
                end
            end
        end
        restyleCards(child)
    end
end

-- Redemption sizes its cards for 13px checkboxes; ours are taller, so cards grow to fit
local function fitCards(widget)
    local grew = false
    for _, child in ipairs(widget:getChildren()) do
        if child:isVisible() then
            grew = fitCards(child) or grew
            if child.pvCard then
                local bottom = 0
                for _, inner in ipairs(child:getChildren()) do
                    if inner:isVisible() then
                        bottom = math.max(bottom, inner:getY() + inner:getHeight() + inner:getMarginBottom() - child:getY())
                    end
                end
                if bottom > child:getHeight() then
                    child:setHeight(bottom + 4)
                    grew = true
                end
            end
        end
    end
    return grew
end

local function fitCardsSoon(panel, passes)
    addEvent(function()
        if panel:isVisible() and fitCards(panel) and passes > 1 then
            fitCardsSoon(panel, passes - 1)
        end
    end)
end

local function showPage(page)
    if controller.ui.selectedOption then
        controller.ui.selectedOption:hide()
    end
    local panel = page and panels[page.open]
    if not panel then
        return
    end
    restyleCards(panel)
    panel:show()
    fitCardsSoon(panel, 3)
    controller.ui.selectedOption = panel
    if page.callbackFunc then
        page.callbackFunc()
    end
end

local function selectPage(index)
    local button = buttons[selectedTab]
    local pages = button and pagesOf(button) or {}
    if not pages[index] then
        return
    end
    selectedPage = index
    for i, widget in ipairs(controller.ui.optionsSubTabBar:getChildren()) do
        widget:setChecked(i == index)
    end
    showPage(pages[index])
end

function selectTab(id, pageIndex)
    local button = buttons[id]
    if not button then
        return
    end
    selectedTab = id
    for i, widget in ipairs(controller.ui.optionsTabBar:getChildren()) do
        widget:setChecked(i == id)
    end
    local bar = controller.ui.optionsSubTabBar
    bar:destroyChildren()
    for index, page in ipairs(pagesOf(button)) do
        local sub = g_ui.createWidget('OptSubTab', bar)
        sub:setText(tr(page.text))
        sub:setWidth(sub:getTextSize().width + 28)
        sub.onClick = function()
            selectPage(index)
        end
    end
    selectPage(pageIndex or 1)
end

local function layoutTabs(bar)
    local count = bar:getChildCount()
    if count == 0 then
        return
    end
    local width = math.floor((bar:getWidth() - 8 * (count - 1)) / count)
    for _, tab in ipairs(bar:getChildren()) do
        tab:setWidth(width)
    end
end

function selectCharacterPage()
end

function closeCharacterButtons()
end

function configureCharacterCategories()
    local bar = controller.ui.optionsTabBar
    bar:destroyChildren()
    for id, button in ipairs(buttons) do
        local tab = g_ui.createWidget('OptTab', bar)
        tab:setText(tr(button.text))
        tab:setIcon(button.icon)
        tab.onClick = function()
            selectTab(id)
        end
    end
    bar.onGeometryChange = layoutTabs
    layoutTabs(bar)
    if selectedTab then
        selectTab(math.min(selectedTab, #buttons), selectedPage)
    end
end

function updateSliderFill(bar)
    local fill = bar and bar:getChildById('fill')
    if not fill then
        return
    end
    local range = bar:getMaximum() - bar:getMinimum()
    local width = 0
    if range > 0 then
        width = math.floor((bar:getValue() - bar:getMinimum()) / range * (bar:getWidth() - 13)) + 7
    end
    fill:setWidth(math.max(0, width))
end

function createCategory(text, icon, openPanel, subCategories)
    local newCategory = {
        text = text,
        icon = icon,
        open = type(openPanel) == "string" and openPanel or getPanelName(openPanel),
        subCategories = subCategories
    }
    table.insert(buttons, newCategory)
    if type(openPanel) ~= "string" then
        panels[getPanelName(openPanel)] = openPanel
    end
    configureCharacterCategories()
end

function removeCategory(categoryText, subcategoryText)
    for i, category in ipairs(buttons) do
        if category.text == categoryText then
            if subcategoryText then
                if category.subCategories then
                    for j, subcategory in ipairs(category.subCategories) do
                        if subcategory.text == subcategoryText then
                            panels[subcategory.open] = nil
                            table.remove(category.subCategories, j)
                            break
                        end
                    end
                end
            else
                panels[category.open] = nil
                if category.subCategories then
                    for _, subcategory in ipairs(category.subCategories) do
                        panels[subcategory.open] = nil
                    end
                end
                table.remove(buttons, i)
            end
            configureCharacterCategories()
            return
        end
    end
end

function removeButton(categoryText, buttonText)
    for _, category in ipairs(buttons) do
        if category.text == categoryText then
            if category.subCategories then
                for i, subcategory in ipairs(category.subCategories) do
                    if subcategory.text == buttonText then
                        panels[subcategory.open] = nil
                        table.remove(category.subCategories, i)
                        configureCharacterCategories()
                        return
                    end
                end
            end
        end
    end
end

function addButton(categoryText, buttonText, openPanel, callback)
    for _, category in ipairs(buttons) do
        if category.text == categoryText then
            if not category.subCategories then
                category.subCategories = {}
            end
            local panelName = type(openPanel) == "string" and openPanel or getPanelName(openPanel)
            table.insert(category.subCategories, {
                text = buttonText,
                open = panelName,
                callbackFunc = callback
            })
            if type(openPanel) ~= "string" then
                panels[panelName] = openPanel
            end
            configureCharacterCategories()
            return
        end
    end
end

local panelNameCount = 0

-- tostring(userdata) has no "0x" on Windows, so names come from a counter rather than the address
function getPanelName(panel)
    for name, p in pairs(panels) do
        if p == panel then
            return name
        end
    end
    panelNameCount = panelNameCount + 1
    return "panel_" .. panelNameCount
end

function addSubcategoryToCategory(categoryText, newSubcategory)
    addButtonToCategory(categoryText, newSubcategory)
end

function getPanel()
    return controller.ui.optionsTabContent
end

function openOptionsCategory(category, subcategory)
    if not controller.ui:isVisible() then
        show()
    end
    for id, button in ipairs(buttons) do
        if button.text == category then
            local pageIndex = 1
            for index, page in ipairs(pagesOf(button)) do
                if subcategory and page.text == subcategory then
                    pageIndex = index
                end
            end
            selectTab(id, pageIndex)
            return true
        end
    end
    return false
end
