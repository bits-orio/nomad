-- Hub im Logistik-Netz. Der Hub gehoert in Factorio zu keinem Logistik-Netz (headless geprueft).
-- Deshalb stehen an jedem Hub zwei unsichtbare Kisten (Prototypen in prototypes/space-robots.lua):
--   ncs-hub-storage:  Lager-Kiste. Roboter liefern Ueberschuss und Muell hinein, das Skript legt alles in den Hub.
--   ncs-hub-provider: passive Anbieter-Kiste. Das Skript legt hinein, was im Netz angefordert wird und fehlt
--                     (hoechstens ein Stapel pro Item); was nicht mehr gebraucht wird, geht zurueck in den Hub.
-- Die Kisten gibt es nur, solange ein Roboport den Hub abdeckt (sonst zeigen sie "Keine Verbindung").

local hub_logistics = {}

local STORAGE = "ncs-hub-storage"
local PROVIDER = "ncs-hub-provider"

local function key_of(name, quality)
  return name .. "|" .. quality
end

local function create_chest(platform, name)
  return platform.surface.create_entity{name = name, position = platform.hub.position, force = platform.force,
    create_build_effect_smoke = false}
end

-- Kisten eines Hubs (werden bei Bedarf angelegt)
local function chests_of(platform)
  local entry = storage.hub_chests[platform.index]
  if entry and entry.storage.valid and entry.provider.valid then return entry end
  if entry then
    if entry.storage.valid then entry.storage.destroy() end
    if entry.provider.valid then entry.provider.destroy() end
  end
  entry = {storage = create_chest(platform, STORAGE), provider = create_chest(platform, PROVIDER)}
  if not (entry.storage and entry.provider) then return nil end
  entry.storage.destructible = false
  entry.provider.destructible = false
  storage.hub_chests[platform.index] = entry
  return entry
end

-- Alles aus einem Inventar in den Hub legen (was nicht passt, bleibt liegen)
local function move_to_hub(inventory, hub)
  for _, stack in pairs(inventory.get_contents()) do
    local item = {name = stack.name, quality = stack.quality, count = stack.count}
    local inserted = hub.insert(item)
    if inserted > 0 then
      inventory.remove{name = stack.name, quality = stack.quality, count = inserted}
    end
  end
end

-- Was die Anforderer im Netz noch brauchen: {key = {name, quality, count}}
local function missing_requests(network, own_provider)
  local missing = {}
  for _, point in pairs(network.requester_points) do
    local owner = point.owner
    if owner and owner.valid and owner ~= own_provider then
      for _, filter in pairs(point.filters or {}) do
        if filter.name and filter.count and filter.count > 0 then
          local quality = filter.quality or "normal"
          local have = owner.get_item_count({name = filter.name, quality = quality})
          local need = filter.count - have
          if need > 0 then
            local key = key_of(filter.name, quality)
            local entry = missing[key] or {name = filter.name, quality = quality, count = 0}
            entry.count = entry.count + need
            missing[key] = entry
          end
        end
      end
    end
  end
  return missing
end

-- Kisten entfernen, ihr Inhalt geht zurueck in den Hub
local function remove_chests(platform, hub)
  local entry = storage.hub_chests[platform.index]
  if not entry then return end
  for _, chest in pairs({entry.storage, entry.provider}) do
    if chest.valid then
      move_to_hub(chest.get_inventory(defines.inventory.chest), hub)
      chest.destroy()
    end
  end
  storage.hub_chests[platform.index] = nil
end

local function update_platform(platform)
  local hub = platform.hub
  if not (hub and hub.valid) then return end
  local hub_inventory = hub.get_inventory(defines.inventory.hub_main)
  if not hub_inventory then return end

  -- Die Kisten gibt es nur, solange ein Roboport den Hub abdeckt. Logistik-Kisten ausserhalb eines Netzes
  -- zeigen sonst dauernd das Symbol "Keine Verbindung" am Hub.
  if not platform.surface.find_logistic_network_by_position(hub.position, platform.force) then
    remove_chests(platform, hub)
    return
  end
  local chests = chests_of(platform)
  if not chests then return end

  -- Lager-Kiste in den Hub leeren
  move_to_hub(chests.storage.get_inventory(defines.inventory.chest), hub)

  local provider_inventory = chests.provider.get_inventory(defines.inventory.chest)
  local network = chests.provider.logistic_network
  if not network then
    move_to_hub(provider_inventory, hub)
    return
  end

  -- Soll-Bestand der Anbieter-Kiste: fehlende Anforderungen, hoechstens ein Stapel pro Item
  local wanted = missing_requests(network, chests.provider)
  for key, entry in pairs(wanted) do
    entry.count = math.min(entry.count, prototypes.item[entry.name].stack_size)
  end

  -- Ueberschuss zurueck in den Hub
  for _, stack in pairs(provider_inventory.get_contents()) do
    local key = key_of(stack.name, stack.quality)
    local keep = wanted[key] and wanted[key].count or 0
    if stack.count > keep then
      local item = {name = stack.name, quality = stack.quality, count = stack.count - keep}
      local inserted = hub.insert(item)
      if inserted > 0 then
        provider_inventory.remove{name = stack.name, quality = stack.quality, count = inserted}
      end
    end
  end

  -- Fehlendes aus dem Hub nachlegen
  for _, entry in pairs(wanted) do
    local item = {name = entry.name, quality = entry.quality}
    local present = provider_inventory.get_item_count(item)
    local add = math.min(entry.count - present, hub_inventory.get_item_count(item))
    if add > 0 then
      local inserted = provider_inventory.insert{name = entry.name, quality = entry.quality, count = add}
      if inserted > 0 then
        hub_inventory.remove{name = entry.name, quality = entry.quality, count = inserted}
      end
    end
  end
end

-- Jede Sekunde aus control.lua
function hub_logistics.update_all()
  local alive = {}
  for _, force in pairs(game.forces) do
    for index, platform in pairs(force.platforms) do
      if platform.valid and platform.surface and platform.hub and platform.hub.valid then
        alive[index] = true
        update_platform(platform)
      end
    end
  end
  for index in pairs(storage.hub_chests) do
    if not alive[index] then storage.hub_chests[index] = nil end
  end
end

function hub_logistics.init()
  storage.hub_chests = storage.hub_chests or {}
end

return hub_logistics
