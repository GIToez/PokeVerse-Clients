
CHAT_MODE = {
  ON = 1,
  OFF = 2
}

Keybind = {
  presets = {},
  presetToIndex = {},
  currentPreset = nil,
  configs = {
    keybinds = {},
    hotkeys = {}
  },
  defaultKeys = {
    [CHAT_MODE.ON] = {},
    [CHAT_MODE.OFF] = {}
  },
  defaultKeybinds = {},
  hotkeys = {
    [CHAT_MODE.ON] = {},
    [CHAT_MODE.OFF] = {}
  },
  chatMode = CHAT_MODE.ON,

  reservedKeys = {
    ["Up"] = true,
    ["Down"] = true,
    ["Left"] = true,
    ["Right"] = true
  }
}

KEY_UP = 1
KEY_DOWN = 2
KEY_PRESS = 3

HOTKEY_ACTION = {
  USE_YOURSELF = 1,
  USE_CROSSHAIR = 2,
  USE_TARGET = 3,
  EQUIP = 4,
  USE = 5,
  TEXT = 6,
  TEXT_AUTO = 7,
  SPELL = 8,
  USE_POKEMON = 9 -- PokeVerse: use the item on the Pokemon the player has out
}

-- OTML hands numbers back as strings, and a saved list must not carry the bound callbacks
local function normalizeHotkey(hotkey)
  hotkey.action = tonumber(hotkey.action)
  hotkey.hotkeyId = tonumber(hotkey.hotkeyId)
  hotkey.primary = hotkey.primary and tostring(hotkey.primary) or ""
  hotkey.secondary = hotkey.secondary and tostring(hotkey.secondary) or ""
  local data = hotkey.data or {}
  hotkey.data = data
  data.itemId = tonumber(data.itemId)
  data.subType = tonumber(data.subType)
  if data.text ~= nil then
    data.text = tostring(data.text)
  end
  return hotkey
end

local function storableHotkeys(list)
  local out = {}
  for id, hotkey in ipairs(list) do
    out[id] = {
      hotkeyId = id,
      action = hotkey.action,
      data = table.recursivecopy(hotkey.data or {}),
      primary = hotkey.primary or "",
      secondary = hotkey.secondary or ""
    }
  end
  return out
end

local function saveHotkeys(preset, chatMode)
  local config = Keybind.configs.hotkeys[preset]
  local list = Keybind.hotkeys[chatMode][preset] or {}
  if #list == 0 then
    config:remove(chatMode)
  else
    config:setNode(chatMode, storableHotkeys(list))
  end
  config:save()
end

local function usesKeyDown(action)
  return action == HOTKEY_ACTION.EQUIP or action == HOTKEY_ACTION.USE or action == HOTKEY_ACTION.TEXT or
    action == HOTKEY_ACTION.TEXT_AUTO or action == HOTKEY_ACTION.USE_POKEMON
end

function Keybind.init()
  connect(g_game, { onGameStart = Keybind.online, onGameEnd = Keybind.offline })

  -- PokeVerse: one "Trainer" preset instead of Redemption's Tibia vocations, also for settings saved with them
  local vocations = { Druid = true, Knight = true, Paladin = true, Sorcerer = true, Monk = true }
  Keybind.presets = {}
  for _, preset in ipairs(g_settings.getList("controls-presets")) do
    if not vocations[preset] then
      table.insert(Keybind.presets, preset)
    end
  end

  if #Keybind.presets == 0 then
    Keybind.presets = { "Trainer" }
  end
  Keybind.currentPreset = g_settings.getValue("controls-preset-current")
  if not table.find(Keybind.presets, Keybind.currentPreset) then
    Keybind.currentPreset = Keybind.presets[1]
  end

  for index, preset in ipairs(Keybind.presets) do
    Keybind.presetToIndex[preset] = index
  end

  if not g_resources.directoryExists("/controls") then
    g_resources.makeDir("/controls")
  end

  if not g_resources.directoryExists("/controls/keybinds") then
    g_resources.makeDir("/controls/keybinds")
  end

  if not g_resources.directoryExists("/controls/hotkeys") then
    g_resources.makeDir("/controls/hotkeys")
  end

  for _, preset in ipairs(Keybind.presets) do
    Keybind.configs.keybinds[preset] = g_configs.create("/controls/keybinds/" .. preset .. ".otml")
    Keybind.configs.hotkeys[preset] = g_configs.create("/controls/hotkeys/" .. preset .. ".otml")
  end

  for preset, config in pairs(Keybind.configs.hotkeys) do
    for chatMode = CHAT_MODE.ON, CHAT_MODE.OFF do
      Keybind.hotkeys[chatMode][preset] = {}
      local hotkeyId = 1
      local hotkeys = config:getNode(chatMode)

      if hotkeys then
        local hotkey = hotkeys[tostring(hotkeyId)]
        while hotkey do
          if hotkey.data.parameter then
            hotkey.data.parameter = "\"" .. hotkey.data.parameter .. "\"" -- forcing quotes cause OTML is not saving them, just wow
          end

          table.insert(Keybind.hotkeys[chatMode][preset], normalizeHotkey(hotkey))
          hotkeyId = hotkeyId + 1

          hotkey = hotkeys[tostring(hotkeyId)]
        end
      end
    end
  end
