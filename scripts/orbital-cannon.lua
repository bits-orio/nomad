-- Orbitalkanone (Prototypen: prototypes/orbital-cannon.lua): Kanonen beschiessen nur den Planeten, in dessen Orbit
-- ihr Schiff steht (seit 1.0.2 wieder, Wunsch des Users: sonst zu stark; von 1.24.1 bis 1.0.1 jeder Planet).
-- Gezielt wird mit der Orbital-Fernsteuerung (Auswahlwerkzeug aus der Schnellleiste, in der Kartenansicht des
-- Planeten): Klick = ein Ziel, Rahmen = jedes gegnerische Militaerziel darin. Die Ziele kommen in eine Warteschlange,
-- jede Kanone feuert alle COOLDOWN Ticks. Ein Orbital-Leuchtsignal zeigt das Ziel und verschwindet beim Schuss.

local achievements = require("scripts.achievements")
local cannon = {}

local CANNON = "ncs-orbital-cannon"
local FLARE = "ncs-orbital-flare"
local TARGETING = "ncs-orbital-targeting"
-- Nachladezeit in Ticks nach einem Schuss, je nach Granate (seit 1.24.1: Orbital-Granate 10 s, Wunsch des Users)
local COOLDOWN = 120       -- Standard (Roboter-Granaten): 2 s
local COOLDOWN_BY_SHELL = {["ncs-orbital-artillery-shell"] = 600, ["ncs-orbital-cluster-shell"] = 1800}

-- Orbital-Clusterbombe: nach dem Haupteinschlag COUNT weitere Orbital-Granaten im Umkreis RADIUS, je STAGGER Ticks
-- nacheinander (gestaffelt ueber die Fallgeschwindigkeit, gleiche Starthoehe)
local CLUSTER = {shell = "ncs-orbital-cluster-shell", projectile = "ncs-orbital-artillery-projectile", COUNT = 12,
  RADIUS = 25, STAGGER = 20}
local MAX_QUEUE = 200      -- Ziele pro Force in der Warteschlange
local FALL_DISTANCE = 60   -- Geschoss startet so weit noerdlich des Ziels (weiter oben ist die Karte evtl. nicht erzeugt)
local FALL_SPEED = 1 / 3   -- Felder pro Tick: 180 Ticks = 3 s bis zum Einschlag

-- Orbitalkanonen der Force auf Schiffen im Orbit des Planeten dieser Oberflaeche (nicht im Flug, nicht anderswo)
local function cannons_of(force, surface)
  local list = {}
  local planet = surface and surface.valid and surface.planet
  if not planet then return list end
  for _, platform in pairs(force.platforms) do
    local location = platform.valid and platform.space_location
    if location and location.name == planet.name and platform.surface then
      for _, entity in pairs(platform.surface.find_entities_filtered{name = CANNON}) do
        table.insert(list, entity)
      end
    end
  end
  return list
end
local function ammo(entity)
  return entity.get_inventory(defines.inventory.artillery_turret_ammo)
end

local function shells_in(cannons)
  local count = 0
  for _, entity in pairs(cannons) do
    local inventory = ammo(entity)
    if inventory then count = count + inventory.get_item_count() end
  end
  return count
end

-- Projektil der Granate (aus ihrem Munitionstyp), sonst das normale Artillerie-Projektil
local function projectile_of(shell_name)
  local item = prototypes.item[shell_name]
  local ammo_type = item and item.get_ammo_type()
  local action = ammo_type and ammo_type.action
  local first = action and action[1]
  local delivery = first and first.action_delivery and first.action_delivery[1]
  return delivery and delivery.projectile or "artillery-projectile"
end

local function fire(entity, target)
  local inventory = ammo(entity)
  if not inventory or inventory.is_empty() then return false end
  local shell
  for _, stack in pairs(inventory.get_contents()) do shell = stack break end
  if not shell then return false end
  inventory.remove{name = shell.name, quality = shell.quality, count = 1}
  storage.orbital_ready_at[entity.unit_number] = game.tick + (COOLDOWN_BY_SHELL[shell.name] or COOLDOWN)

  local surface = game.surfaces[target.surface]
  if not (surface and surface.valid) then return true end
  local position = target.position
  -- Fallzeit: FALL_DISTANCE / FALL_SPEED Ticks (seit 1.24.1 etwa 3 s, Wunsch des Users; vorher 60 / 1 = 1 s)
  surface.create_entity{name = projectile_of(shell.name), position = {position.x, position.y - FALL_DISTANCE},
    target = position, speed = FALL_SPEED, force = entity.force}
  if shell.name == CLUSTER.shell then
    achievements.on_cluster_bomb(entity.force)
    local main_ticks = FALL_DISTANCE / FALL_SPEED
    for i = 1, CLUSTER.COUNT do
      -- gleichmaessig in der Kreisflaeche verteilt
      local angle, distance = math.random() * 2 * math.pi, math.sqrt(math.random()) * CLUSTER.RADIUS
      local spot = {x = position.x + math.cos(angle) * distance, y = position.y + math.sin(angle) * distance}
      surface.create_entity{name = CLUSTER.projectile, position = {spot.x, spot.y - FALL_DISTANCE}, target = spot,
        speed = FALL_DISTANCE / (main_ticks + i * CLUSTER.STAGGER), force = entity.force}
    end
  end
  local reveal = shell.name == CLUSTER.shell and CLUSTER.RADIUS + 16 or 16
  entity.force.chart(surface, {{position.x - reveal, position.y - reveal}, {position.x + reveal, position.y + reveal}})
  if target.flare and target.flare.valid then target.flare.destroy() end
  if prototypes.entity["artillery-cannon-muzzle-flash"] then
    -- Gerichtete Explosion, braucht ein Ziel: nach oben
    entity.surface.create_entity{name = "artillery-cannon-muzzle-flash", position = entity.position,
      target = {entity.position.x, entity.position.y - 5}}
  end
  return true
