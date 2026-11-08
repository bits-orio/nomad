-- Hub nutzt das Spieler-Inventar (seit 1.24.1, Wunsch des Users). Auf Plattformen baut nur der Hub die Geister,
-- und zwar nur aus seinem eigenen Inventar; Bauroboter im Spieler-Inventar bauen dort nie (Engine).
-- Deshalb legt das Skript fuer Geister fehlende Items aus dem Inventar der Spieler auf dem Schiff (im Hub oder im
-- Raumanzug draussen) in den Hub, genau die fehlende Menge. Den Bau macht danach der Hub wie im Grundspiel.
-- Laeuft nur, solange auf einem Schiff Geister stehen (storage.hub_supply), angestossen beim Setzen von Geistern.

local hub_supply = {}

local GHOST_TYPES = {"entity-ghost", "tile-ghost"}

hub_supply.FILTER = {{filter = "type", type = "entity-ghost"}, {filter = "type", type = "tile-ghost"}}

local function key_of(name, quality)
  return name .. "|" .. quality
end

-- Items, die alle Geister der Plattform brauchen: {key = {name, quality, count}}, nil wenn es keine Geister gibt
local function needed_items(platform)
  local ghosts = platform.surface.find_entities_filtered{type = GHOST_TYPES, force = platform.force}
  if #ghosts == 0 then return nil end
  local needed = {}
  for _, ghost in pairs(ghosts) do
    local items = ghost.ghost_prototype.items_to_place_this
    local item = items and items[1]
    if item then
      local quality = ghost.type == "tile-ghost" and "normal" or ghost.quality.name
      local key = key_of(item.name, quality)
      local entry = needed[key] or {name = item.name, quality = quality, count = 0}
      entry.count = entry.count + (item.count or 1)
      needed[key] = entry
    end
  end
  return needed
end

-- Haupt-Inventare der Spieler, die gerade koerperlich auf dieser Plattform sind
local function player_inventories(platform)
  local inventories = {}
  for _, player in pairs(platform.force.connected_players) do
    local surface = player.physical_surface
    local character = player.character
    if surface and surface.index == platform.surface.index and character and character.valid then
      local inventory = character.get_main_inventory()
      if inventory then table.insert(inventories, inventory) end
    end
  end
  return inventories
end

-- Gibt false zurueck, wenn die Plattform nicht mehr beobachtet werden muss
local function update_platform(platform)
  if not (platform.valid and platform.surface and platform.hub and platform.hub.valid) then return false end
  local inventories = player_inventories(platform)
  if #inventories == 0 then return true end -- niemand an Bord, spaeter wieder pruefen
  local needed = needed_items(platform)
  if not needed then return false end

  local hub = platform.hub
  local hub_inventory = hub.get_inventory(defines.inventory.hub_main)
  if not hub_inventory then return true end
  for _, entry in pairs(needed) do
    local item = {name = entry.name, quality = entry.quality}
    local missing = entry.count - hub_inventory.get_item_count(item)
    for _, inventory in pairs(inventories) do
      if missing <= 0 then break end
      local take = math.min(missing, inventory.get_item_count(item))
      if take > 0 then
        local inserted = hub.insert{name = entry.name, quality = entry.quality, count = take}
        if inserted > 0 then
          inventory.remove{name = entry.name, quality = entry.quality, count = inserted}
          missing = missing - inserted
        end
      end
    end
  end
  return true
end

-- Jede Sekunde aus control.lua
function hub_supply.update_all()
  hub_supply.init() -- Spielstaende, die schon mit dieser Version gespeichert wurden
  for index, platform in pairs(storage.hub_supply) do
    if not update_platform(platform) then storage.hub_supply[index] = nil end
  end
end

-- Geist gesetzt: Plattform beobachten
function hub_supply.on_built(event)
  local entity = event.entity
  if not (entity and entity.valid and (entity.type == "entity-ghost" or entity.type == "tile-ghost")) then return end
  local platform = entity.surface.platform
  hub_supply.init()
  if platform then storage.hub_supply[platform.index] = platform end
end

function hub_supply.init()
  if storage.hub_supply then return end
  storage.hub_supply = {}
  -- Erster Start dieser Version: alle Schiffe einmal pruefen (Geister aus alten Spielstaenden)
  for _, force in pairs(game.forces) do
    for index, platform in pairs(force.platforms) do
      storage.hub_supply[index] = platform
    end
  end
end

return hub_supply