end

function Keybind.terminate()
  disconnect(g_game, { onGameStart = Keybind.online, onGameEnd = Keybind.offline })

  for _, preset in ipairs(Keybind.presets) do
    Keybind.configs.keybinds[preset]:save()
    Keybind.configs.hotkeys[preset]:save()
  end

  g_settings.setList("controls-presets", Keybind.presets)
  g_settings.setValue("controls-preset-current", Keybind.currentPreset)
  g_settings.save()
end

function Keybind.online()
  for _, hotkey in ipairs(Keybind.hotkeys[Keybind.chatMode][Keybind.currentPreset]) do
    Keybind.bindHotkey(hotkey.hotkeyId, Keybind.chatMode)
  end
end

function Keybind.offline()
  for _, hotkey in ipairs(Keybind.hotkeys[Keybind.chatMode][Keybind.currentPreset]) do
    Keybind.unbindHotkey(hotkey.hotkeyId, Keybind.chatMode)
  end
end

function Keybind.new(category, action, primary, secondary, alone)
  local index = category .. '_' .. action
  if Keybind.defaultKeybinds[index] then
    pwarning(string.format("Keybind for [%s: %s] is already in use", category, action))
    return
  end

  local keys = {}
  if type(primary) == "string" then
    keys[CHAT_MODE.ON] = { primary = primary }
    keys[CHAT_MODE.OFF] = { primary = primary }
  else
    keys[CHAT_MODE.ON] = { primary = primary[CHAT_MODE.ON] }
    keys[CHAT_MODE.OFF] = { primary = primary[CHAT_MODE.OFF] }
  end

  if type(secondary) == "string" then
    keys[CHAT_MODE.ON].secondary = secondary
    keys[CHAT_MODE.OFF].secondary = secondary
  else
    keys[CHAT_MODE.ON].secondary = secondary[CHAT_MODE.ON]
    keys[CHAT_MODE.OFF].secondary = secondary[CHAT_MODE.OFF]
  end

  keys[CHAT_MODE.ON].primary = retranslateKeyComboDesc(keys[CHAT_MODE.ON].primary)

  if keys[CHAT_MODE.ON].secondary then
    keys[CHAT_MODE.ON].secondary = retranslateKeyComboDesc(keys[CHAT_MODE.ON].secondary)
  end

  keys[CHAT_MODE.OFF].primary = retranslateKeyComboDesc(keys[CHAT_MODE.OFF].primary)

  if keys[CHAT_MODE.OFF].secondary then
    keys[CHAT_MODE.OFF].secondary = retranslateKeyComboDesc(keys[CHAT_MODE.OFF].secondary)
  end

  if Keybind.defaultKeys[CHAT_MODE.ON][keys[CHAT_MODE.ON].primary] then
    local primaryIndex = Keybind.defaultKeys[CHAT_MODE.ON][keys[CHAT_MODE.ON].primary]
    local primaryKeybind = Keybind.defaultKeybinds[primaryIndex]
    perror(string.format("Default primary key (Chat Mode On) assigned to [%s: %s] is already in use by [%s: %s]",
      category, action, primaryKeybind.category, primaryKeybind.action))
    return
  end

  if Keybind.defaultKeys[CHAT_MODE.OFF][keys[CHAT_MODE.OFF].primary] then
    local primaryIndex = Keybind.defaultKeys[CHAT_MODE.OFF][keys[CHAT_MODE.OFF].primary]
    local primaryKeybind = Keybind.defaultKeybinds[primaryIndex]
    perror(string.format("Default primary key (Chat Mode Off) assigned to [%s: %s] is already in use by [%s: %s]",
      category, action, primaryKeybind.category, primaryKeybind.action))
    return
  end

  if keys[CHAT_MODE.ON].secondary and Keybind.defaultKeys[CHAT_MODE.ON][keys[CHAT_MODE.ON].secondary] then
    local secondaryIndex = Keybind.defaultKeys[CHAT_MODE.ON][keys[CHAT_MODE.ON].secondary]
    local secondaryKeybind = Keybind.defaultKeybinds[secondaryIndex]
    perror(string.format("Default secondary key (Chat Mode On) assigned to [%s: %s] is already in use by [%s: %s]",
      category, action, secondaryKeybind.category, secondaryKeybind.action))
    return
  end

  if keys[CHAT_MODE.OFF].secondary and Keybind.defaultKeys[CHAT_MODE.OFF][keys[CHAT_MODE.OFF].secondary] then
    local secondaryIndex = Keybind.defaultKeys[CHAT_MODE.OFF][keys[CHAT_MODE.OFF].secondary]
    local secondaryKeybind = Keybind.defaultKeybinds[secondaryIndex]
    perror(string.format("Default secondary key (Chat Mode Off) assigned to [%s: %s] is already in use by [%s: %s]",
      category, action, secondaryKeybind.category, secondaryKeybind.action))
    return
  end

  if keys[CHAT_MODE.ON].primary then
    Keybind.defaultKeys[CHAT_MODE.ON][keys[CHAT_MODE.ON].primary] = index
  end

  if keys[CHAT_MODE.OFF].primary then
    Keybind.defaultKeys[CHAT_MODE.OFF][keys[CHAT_MODE.OFF].primary] = index
  end

  Keybind.defaultKeybinds[index] = {
    category = category,
    action = action,
    keys = keys,
    alone = alone
  }

  if keys[CHAT_MODE.ON].secondary then
    Keybind.defaultKeys[CHAT_MODE.ON][keys[CHAT_MODE.ON].secondary] = index
  end
  if keys[CHAT_MODE.OFF].secondary then
    Keybind.defaultKeys[CHAT_MODE.OFF][keys[CHAT_MODE.OFF].secondary] = index
  end
