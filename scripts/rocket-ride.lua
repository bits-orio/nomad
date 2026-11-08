-- Mit Inventar in die Rakete (seit 1.24.1, Wunsch des Users). Space Age laesst nur mit leerem Inventar in eine
-- Rakete einsteigen; per Prototyp laesst sich das nicht abschalten. Die Taste "ncs-board-rocket" (prototypes/
-- rocket-ride.lua) haengt an "Einsteigen" und kommt vor dem Spiel dran: Steht eine startbereite Rakete in der Naehe,
-- verstaut das Skript Haupt-Inventar, Muell-, Munitions- und Waffen-Plaetze in einem Skript-Inventar. Nach der Ankunft (nicht mehr in der
-- Frachtkapsel) kommt alles zurueck, was nicht passt in den Hub bzw. auf den Boden. Wer doch nicht einsteigt,
-- bekommt das Inventar nach einer Sekunde zurueck.

local rocket_ride = {}

local SILO_RADIUS = 12 -- Abstand Spieler zur Silo-Mitte (Silo 9x9 plus Reichweite zum Einsteigen)
local WAIT = 60 -- Ticks, bis das Inventar zurueckkommt, wenn der Spieler nicht eingestiegen ist
-- Space Age verlangt auch leere Munitions-Plaetze; Waffen kommen sicherheitshalber mit
local INVENTORIES = {defines.inventory.character_main, defines.inventory.character_trash,
  defines.inventory.character_ammo, defines.inventory.character_guns}

local function is_empty(character)
  for _, id in pairs(INVENTORIES) do
    local inventory = character.get_inventory(id)
    if inventory and not inventory.is_empty() then return false end
  end
  return true
end

local function ready_silo_near(character, is_capsule)
  local silos = character.surface.find_entities_filtered{type = "rocket-silo", position = character.position,
    radius = SILO_RADIUS}
  -- Alle Silos inkl. Versorgungskapsel (seit 1.24.1 nimmt auch die Kapsel Spieler mit; is_capsule bleibt im
  -- Aufruf fuer spaetere Unterscheidungen)
  for _, silo in pairs(silos) do
    if silo.rocket_silo_status == defines.rocket_silo_status.rocket_ready then
      return silo
    end
  end
  return nil
end

local function stash(player, character)
  local entry = {player = player, tick = game.tick, inventories = {}}
  for _, id in pairs(INVENTORIES) do
    local inventory = character.get_inventory(id)
    if inventory then
      local saved = game.create_inventory(#inventory)
      for i = 1, #inventory do
        saved[i].transfer_stack(inventory[i])
      end
      entry.inventories[id] = saved
    end
  end
  storage.ride_stash[player.index] = entry
end

-- Einen Stapel ablegen: Inventar, sonst Hub (auf Schiffen), sonst auf den Boden
local function put_back(stack, inventory, slot, character)
  if slot <= #inventory and not inventory[slot].valid_for_read then
    inventory[slot].transfer_stack(stack)
    if not stack.valid_for_read then return end
  end
  local inserted = inventory.insert(stack)
  if inserted >= stack.count then
    stack.clear()
    return
  end
  stack.count = stack.count - inserted
  local platform = character.surface.platform
  local hub = platform and platform.hub
  if hub and hub.valid then
    inserted = hub.insert(stack)
    if inserted >= stack.count then
      stack.clear()
      return
    end
    stack.count = stack.count - inserted
  end
  character.surface.spill_item_stack{position = character.position, stack = stack, allow_belts = false}
  stack.clear()
end

local function restore(entry, character)
  for id, saved in pairs(entry.inventories) do
    local inventory = character.get_inventory(id)
    for i = 1, #saved do
      if saved[i].valid_for_read then
        if inventory then
          put_back(saved[i], inventory, i, character)
        else
          character.surface.spill_item_stack{position = character.position, stack = saved[i], allow_belts = false}
        end
      end
    end
    saved.destroy()
  end
end

-- Taste "Einsteigen" (vor dem Spiel)
function rocket_ride.on_board(event, is_capsule)
  local player = game.get_player(event.player_index)
  rocket_ride.init()
  if not (player and player.valid) or storage.ride_stash[player.index] then return end
  local character = player.character
  if not (character and character.valid) or player.controller_type ~= defines.controllers.character then return end
  if character.surface.platform or player.cargo_pod then return end
  if is_empty(character) then return end
  if not ready_silo_near(character, is_capsule) then return end
  player.clear_cursor()
  stash(player, character)
end

-- Alle 10 Ticks aus control.lua
function rocket_ride.update()
  if not storage.ride_stash then return end -- vor dem ersten Einsteigen in alten Spielstaenden
  for index, entry in pairs(storage.ride_stash) do
    local player = entry.player
    if not player.valid then
      for _, saved in pairs(entry.inventories) do saved.destroy() end
      storage.ride_stash[index] = nil
    elseif player.cargo_pod then
      entry.boarded = true
    else
      local character = player.character
      if character and character.valid and (entry.boarded or game.tick >= entry.tick + WAIT) then
        restore(entry, character)
        storage.ride_stash[index] = nil
      end
    end
  end
end

function rocket_ride.init()
  storage.ride_stash = storage.ride_stash or {}
end

return rocket_ride