end

-- Ziele in die Warteschlange der Force (auch fuer Tests per Remote). Gibt die Anzahl zurueck.
function cannon.enqueue(force, surface, positions, flare)
  local queue = storage.orbital_queue[force.index] or {}
  storage.orbital_queue[force.index] = queue
  local added = 0
  for _, position in pairs(positions) do
    if #queue >= MAX_QUEUE then break end
    table.insert(queue, {surface = surface.index, position = {x = position.x or position[1], y = position.y or position[2]},
      flare = flare})
    added = added + 1
  end
  return added
end

-- Leuchtsignal nur zur Anzeige des Ziels (die Kanone schiesst auf die Position in der Warteschlange)
local function create_flare(surface, position, force)
  return surface.create_entity{name = FLARE, position = position, force = force, movement = {0, 0}, height = 0,
    vertical_speed = 0, frame_speed = 1}
end

-- Orbital-Fernsteuerung (Auswahlwerkzeug): Klick = ein Ziel, Rahmen = jedes gegnerische Militaerziel darin.
-- Geht in der Kartenansicht eines Planeten, ueber dem ein Schiff mit Orbitalkanone steht, ohne Reichweite.
function cannon.on_player_selected_area(event)
  if event.item ~= TARGETING then return end
  local player = game.get_player(event.player_index)
  local surface = event.surface
  if not (player and surface and surface.valid) then return end
  if not surface.planet or surface.platform then
    player.print({"ncs-cannon.not-planet"})
    return
  end
  local force = player.force
  local cannons = cannons_of(force, surface)
  if #cannons == 0 then
    player.print({"ncs-cannon.no-cannon", "[planet=" .. surface.planet.name .. "]"})
    return
  end
  if shells_in(cannons) == 0 then
    player.print({"ncs-cannon.no-shells"})
    return
  end

  local area = event.area
  local width, height = area.right_bottom.x - area.left_top.x, area.right_bottom.y - area.left_top.y
  local positions = {}
  if width < 2 and height < 2 then
    positions[1] = {x = (area.left_top.x + area.right_bottom.x) / 2, y = (area.left_top.y + area.right_bottom.y) / 2}
  else
    local enemies = {}
    for _, other in pairs(game.forces) do
      if force.is_enemy(other) then table.insert(enemies, other) end
    end
    for _, entity in pairs(surface.find_entities_filtered{area = area, force = enemies, is_military_target = true,
        type = {"unit-spawner", "turret", "ammo-turret", "electric-turret", "fluid-turret", "artillery-turret"}}) do
      table.insert(positions, entity.position)
    end
    if #positions == 0 then
      player.print({"ncs-cannon.no-target"})
      return
    end
  end

  local queue = storage.orbital_queue[force.index] or {}
  local added = 0
  for _, position in pairs(positions) do
    if #queue + added >= MAX_QUEUE then break end
    cannon.enqueue(force, surface, {position}, create_flare(surface, position, force))
    added = added + 1
  end
  player.print({"ncs-cannon.queued", added, #cannons})
end
-- Alle 30 Ticks aus control.lua: neue Leuchtsignale aufnehmen, freie Kanonen feuern auf die naechsten Ziele.
function cannon.update()
  local tick = game.tick
  for force_index, queue in pairs(storage.orbital_queue) do
    local force = game.forces[force_index]
    if not force or #queue == 0 then
      storage.orbital_queue[force_index] = nil
    else
      local surface = game.surfaces[queue[1].surface]
      local planet = surface and surface.valid and surface.planet
      if not planet then
        table.remove(queue, 1)
      else
        local any_shells = false
        for _, entity in pairs(cannons_of(force, surface)) do
          local inventory = ammo(entity)
          if inventory and not inventory.is_empty() then any_shells = true end
          local ready = (storage.orbital_ready_at[entity.unit_number] or 0) <= tick
          if ready and queue[1] and queue[1].surface == surface.index and fire(entity, queue[1]) then
            table.remove(queue, 1)
          end
        end
        -- Kein Schiff mehr im Orbit dieses Planeten oder keine Granaten: dessen Ziele verwerfen (samt Leuchtsignalen),
        -- Ziele auf anderen Planeten bleiben
        if not any_shells then
          local dropped = 0
          for i = #queue, 1, -1 do
            if queue[i].surface == surface.index then
              if queue[i].flare and queue[i].flare.valid then queue[i].flare.destroy() end
              table.remove(queue, i)
              dropped = dropped + 1
            end
          end
          force.print({"ncs-cannon.stopped", dropped, "[planet=" .. planet.name .. "]"})
        end
      end
    end
  end
end

-- Leuchtsignal weg (abgelaufen oder nach dem Schuss): Merker entfernen
function cannon.on_object_destroyed(event)
  if storage.orbital_flares then storage.orbital_flares[event.registration_number] = nil end
end

function cannon.init()
  storage.orbital_queue = storage.orbital_queue or {}
  storage.orbital_last_shot = nil -- bis 1.24.0, ersetzt durch orbital_ready_at
  storage.orbital_ready_at = storage.orbital_ready_at or {}
  storage.orbital_flares = storage.orbital_flares or {}
end

return cannon