end

function Keybind.delete(category, action)
  local index = category .. '_' .. action
  local keybind = Keybind.defaultKeybinds[index]

  if not keybind then
    return
  end

  Keybind.unbind(category, action)

  local keysOn = keybind.keys[CHAT_MODE.ON]
  local keysOff = keybind.keys[CHAT_MODE.OFF]

  local primaryOn = keysOn.primary and tostring(keysOn.primary) or nil
  local primaryOff = keysOff.primary and tostring(keysOff.primary) or nil
  local secondaryOn = keysOn.secondary and tostring(keysOn.secondary) or nil
  local secondaryOff = keysOff.secondary and tostring(keysOff.secondary) or nil

  if primaryOn and primaryOn:len() > 0 then
    Keybind.defaultKeys[CHAT_MODE.ON][primaryOn] = nil
  end
  if secondaryOn and secondaryOn:len() > 0 then
    Keybind.defaultKeys[CHAT_MODE.ON][secondaryOn] = nil
  end

  if primaryOff and primaryOff:len() > 0 then
    Keybind.defaultKeys[CHAT_MODE.OFF][primaryOff] = nil
  end
  if secondaryOff and secondaryOff:len() > 0 then
    Keybind.defaultKeys[CHAT_MODE.OFF][secondaryOff] = nil
  end

  Keybind.defaultKeybinds[index] = nil
end

function Keybind.bind(category, action, callbacks, widget)
  local index = category .. '_' .. action
  local keybind = Keybind.defaultKeybinds[index]

  if not keybind then
    return
  end

  keybind.callbacks = callbacks
  keybind.widget = widget

  local keys = Keybind.getKeybindKeys(category, action)

  for _, callback in ipairs(keybind.callbacks) do
    if callback.type == KEY_UP then
      if keys.primary then
        keys.primary = tostring(keys.primary)
        if keys.primary:len() > 0 then
          g_keyboard.bindKeyUp(keys.primary, callback.callback, keybind.widget, callback.alone)
        end
      end
      if keys.secondary then
        keys.secondary = tostring(keys.secondary)
        if keys.secondary:len() > 0 then
          g_keyboard.bindKeyUp(keys.secondary, callback.callback, keybind.widget, callback.alone)
        end
      end
    elseif callback.type == KEY_DOWN then
      if keys.primary then
        keys.primary = tostring(keys.primary)
        if keys.primary:len() > 0 then
          g_keyboard.bindKeyDown(keys.primary, callback.callback, keybind.widget, callback.alone)
        end
      end
      if keys.secondary then
        keys.secondary = tostring(keys.secondary)
        if keys.secondary:len() > 0 then
          g_keyboard.bindKeyDown(keys.secondary, callback.callback, keybind.widget, callback.alone)
        end
      end
    elseif callback.type == KEY_PRESS then
      if keys.primary then
        keys.primary = tostring(keys.primary)
        if keys.primary:len() > 0 then
          g_keyboard.bindKeyPress(keys.primary, callback.callback, keybind.widget)
        end
      end
      if keys.secondary then
        keys.secondary = tostring(keys.secondary)
        if keys.secondary:len() > 0 then
          g_keyboard.bindKeyPress(keys.secondary, callback.callback, keybind.widget)
        end
      end
    end
  end
end

function Keybind.unbind(category, action)
  local index = category .. '_' .. action
  local keybind = Keybind.defaultKeybinds[index]

  if not keybind or not keybind.callbacks then
    return
  end

  local keys = Keybind.getKeybindKeys(category, action)

  for _, callback in ipairs(keybind.callbacks) do
    if callback.type == KEY_UP then
      if keys.primary then
        keys.primary = tostring(keys.primary)
        if keys.primary:len() > 0 then
          g_keyboard.unbindKeyUp(keys.primary, callback.callback, keybind.widget)
        end
      end
      if keys.secondary then
        keys.secondary = tostring(keys.secondary)
        if keys.secondary:len() > 0 then
          g_keyboard.unbindKeyUp(keys.secondary, callback.callback, keybind.widget)
        end
      end
    elseif callback.type == KEY_DOWN then
      if keys.primary then
        keys.primary = tostring(keys.primary)
        if keys.primary:len() > 0 then
          g_keyboard.unbindKeyDown(keys.primary, callback.callback, keybind.widget)
        end
      end
      if keys.secondary then
        keys.secondary = tostring(keys.secondary)
        if keys.secondary:len() > 0 then
          g_keyboard.unbindKeyDown(keys.secondary, callback.callback, keybind.widget)
        end
      end
    elseif callback.type == KEY_PRESS then
      if keys.primary then
        keys.primary = tostring(keys.primary)
        if keys.primary:len() > 0 then
          g_keyboard.unbindKeyPress(keys.primary, callback.callback, keybind.widget)
        end
      end
      if keys.secondary then
        keys.secondary = tostring(keys.secondary)
        if keys.secondary:len() > 0 then
          g_keyboard.unbindKeyPress(keys.secondary, callback.callback, keybind.widget)
        end
      end
    end
  end
end

function Keybind.newPreset(presetName)
  if Keybind.presetToIndex[presetName] then
    return
  end

  table.insert(Keybind.presets, presetName)
  Keybind.presetToIndex[presetName] = #Keybind.presets

  Keybind.configs.keybinds[presetName] = g_configs.create("/controls/keybinds/" .. presetName .. ".otml")
  Keybind.configs.hotkeys[presetName] = g_configs.create("/controls/hotkeys/" .. presetName .. ".otml")

  Keybind.hotkeys[CHAT_MODE.ON][presetName] = {}
  Keybind.hotkeys[CHAT_MODE.OFF][presetName] = {}

  g_settings.setList("controls-presets", Keybind.presets)
  g_settings.save()
end

function Keybind.copyPreset(fromPreset, toPreset)
  if Keybind.presetToIndex[toPreset] then
    return false
  end

  table.insert(Keybind.presets, toPreset)
  Keybind.presetToIndex[toPreset] = #Keybind.presets

  Keybind.configs.keybinds[fromPreset]:save()
  Keybind.configs.hotkeys[fromPreset]:save()

  local keybindsConfigPath = Keybind.configs.keybinds[fromPreset]:getFileName()
  local keybindsConfigContent = g_resources.readFileContents(keybindsConfigPath)
  g_resources.writeFileContents("/controls/keybinds/" .. toPreset .. ".otml", keybindsConfigContent)
  Keybind.configs.keybinds[toPreset] = g_configs.create("/controls/keybinds/" .. toPreset .. ".otml")

  local hotkeysConfigPath = Keybind.configs.hotkeys[fromPreset]:getFileName()
  local hotkeysConfigContent = g_resources.readFileContents(hotkeysConfigPath)
  g_resources.writeFileContents("/controls/hotkeys/" .. toPreset .. ".otml", hotkeysConfigContent)
  Keybind.configs.hotkeys[toPreset] = g_configs.create("/controls/hotkeys/" .. toPreset .. ".otml")

  for chatMode = CHAT_MODE.ON, CHAT_MODE.OFF do
    Keybind.hotkeys[chatMode][toPreset] = {}

    local hotkeyId = 1
    local hotkeys = Keybind.configs.hotkeys[toPreset]:getNode(chatMode)

    if hotkeys then
      local hotkey = hotkeys[tostring(hotkeyId)]
      while hotkey do
        if hotkey.data.parameter then
          hotkey.data.parameter = "\"" .. hotkey.data.parameter .. "\"" -- forcing quotes cause OTML is not saving them, just wow
        end

        table.insert(Keybind.hotkeys[chatMode][toPreset], normalizeHotkey(hotkey))
        hotkeyId = hotkeyId + 1

        hotkey = hotkeys[tostring(hotkeyId)]
      end
    end
  end

  g_settings.setList("controls-presets", Keybind.presets)
  g_settings.save()

  return true
end

function Keybind.renamePreset(oldPresetName, newPresetName)
  if Keybind.currentPreset == oldPresetName then
    Keybind.currentPreset = newPresetName
  end

  local index = Keybind.presetToIndex[oldPresetName]
  Keybind.presetToIndex[oldPresetName] = nil
  Keybind.presetToIndex[newPresetName] = index
  Keybind.presets[index] = newPresetName

  local keybindsConfigPath = Keybind.configs.keybinds[oldPresetName]:getFileName()
  Keybind.configs.keybinds[oldPresetName]:save()
  Keybind.configs.keybinds[oldPresetName] = nil

  local keybindsConfigContent = g_resources.readFileContents(keybindsConfigPath)
  g_resources.deleteFile(keybindsConfigPath)
  g_resources.writeFileContents("/controls/keybinds/" .. newPresetName .. ".otml", keybindsConfigContent)
  Keybind.configs.keybinds[newPresetName] = g_configs.create("/controls/keybinds/" .. newPresetName .. ".otml")

  local hotkeysConfigPath = Keybind.configs.hotkeys[oldPresetName]:getFileName()
  Keybind.configs.hotkeys[oldPresetName]:save()
  Keybind.configs.hotkeys[oldPresetName] = nil

  local hotkeysConfigContent = g_resources.readFileContents(hotkeysConfigPath)
  g_resources.deleteFile(hotkeysConfigPath)
  g_resources.writeFileContents("/controls/hotkeys/" .. newPresetName .. ".otml", hotkeysConfigContent)
  Keybind.configs.hotkeys[newPresetName] = g_configs.create("/controls/hotkeys/" .. newPresetName .. ".otml")

  Keybind.hotkeys[CHAT_MODE.ON][newPresetName] = Keybind.hotkeys[CHAT_MODE.ON][oldPresetName]
  Keybind.hotkeys[CHAT_MODE.OFF][newPresetName] = Keybind.hotkeys[CHAT_MODE.OFF][oldPresetName]

  g_settings.setList("controls-presets", Keybind.presets)
  g_settings.save()
end

function Keybind.removePreset(presetName)
  if #Keybind.presets == 1 then
    return false
  end

  table.remove(Keybind.presets, Keybind.presetToIndex[presetName])
  Keybind.presetToIndex[presetName] = nil

  Keybind.configs.keybinds[presetName] = nil
  g_configs.unload("/controls/keybinds/" .. presetName .. ".otml")
  g_resources.deleteFile("/controls/keybinds/" .. presetName .. ".otml")

  Keybind.configs.hotkeys[presetName] = nil
  g_configs.unload("/controls/hotkeys/" .. presetName .. ".otml")
  g_resources.deleteFile("/controls/hotkeys/" .. presetName .. ".otml")

  if Keybind.currentPreset == presetName then
    Keybind.currentPreset = Keybind.presets[1]
  end

  g_settings.setList("controls-presets", Keybind.presets)
  g_settings.save()

  return true
end

function Keybind.selectPreset(presetName)
  if Keybind.currentPreset == presetName then
    return false
  end

  if not Keybind.presetToIndex[presetName] then
    return false
  end

  for _, keybind in pairs(Keybind.defaultKeybinds) do
    if keybind.callbacks then
      Keybind.unbind(keybind.category, keybind.action)
    end
  end

  for _, hotkey in ipairs(Keybind.hotkeys[Keybind.chatMode][Keybind.currentPreset]) do
    Keybind.unbindHotkey(hotkey.hotkeyId, Keybind.chatMode)
  end

  Keybind.currentPreset = presetName

  for _, keybind in pairs(Keybind.defaultKeybinds) do
    if keybind.callbacks then
      Keybind.bind(keybind.category, keybind.action, keybind.callbacks, keybind.widget)
    end
  end

  for _, hotkey in ipairs(Keybind.hotkeys[Keybind.chatMode][Keybind.currentPreset]) do
    Keybind.bindHotkey(hotkey.hotkeyId, Keybind.chatMode)
  end

  return true
end

function Keybind.getAction(category, action)
  local index = category .. '_' .. action
  return Keybind.defaultKeybinds[index]
end

function Keybind.setPrimaryActionKey(category, action, preset, keyCombo, chatMode)
  local index = category .. '_' .. action
  local keybind = Keybind.defaultKeybinds[index]

  if keyCombo and type(keyCombo) == "string" and keyCombo:len() > 0 then
    keyCombo = retranslateKeyComboDesc(keyCombo)
  end

  local numericChatMode = chatMode
  chatMode = tostring(chatMode)

  local keys = Keybind.configs.keybinds[preset]:getNode(index)
  if not keys then
    keys = {}
    for k, v in pairs(keybind.keys) do
      keys[tostring(k)] = table.recursivecopy(v)
    end
  end

  if keybind.callbacks then
    Keybind.unbind(category, action)
  end

  if not keys[chatMode] then
    keys[chatMode] = { primary = keyCombo, secondary = keybind.keys[numericChatMode].secondary }
  end

  keys[chatMode].primary = keyCombo

  local ret = false
  if keys[chatMode].secondary == keyCombo then
    keys[chatMode].secondary = nil
    ret = true
  end

  Keybind.configs.keybinds[preset]:setNode(index, keys)

  if keybind.callbacks then
    Keybind.bind(category, action, keybind.callbacks, keybind.widget)
  end

  signalcall(Keybind.onBind, category, action)
  return ret
end

function Keybind.setSecondaryActionKey(category, action, preset, keyCombo, chatMode)
  local index = category .. '_' .. action
  local keybind = Keybind.defaultKeybinds[index]

  if keyCombo and type(keyCombo) == "string" and keyCombo:len() > 0 then
    keyCombo = retranslateKeyComboDesc(keyCombo)
  end

  local numericChatMode = chatMode
  chatMode = tostring(chatMode)

  local keys = Keybind.configs.keybinds[preset]:getNode(index)
  if not keys then
    keys = {}
    for k, v in pairs(keybind.keys) do
      keys[tostring(k)] = table.recursivecopy(v)
    end
  end

  if keybind.callbacks then
    Keybind.unbind(category, action)
  end

  if not keys[chatMode] then
    keys[chatMode] = { primary = keybind.keys[numericChatMode].primary, secondary = keyCombo }
  end

  keys[chatMode].secondary = keyCombo

  local ret = false
  if keys[chatMode].primary == keyCombo then
    keys[chatMode].primary = nil
    ret = true
  end

  Keybind.configs.keybinds[preset]:setNode(index, keys)

  if keybind.callbacks then
    Keybind.bind(category, action, keybind.callbacks, keybind.widget)
  end

  signalcall(Keybind.onBind, category, action)
  return ret
end

function Keybind.resetKeybindsToDefault(presetName, chatMode)
  if not chatMode then
    chatMode = Keybind.chatMode
  end

  for _, keybind in pairs(Keybind.defaultKeybinds) do
    if keybind.callbacks then
      Keybind.unbind(keybind.category, keybind.action)
    end
  end

  for _, keybind in pairs(Keybind.defaultKeybinds) do
    local index = keybind.category .. '_' .. keybind.action
    Keybind.configs.keybinds[presetName]:setNode(index, keybind.keys)
  end

  for _, keybind in pairs(Keybind.defaultKeybinds) do
    if keybind.callbacks then
      Keybind.bind(keybind.category, keybind.action, keybind.callbacks, keybind.widget)
    end
  end
end

function Keybind.getKeybindKeys(category, action, chatMode, preset, forceDefault)
  if not chatMode then
    chatMode = Keybind.chatMode
  end

  local index = category .. '_' .. action
  local keybind = Keybind.defaultKeybinds[index]
  local keys = Keybind.configs.keybinds[preset or Keybind.currentPreset]:getNode(index)

  if not keys or forceDefault then
    keys = {
      primary = keybind.keys[chatMode].primary,
      secondary = keybind.keys[chatMode].secondary
    }
  else
    keys = keys[tostring(chatMode)] or keys[chatMode]
  end

  if not keys then
    keys = {
      primary = "",
      secondary = ""
    }
  end

  return keys
end

function Keybind.isKeyComboUsed(keyCombo, category, action, chatMode)
  local ignore = (category and action) and { category = category, action = action } or nil
  return Keybind.findKeyUser(keyCombo, chatMode, ignore) ~= nil
end

function Keybind.newHotkey(action, data, primary, secondary, chatMode)
  if not chatMode then
    chatMode = Keybind.chatMode
  end

  local hotkey = normalizeHotkey({
    action = action,
    data = data,
    primary = primary and primary:len() > 0 and retranslateKeyComboDesc(primary) or "",
    secondary = secondary and secondary:len() > 0 and retranslateKeyComboDesc(secondary) or ""
  })

  if not Keybind.hotkeys[chatMode][Keybind.currentPreset] then
    Keybind.hotkeys[chatMode][Keybind.currentPreset] = {}
  end

  table.insert(Keybind.hotkeys[chatMode][Keybind.currentPreset], hotkey)

  local hotkeyId = #Keybind.hotkeys[chatMode][Keybind.currentPreset]
  hotkey.hotkeyId = hotkeyId
  saveHotkeys(Keybind.currentPreset, chatMode)

  Keybind.bindHotkey(hotkeyId, chatMode)
  signalcall(Keybind.onHotkeysChange)
  return hotkeyId
end

function Keybind.removeHotkey(hotkeyId, chatMode)
  if not chatMode then
    chatMode = Keybind.chatMode
  end

  if not Keybind.hotkeys[chatMode][Keybind.currentPreset] then
    return
  end

  local list = Keybind.hotkeys[chatMode][Keybind.currentPreset]
  for _, hotkey in ipairs(list) do
    Keybind.unbindHotkey(hotkey.hotkeyId, chatMode)
  end

  table.remove(list, hotkeyId)
  for id, hotkey in ipairs(list) do
    hotkey.hotkeyId = id
  end
  saveHotkeys(Keybind.currentPreset, chatMode)

  for _, hotkey in ipairs(list) do
    Keybind.bindHotkey(hotkey.hotkeyId, chatMode)
  end
  signalcall(Keybind.onHotkeysChange)
end

function Keybind.editHotkey(hotkeyId, action, data, chatMode)
  if not chatMode then
    chatMode = Keybind.chatMode
  end

  Keybind.unbindHotkey(hotkeyId, chatMode)

  local hotkey = Keybind.hotkeys[chatMode][Keybind.currentPreset][hotkeyId]
  hotkey.action = action
  hotkey.data = data
  normalizeHotkey(hotkey)
  saveHotkeys(Keybind.currentPreset, chatMode)

  Keybind.bindHotkey(hotkeyId, chatMode)
  signalcall(Keybind.onHotkeysChange)
end

function Keybind.editHotkeyKeys(hotkeyId, primary, secondary, chatMode)
  if not chatMode then
    chatMode = Keybind.chatMode
  end

  Keybind.unbindHotkey(hotkeyId, chatMode)

  local hotkey = Keybind.hotkeys[chatMode][Keybind.currentPreset][hotkeyId]
  if primary ~= nil then
    primary = tostring(primary)
    if primary:len() > 0 then
      primary = retranslateKeyComboDesc(primary)
    end
  end
  if secondary ~= nil then
    secondary = tostring(secondary)
    if secondary:len() > 0 then
      secondary = retranslateKeyComboDesc(secondary)
    end
  end
  hotkey.primary = primary or ""
  hotkey.secondary = secondary or ""
  saveHotkeys(Keybind.currentPreset, chatMode)

  Keybind.bindHotkey(hotkeyId, chatMode)
  signalcall(Keybind.onHotkeysChange)
end

function Keybind.removeAllHotkeys(chatMode)
  if not chatMode then
    chatMode = Keybind.chatMode
  end

  for _, hotkey in ipairs(Keybind.hotkeys[chatMode][Keybind.currentPreset]) do
    Keybind.unbindHotkey(hotkey.hotkeyId, chatMode)
  end

  Keybind.hotkeys[chatMode][Keybind.currentPreset] = {}

  Keybind.configs.hotkeys[Keybind.currentPreset]:remove(chatMode)
  Keybind.configs.hotkeys[Keybind.currentPreset]:save()
end

function Keybind.getHotkeyKeys(hotkeyId, preset, chatMode)
  if not chatMode then
    chatMode = Keybind.chatMode
  end
  if not preset then
    preset = Keybind.currentPreset
  end

  local keys = { primary = "", secondary = "" }
  if not Keybind.hotkeys[chatMode][preset] then
    return keys
  end

  local hotkey = Keybind.hotkeys[chatMode][preset][hotkeyId]
  if not hotkey then
    return keys
  end

  return { primary = hotkey.primary or "", secondary = hotkey.secondary or "" }
end

function Keybind.hotkeyCallback(hotkeyId, chatMode)
  if not chatMode then
    chatMode = Keybind.chatMode
  end

  local hotkey = Keybind.hotkeys[chatMode][Keybind.currentPreset][hotkeyId]

  if not hotkey then
    return
  end

  if modules.game_hotkeys and modules.game_hotkeys.areHotkeysDisabled and modules.game_hotkeys.areHotkeysDisabled() then
    return
  end

  local action = hotkey.action
  local data = hotkey.data

  if data.itemId then
    local delay = modules.client_options and modules.client_options.getOption('hotkeyDelay') or 0
    if g_clock.millis() - (Keybind.lastItemHotkey or 0) < (tonumber(delay) or 0) then
      return
    end
    Keybind.lastItemHotkey = g_clock.millis()
  end

  if action == HOTKEY_ACTION.USE_POKEMON then
    local player = g_game.getLocalPlayer()
    local pos = player and player:getPosition()
    if not pos then
      return
    end
    for _, creature in ipairs(g_map.getSpectators(pos, false)) do
      if creature:isLocalPlayerSummon() then
        if data.subType then
          local item = g_game.findPlayerItem(data.itemId, data.subType)
          if item then
            g_game.useWith(item, creature)
          end
        else
          g_game.useInventoryItemWith(data.itemId, creature)
        end
        return
      end
    end
    modules.game_textmessage.displayFailureMessage(tr('Call a Pokemon out first.'))
  elseif action == HOTKEY_ACTION.USE_YOURSELF then
    if g_game.getClientVersion() < 780 then
      local item = g_game.findPlayerItem(data.itemId, data.subType or -1)

      if item then
        g_game.useWith(item, g_game.getLocalPlayer())
      end
    else
      g_game.useInventoryItemWith(data.itemId, g_game.getLocalPlayer(), data.subType or -1)
    end
  elseif action == HOTKEY_ACTION.USE_CROSSHAIR then
    local item = Item.create(data.itemId)

    if g_game.getClientVersion() < 780 then
      item = g_game.findPlayerItem(data.itemId, data.subType or -1)
    end

    if item then
      modules.game_interface.startUseWith(item, data.subType or -1)
    end
  elseif action == HOTKEY_ACTION.USE_TARGET then
    local attackingCreature = g_game.getAttackingCreature()
    if not attackingCreature then
      local item = Item.create(data.itemId)

      if g_game.getClientVersion() < 780 then
        item = g_game.findPlayerItem(data.itemId, data.subType or -1)
      end

      if item then
        modules.game_interface.startUseWith(item, data.subType or -1)
      end

      return
    end

    if attackingCreature:getTile() then
      if g_game.getClientVersion() < 780 then
        local item = g_game.findPlayerItem(data.itemId, data.subType or -1)
        if item then
          g_game.useWith(item, attackingCreature, data.subType or -1)
        end
      else
        g_game.useInventoryItemWith(data.itemId, attackingCreature, data.subType or -1)
      end
    end
  elseif action == HOTKEY_ACTION.EQUIP then
    if g_game.getClientVersion() >= 910 then
      local item = Item.create(data.itemId)

      g_game.equipItem(item)
    end
  elseif action == HOTKEY_ACTION.USE then
    if g_game.getClientVersion() < 780 then
      local item = g_game.findPlayerItem(data.itemId, data.subType or -1)

      if item then
        g_game.use(item)
      end
    else
      g_game.useInventoryItem(data.itemId)
    end
  elseif action == HOTKEY_ACTION.TEXT then
    if modules.game_interface.isChatVisible() then
      modules.game_console.setTextEditText(hotkey.data.text)
    end
  elseif action == HOTKEY_ACTION.TEXT_AUTO then
    if modules.game_interface.isChatVisible() then
      modules.game_console.sendMessage(hotkey.data.text)
    else
      g_game.talk(hotkey.data.text)
    end
  elseif action == HOTKEY_ACTION.SPELL then
    local text = data.words
    if data.parameter then
      text = text .. " " .. data.parameter
    end

    if modules.game_interface.isChatVisible() then
      modules.game_console.sendMessage(text)
    else
      g_game.talk(text)
    end
  end
end

function Keybind.bindHotkey(hotkeyId, chatMode)
  if not chatMode or chatMode ~= Keybind.chatMode then
    return
  end

  if not modules.game_interface then
    return
  end

  local hotkey = Keybind.hotkeys[chatMode][Keybind.currentPreset][hotkeyId]

  if not hotkey then
    return
  end

  local keys = Keybind.getHotkeyKeys(hotkeyId, Keybind.currentPreset, chatMode)
  local gameRootPanel = modules.game_interface.getRootPanel()
  local action = hotkey.action

  hotkey.callback = function() Keybind.hotkeyCallback(hotkeyId, chatMode) end

  if keys.primary then
    keys.primary = tostring(keys.primary)
    if keys.primary:len() > 0 then
      if usesKeyDown(action) then
        g_keyboard.bindKeyDown(keys.primary, hotkey.callback, gameRootPanel)
      else
        g_keyboard.bindKeyPress(keys.primary, hotkey.callback, gameRootPanel)
      end
    end
  end

  if keys.secondary then
    keys.secondary = tostring(keys.secondary)
    if keys.secondary:len() > 0 then
      if usesKeyDown(action) then
        g_keyboard.bindKeyDown(keys.secondary, hotkey.callback, gameRootPanel)
      else
        g_keyboard.bindKeyPress(keys.secondary, hotkey.callback, gameRootPanel)
      end
    end
  end
end

function Keybind.unbindHotkey(hotkeyId, chatMode)
  if not chatMode or chatMode ~= Keybind.chatMode then
    return
  end

  if not modules.game_interface then
    return
  end

  local hotkey = Keybind.hotkeys[chatMode][Keybind.currentPreset][hotkeyId]

  if not hotkey then
    return
  end

  local keys = Keybind.getHotkeyKeys(hotkeyId, Keybind.currentPreset, chatMode)
  local gameRootPanel = modules.game_interface.getRootPanel()
  local action = hotkey.action

  if keys.primary then
    keys.primary = tostring(keys.primary)
    if keys.primary:len() > 0 then
      if usesKeyDown(action) then
        g_keyboard.unbindKeyDown(keys.primary, hotkey.callback, gameRootPanel)
      else
        g_keyboard.unbindKeyPress(keys.primary, hotkey.callback, gameRootPanel)
      end
    end
  end

  if keys.secondary then
    keys.secondary = tostring(keys.secondary)
    if keys.secondary:len() > 0 then
      if usesKeyDown(action) then
        g_keyboard.unbindKeyDown(keys.secondary, hotkey.callback, gameRootPanel)
      else
        g_keyboard.unbindKeyPress(keys.secondary, hotkey.callback, gameRootPanel)
      end
    end
  end
end

function Keybind.setChatMode(chatMode)
  if Keybind.chatMode == chatMode then
    return
  end

  for _, keybind in pairs(Keybind.defaultKeybinds) do
    if keybind.callbacks then
      Keybind.unbind(keybind.category, keybind.action)
    end
  end

  for _, hotkey in ipairs(Keybind.hotkeys[Keybind.chatMode][Keybind.currentPreset]) do
    Keybind.unbindHotkey(hotkey.hotkeyId, Keybind.chatMode)
  end

  if modules.game_walking then
    modules.game_walking.unbindTurnKeys()
  end

  Keybind.chatMode = chatMode

  for _, keybind in pairs(Keybind.defaultKeybinds) do
    if keybind.callbacks then
      Keybind.bind(keybind.category, keybind.action, keybind.callbacks, keybind.widget)
    end
  end

  for _, hotkey in ipairs(Keybind.hotkeys[chatMode][Keybind.currentPreset]) do
    Keybind.bindHotkey(hotkey.hotkeyId, chatMode)
  end

  if modules.game_walking then
    modules.game_walking.bindTurnKeys()
  end
end

-- PokeVerse: what a key does now in a chat mode, for clash warnings. ignore = { category, action }
-- or { hotkeyId } leaves out the entry being edited. Returns nil when the key is free.
function Keybind.findKeyUser(keyCombo, chatMode, ignore)
  if not keyCombo or keyCombo == "" then
    return nil
  end
  chatMode = chatMode or Keybind.chatMode
  ignore = ignore or {}
  if Keybind.reservedKeys[keyCombo] then
    return { type = "reserved" }
  end
  for _, keybind in pairs(Keybind.defaultKeybinds) do
    if not (keybind.category == ignore.category and keybind.action == ignore.action) then
      local keys = Keybind.getKeybindKeys(keybind.category, keybind.action, chatMode, Keybind.currentPreset)
      for _, slot in ipairs({ "primary", "secondary" }) do
        if keys[slot] and tostring(keys[slot]) == keyCombo then
          return { type = "keybind", category = keybind.category, action = keybind.action, slot = slot }
        end
      end
    end
  end
  for id, hotkey in ipairs(Keybind.hotkeys[chatMode][Keybind.currentPreset] or {}) do
    if id ~= ignore.hotkeyId and not (ignore.uid and hotkey.data.uid == ignore.uid) then
      for _, slot in ipairs({ "primary", "secondary" }) do
        if hotkey[slot] == keyCombo then
          return { type = "hotkey", hotkeyId = id, hotkey = hotkey, slot = slot }
        end
      end
    end
  end
  return nil
end
