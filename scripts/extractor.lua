-- Boden-Extraktor (Prototypen: prototypes/extractor.lua, Daten: scripts/extractor-config.lua).
--   Fundstellen: entstehen selten beim Erzeugen der Karte neben den passenden Feldern bzw. Lagerstaetten, haeufiger
--     weit weg vom Start. Jede ist 3x3 gross wie der Extraktor; jedes Feld haelt config.RUNS Laeufe.
--   Extraktor: bekommt auf einer Fundstelle selbst das passende Rezept. Er steht still, bis jemand im Fenster auf
--     "Lauf starten" drueckt (Forschung und Zutaten noetig). Ein Lauf dauert config.RUN_SECONDS; danach verbraucht
--     er einen Lauf der Fundstelle und steht wieder still.
--   Das Ergebnis bleibt im Ausgang des Extraktors (seit 1.24.0, vorher direkt zum Schiff gebeamt); abholen und
--   selbst hochschicken. Ein neuer Lauf startet erst, wenn der Ausgang leer ist.
--   Waehrend eines Laufs gilt die Herausforderung des Planeten (siehe CHALLENGES).

local config = require("scripts.extractor-config")
local achievements = require("scripts.achievements")

local extractor = {}

local NAME = config.EXTRACTOR
local GUI = "ncs_extractor"
local START_BUTTON = "ncs_extractor_start"

local BY_ENTITY = {}
local BY_NAME = {}
local PRODUCTS = {}
local CORE_NAMES = {}
local BY_PLANET = {}
for _, core in pairs(config.cores) do
  BY_ENTITY[core.entity] = core
  BY_NAME[core.name] = core
  PRODUCTS[core.product] = true
  table.insert(CORE_NAMES, core.entity)
  BY_PLANET[core.planet] = BY_PLANET[core.planet] or {}
  table.insert(BY_PLANET[core.planet], core)
end

extractor.FILTER = {{filter = "name", name = NAME}, {filter = "ghost_name", name = NAME}}

---------------------------------------------------------------------------
-- Fundstellen erzeugen

local function patch_area(center, extra)
  local r = config.PATCH_RADIUS + 0.5 + (extra or 0)
  return {{center.x - r, center.y - r}, {center.x + r, center.y + r}}
end

-- Ein Ankerpunkt im Chunk, an dem die Fundstelle liegen soll (passendes Feld oder passende Lagerstaette)
local function find_anchor(surface, area, core)
  if core.tiles then
    local tiles = surface.find_tiles_filtered{area = area, name = core.tiles, limit = 50}
    if #tiles > 0 then return tiles[math.random(#tiles)].position end
  else
    local resources = surface.find_entities_filtered{area = area, name = core.resources, limit = 50}
    if #resources > 0 then return resources[math.random(#resources)].position end
  end
  return nil
end

local function all_generated(surface, area)
  for _, corner in pairs({area[1], area[2], {area[1][1], area[2][2]}, {area[2][1], area[1][2]}}) do
    if not surface.is_chunk_generated({math.floor(corner[1] / 32), math.floor(corner[2] / 32)}) then return false end
  end
  return true
end

-- Freien Platz fuer den Extraktor neben dem Ankerpunkt suchen, ohne andere Lagerstaetten darunter.
local function find_spot(surface, anchor)
  for _ = 1, 8 do
    local probe = {x = anchor.x + math.random(-12, 12), y = anchor.y + math.random(-12, 12)}
    local center = surface.find_non_colliding_position(NAME, probe, 10, 1, true)
    if center then
      local area = patch_area(center)
      if all_generated(surface, area) and surface.count_entities_filtered{area = area, type = "resource", limit = 1} == 0 then
        return center
      end
    end
  end
  return nil
end

local function create_patch(surface, center, core)
  local r = config.PATCH_RADIUS
  for dx = -r, r do
    for dy = -r, r do
      surface.create_entity{name = core.entity, position = {center.x + dx, center.y + dy}, amount = core.runs or config.RUNS}
    end
  end
end

local function generate(surface, area, chunk_position)
  local planet = surface.planet
  local cores = planet and BY_PLANET[planet.name]
  if not cores then return end
  local distance = math.sqrt(chunk_position.x ^ 2 + chunk_position.y ^ 2)
  local chance = config.CHANCE * (1 + 2 * math.min(1, distance / config.FAR_CHUNKS))
  for _, core in pairs(cores) do
    if math.random() < chance * (core.chance or 1) then
      local anchor = find_anchor(surface, area, core)
      -- Nicht zu dicht an einer anderen Fundstelle derselben Art
      if anchor and surface.count_entities_filtered{name = core.entity, position = anchor, radius = 96, limit = 1} == 0 then
        local center = find_spot(surface, anchor)
        if center then create_patch(surface, center, core) end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Garantierte Fundstellen: pro Planet und Art mindestens eine im Umkreis um den Landepunkt.
-- Ablauf: Karte im Umkreis erzeugen lassen (laeuft im Hintergrund), dann fehlende Arten an passender Stelle anlegen.

local function chunk_radius(radius) return math.ceil(radius / 32) end

local function register_guarantee(surface)
  if storage.core_guarantee[surface.index] then return end
  if not (surface.planet and BY_PLANET[surface.planet.name]) then return end
  local radius = config.GUARANTEE.RADIUS
  storage.core_guarantee[surface.index] = {radius = radius}
  surface.request_to_generate_chunks({0, 0}, chunk_radius(radius))
end

-- Ist die Karte im Umkreis fertig erzeugt? (Ecken und Kanten pruefen genuegt)
local function area_generated(surface, radius)
  local n = chunk_radius(radius) - 1
  for _, c in pairs({{n, n}, {-n, n}, {n, -n}, {-n, -n}, {0, n}, {0, -n}, {n, 0}, {-n, 0}}) do
    if not surface.is_chunk_generated(c) then return false end
  end
  return true
end

-- Eine Fundstelle dieser Art irgendwo im Umkreis anlegen; true bei Erfolg
local function place_guaranteed(surface, core, radius)
  local g = config.GUARANTEE
  local n = chunk_radius(radius) - 1
  for _ = 1, g.TRIES do
    local cx, cy = math.random(-n, n), math.random(-n, n)
    local distance = math.sqrt(cx * cx + cy * cy) * 32
    if distance >= g.MIN_DISTANCE and distance <= radius and surface.is_chunk_generated({cx, cy}) then
      local area = {{cx * 32, cy * 32}, {cx * 32 + 32, cy * 32 + 32}}
      local anchor = find_anchor(surface, area, core)
      local center = anchor and find_spot(surface, anchor)
      if center then
        create_patch(surface, center, core)
        log("[nomad] Garantierte Fundstelle " .. core.name .. " auf " .. surface.name .. " bei "
          .. serpent.line(center))
        return true
      end
    end
  end
  return false
end

local function process_guarantee(surface, state)
  if not area_generated(surface, state.radius) then return end
  local r = state.radius
  local missing = false
  for _, core in pairs(BY_PLANET[surface.planet.name]) do
    local present = surface.count_entities_filtered{name = core.entity, area = {{-r, -r}, {r, r}}, limit = 1} > 0
    if not present and not place_guaranteed(surface, core, r) then missing = true end
  end
  if missing and r < config.GUARANTEE.MAX_RADIUS then
    state.radius = r + config.GUARANTEE.STEP
    surface.request_to_generate_chunks({0, 0}, chunk_radius(state.radius))
  else
    state.done = true
  end
end

function extractor.process_guarantees()
  for index, state in pairs(storage.core_guarantee) do
    local surface = game.surfaces[index]
    if not (surface and surface.valid) then
      storage.core_guarantee[index] = nil
    elseif not state.done then
      process_guarantee(surface, state)
    end
  end
end

function extractor.on_surface_created(event)
  local surface = game.surfaces[event.surface_index]
  if surface then register_guarantee(surface) end
end

function extractor.on_chunk_generated(event)
  storage.core_scanned[event.surface.index] = true
  register_guarantee(event.surface)
  generate(event.surface, event.area, event.position)
end

-- Fuer Karten, die schon vor dieser Version erzeugt waren: einmal alle erzeugten Chunks durchgehen.
function extractor.scan_existing()
  for _, surface in pairs(game.surfaces) do
    register_guarantee(surface)
    if surface.planet and BY_PLANET[surface.planet.name] and not storage.core_scanned[surface.index] then
      storage.core_scanned[surface.index] = true
      for chunk in surface.get_chunks() do
        if surface.is_chunk_generated(chunk) then
          generate(surface, chunk.area, chunk)
        end
      end
    end
  end
end

---------------------------------------------------------------------------
-- Fundstellen-Scanner: naechste Fundstelle pro Art auf dieser Oberflaeche (nur bereits erzeugte Karte),
-- Pfeil zur naechsten an der Figur, Liste im Chat.

local DIRECTIONS = {"n", "ne", "e", "se", "s", "sw", "w", "nw"}

local function direction_key(from, to)
  -- 0 = Norden, im Uhrzeigersinn (y waechst nach Sueden)
  local angle = math.atan2(to.x - from.x, from.y - to.y)
  local index = math.floor((angle / (2 * math.pi) * 8) + 0.5) % 8 + 1
  return "ncs-scanner.dir-" .. DIRECTIONS[index]
end

function extractor.scan(player)
  local surface = player.surface
  if surface.platform or not (surface.planet and BY_PLANET[surface.planet.name]) then
    player.print({"ncs-scanner.no-planet"})
    return
  end
  local origin = player.position
  local nearest = {} -- Art -> {entity, distance}
  for _, core in pairs(surface.find_entities_filtered{name = CORE_NAMES}) do
    local dx, dy = core.position.x - origin.x, core.position.y - origin.y
    local distance = math.sqrt(dx * dx + dy * dy)
    local best = nearest[core.name]
    if not best or distance < best.distance then nearest[core.name] = {entity = core, distance = distance} end
  end

  local closest
  for _, kind in pairs(BY_PLANET[surface.planet.name]) do
    local found = nearest[kind.entity]
    local label = {"", "[item=" .. kind.product .. "] ", {"item-name." .. kind.product}}
    if found then
      player.print({"ncs-scanner.found", label, math.floor(found.distance), {direction_key(origin, found.entity.position)},
        found.entity.gps_tag})
      if not closest or found.distance < closest.distance then closest = found end
    else
      player.print({"ncs-scanner.none", label})
    end
  end
  if not closest then
    player.print({"ncs-scanner.explore"})
    return
  end
  if player.character then
    rendering.draw_sprite{sprite = "utility/indication_arrow", target = player.character, surface = surface,
      orientation_target = closest.entity.position, oriented_offset = {0, -2.5}, x_scale = 2, y_scale = 2,
      players = {player}, time_to_live = 600}
  end
end

function extractor.on_player_selected_area(event)
  if event.item ~= config.SCANNER then return end
  local player = game.get_player(event.player_index)
  if player then extractor.scan(player) end
end

---------------------------------------------------------------------------
-- Extraktor

local function cores_under(entity)
  return entity.surface.find_entities_filtered{area = entity.bounding_box, name = CORE_NAMES}
end

local function core_kind(cores)
  return cores[1] and BY_ENTITY[cores[1].name] or nil
end

local function runs_left(cores)
  local most = 0
  for _, core in pairs(cores) do most = math.max(most, core.amount) end
  return most
end

local function researched(force, core)
  local technology = force.technologies[core.technology]
  return technology ~= nil and technology.researched
end

local function has_ingredients(entity, core)
  if entity.is_crafting() then return true end
  local input = entity.get_inventory(defines.inventory.crafter_input)
  if not input then return false end
  for _, ingredient in pairs(core.ingredients) do
    if input.get_item_count(ingredient.name) < ingredient.amount then return false end
  end
  return true
end

local function status(entity, diode, label)
  entity.custom_status = {diode = diode, label = label}
end

-- Items, die beim Rezeptwechsel herausfallen, neben den Extraktor legen
local function spill(entity, items)
  for _, stack in pairs(items or {}) do
    entity.surface.spill_item_stack{position = entity.position, stack = stack, enable_looted = true, force = entity.force}
  end
end

local function set_recipe(entity, recipe)
  local current = entity.get_recipe()
  if (current and current.name) == recipe then return end
  spill(entity, entity.set_recipe(recipe))
end

local function deplete(cores)
  for _, core in pairs(cores) do
    if core.valid then
      if core.amount <= 1 then core.destroy() else core.amount = core.amount - 1 end
    end
  end
end

-- Liegen fertige Boeden/Quellen im Ausgang? (Der Schrott der Lawine zaehlt nicht.)
local function product_waiting(entity)
  local output = entity.get_inventory(defines.inventory.crafter_output)
  if not output then return false end
  for _, stack in pairs(output.get_contents()) do
    if PRODUCTS[stack.name] then return true end
  end
  return false
end

-- Lauf verloren: Zutaten des Laufs sind weg, alles andere (Rest im Eingang, Schrott im Ausgang) faellt heraus.
local function fail(entry, core, reason, damage)
  local entity = entry.entity
  local lost = {}
  for _, ingredient in pairs(core.ingredients) do lost[ingredient.name] = ingredient.amount end
  local removed = entity.set_recipe(nil)
  for _, stack in pairs(removed) do
    local drop = stack.count - (lost[stack.name] or 0)
    lost[stack.name] = math.max(0, (lost[stack.name] or 0) - stack.count)
    if drop > 0 then spill(entity, {{name = stack.name, quality = stack.quality, count = drop}}) end
  end
  entry.running = false
  entry.blocked = 0
  entry.heat = 0
  entity.disabled_by_script = true
  entity.surface.create_entity{name = "big-explosion", position = entity.position}
  entity.force.print({"ncs-extractor.failed", reason, entity.gps_tag})
  if damage then entity.damage(damage, "neutral", "explosion") end -- kann ihn zerstoeren, dann ist entity ungueltig
end

local HEAT_ENTITY = NAME .. "-heat"

-- Aquilo: unsichtbarer Waermespeicher unter dem Extraktor (Herausforderung "cold")
local function ensure_heat_entity(entry)
  local entity = entry.entity
  if entry.heat_entity and entry.heat_entity.valid then return entry.heat_entity end
  local planet = entity.surface.planet
  if not (planet and planet.name == "aquilo") then return nil end
  local heat = entity.surface.create_entity{name = HEAT_ENTITY, position = entity.position, force = entity.force,
    create_build_effect_smoke = false}
  if heat then heat.destructible = false end
  entry.heat_entity = heat
  return heat
end

local function destroy_heat_entity(entry)
  if entry and entry.heat_entity and entry.heat_entity.valid then entry.heat_entity.destroy() end
end

local function register(entity)
  local entry = {entity = entity, running = false, finished = entity.products_finished}
  storage.extractors[entity.unit_number] = entry
  entity.disabled_by_script = true
  ensure_heat_entity(entry)
end

local function update(entry)
  local entity = entry.entity
  local cores = cores_under(entity)
  local core = core_kind(cores)
  local waiting = product_waiting(entity)

  if entry.running then
    if entity.products_finished > entry.finished then
      entry.running = false
      entry.finished = entity.products_finished
      entity.disabled_by_script = true
      deplete(cores)
      if core then
        entity.force.print({"ncs-extractor.done", core.count, "[item=" .. core.product .. "]", entity.gps_tag})
        achievements.on_extractor_done(entity, core, entry.started)
      end
      status(entity, defines.entity_status_diode.yellow, {"ncs-extractor.collect"})
      return
    end
    local no_power = entity.status == defines.entity_status.no_power or entity.status == defines.entity_status.low_power
    if not core then
      -- Fundstelle verschwunden (z. B. per Befehl entfernt): Lauf abbrechen
      entry.running = false
      entity.disabled_by_script = true
    elseif no_power then
      status(entity, defines.entity_status_diode.red, {"ncs-extractor.running-no-power", math.floor(entity.crafting_progress * 100)})
      return
    elseif core.challenge == "avalanche" then
      status(entity, defines.entity_status_diode.green, {"ncs-extractor.running-avalanche",
        math.floor(entity.crafting_progress * 100), math.floor(entry.rate or 0)})
      return
    elseif core.challenge == "heat" then
      local diode = (entry.heat or 0) > 50 and defines.entity_status_diode.red
        or (entry.cooling and defines.entity_status_diode.yellow or defines.entity_status_diode.green)
      local key = entry.cooling and ("ncs-extractor.running-heat-" .. entry.cooling) or "ncs-extractor.running-heat"
      local rate = (entry.rate or 0) * (entry.cooling == "steam" and config.HEAT.STEAM_PER_WATER or 1)
      status(entity, diode, {key, math.floor(entity.crafting_progress * 100), math.floor(rate), math.floor(entry.heat or 0)})
      return
    elseif core.challenge == "waves" then
      status(entity, defines.entity_status_diode.green, {"ncs-extractor.running-waves",
        math.floor(entity.crafting_progress * 100), entry.wave or 0, #config.WAVES})
      return
    elseif core.challenge == "cold" then
      local diode = (entry.frost or 0) > 0 and defines.entity_status_diode.yellow or defines.entity_status_diode.green
      if (entry.frost or 0) > 50 then diode = defines.entity_status_diode.red end
      status(entity, diode, {"ncs-extractor.running-cold", math.floor(entity.crafting_progress * 100),
        math.floor(entry.rate or 0), math.floor(entry.temperature or 0), math.floor(entry.frost or 0)})
      return
    elseif core.challenge == "pollution" then
      status(entity, defines.entity_status_diode.green, {"ncs-extractor.running-pollution",
        math.floor(entity.crafting_progress * 100), math.floor(entry.rate or 0), entry.attackers or 0})
      return
    else
      status(entity, defines.entity_status_diode.green,
        {"ncs-extractor.running", math.floor(entity.crafting_progress * 100)})
      return
    end
  end

  entity.disabled_by_script = true
  if not core then
    -- Rezept erst entfernen, wenn das Ergebnis abgeholt ist (sonst fiele es heraus, z. B. nach dem letzten Lauf)
    if waiting then
      status(entity, defines.entity_status_diode.yellow, {"ncs-extractor.collect"})
      return
    end
    set_recipe(entity, nil)
    status(entity, defines.entity_status_diode.red, {"ncs-extractor.no-core"})
    return
  end
  set_recipe(entity, core.recipe)
  if waiting then
    status(entity, defines.entity_status_diode.yellow, {"ncs-extractor.collect"})
  elseif not researched(entity.force, core) then
    status(entity, defines.entity_status_diode.red, {"ncs-extractor.need-research", {"technology-name." .. core.technology}})
  elseif not has_ingredients(entity, core) then
    status(entity, defines.entity_status_diode.yellow, {"ncs-extractor.need-ingredients"})
  else
    status(entity, defines.entity_status_diode.yellow, {"ncs-extractor.ready"})
  end
end

---------------------------------------------------------------------------
-- Herausforderungen waehrend eines Laufs (alle 6 Ticks: kleine Portionen, der Ausgang fasst nur 50 Schrott;
-- nicht 5, das belegt schon process_blasts in control.lua)

local TICKS = 6

-- Fulgora, Schrott-Lawine: immer mehr Schrott in den Ausgang; ist er zu lange voll, stuerzt der Schacht ein.
local function avalanche(entry, core)
  local entity = entry.entity
  local a = config.AVALANCHE
  local progress = entity.crafting_progress
  entry.rate = a.START + (a.END - a.START) * progress * progress
  if not entity.is_crafting() or entity.status == defines.entity_status.low_power
    or entity.status == defines.entity_status.no_power then
    return -- ohne Strom graebt er nicht
  end
  entry.carry = (entry.carry or 0) + entry.rate * TICKS / 60
  local count = math.floor(entry.carry)
  if count < 1 then return end
  entry.carry = entry.carry - count
  local output = entity.get_inventory(defines.inventory.crafter_output)
  local inserted = output and output.insert{name = a.item, count = count} or 0
  if inserted < count then
    entry.blocked = (entry.blocked or 0) + TICKS
    if entry.blocked >= a.FAIL_SECONDS * 60 then
      fail(entry, core, {"ncs-extractor.collapsed"})
    end
  else
    entry.blocked = 0
  end
end

-- Fluessigkeits-Anschluss mit dieser Fluessigkeit (Filter aus dem Rezept). Seit 2.1 ohne LuaFluidBox.
local function fluid_index(entity, fluid)
  for i = 1, entity.fluids_count do
    local filter = entity.get_fluid_filter(i)
    if filter and filter.name == fluid then return i end
  end
  return nil
end

-- Vulcanus, Kuehlung: Wasser rein, gleich viel Dampf raus. Fehlt Wasser oder ist der Dampf-Ausgang voll, steigt die
-- Hitze; bei 100 % explodiert er.
local function heat(entry, core)
  local entity = entry.entity
  local h = config.HEAT
  local progress = entity.crafting_progress
  entry.rate = h.START + (h.END - h.START) * progress
  entry.heat = entry.heat or 0
  if not entity.is_crafting() or entity.status == defines.entity_status.low_power
    or entity.status == defines.entity_status.no_power then
    return -- ohne Strom graebt er nicht und wird nicht heiss
  end
  local water_index = fluid_index(entity, "water")
  local steam_index = fluid_index(entity, "steam")
  if not (water_index and steam_index) then return end

  local need = entry.rate * TICKS / 60
  local water = entity.get_fluid(water_index)
  local steam = entity.get_fluid(steam_index)
  local water_amount = water and water.amount or 0
  local room = entity.get_fluid_capacity(steam_index) - (steam and steam.amount or 0)
  local ratio = h.STEAM_PER_WATER
  local cooled = math.min(need, water_amount, room / ratio) -- Wasser, das in diesem Takt zu Dampf wird
  if cooled > 0 then
    entity.remove_fluid(water_index, cooled)
    cooled = entity.add_fluid(steam_index, {name = "steam", amount = cooled * ratio, temperature = h.STEAM_TEMPERATURE}) / ratio
  end
  local missing = 1 - cooled / need
  if missing > 0.01 then
    entry.heat = entry.heat + h.RISE * missing * TICKS / 60
  else
    entry.heat = math.max(0, entry.heat - h.COOL * TICKS / 60)
  end
  entry.cooling = water_amount < need and "water" or (room < need * ratio and "steam" or nil)
  if entry.heat >= 100 then
    fail(entry, core, {"ncs-extractor.overheated"}, h.DAMAGE)
  end
end

local function powered(entity)
  return entity.is_crafting() and entity.status ~= defines.entity_status.low_power
    and entity.status ~= defines.entity_status.no_power
end

-- Gleba, Gegnerwellen: bei bestimmtem Fortschritt kommt eine Welle Pentapoden aus einer zufaelligen Richtung.
local function waves(entry, core)
  local entity = entry.entity
  entry.wave = entry.wave or 0
  local wave = config.WAVES[entry.wave + 1]
  if not (wave and entity.crafting_progress >= wave.at) then return end
  entry.wave = entry.wave + 1
  local surface = entity.surface
  local angle = math.random() * 2 * math.pi
  local origin = {x = entity.position.x + math.cos(angle) * config.WAVES.DISTANCE,
    y = entity.position.y + math.sin(angle) * config.WAVES.DISTANCE}
  -- So weit draussen ist die Karte evtl. noch nicht erzeugt, dann scheitert create_entity.
  local chunk = {x = math.floor(origin.x / 32), y = math.floor(origin.y / 32)}
  if not surface.is_chunk_generated(chunk) then
    surface.request_to_generate_chunks(origin, 1)
    surface.force_generate_chunk_requests()
  end
  local spawned = 0
  for _, group in pairs(wave.units) do
    local name, count = group[1], group[2]
    if prototypes.entity[name] then
      for _ = 1, count do
        local probe = {x = origin.x + math.random(-8, 8), y = origin.y + math.random(-8, 8)}
        local position = surface.find_non_colliding_position(name, probe, 16, 1)
        local unit = position and surface.create_entity{name = name, position = position, force = "enemy"}
        if unit then
          spawned = spawned + 1
          local commandable = unit.commandable
          if commandable then
            commandable.set_command{type = defines.command.attack, target = entity, distraction = defines.distraction.by_enemy}
          end
        end
      end
    end
  end
  local key = wave.boss and "ncs-extractor.boss-wave" or "ncs-extractor.wave"
  entity.force.print({key, entry.wave, #config.WAVES, spawned, entity.gps_tag})
end

-- Aquilo, Waerme: dem Waermespeicher stetig mehr Waerme entziehen; ist er zu kalt, steigt der Frost.
local function cold(entry, core)
  local entity = entry.entity
  local c = config.COLD
  entry.rate = c.START + (c.END - c.START) * entity.crafting_progress
  entry.frost = entry.frost or 0
  -- Normales Einfrieren (Aquilo-Regel): erst nach 3 s am Stueck verloren, kurz nach dem Bauen ist er sonst noch kalt
  entry.frozen_ticks = entity.frozen and (entry.frozen_ticks or 0) + TICKS or 0
  if entry.frozen_ticks >= 180 then
    fail(entry, core, {"ncs-extractor.frozen"})
    return
  end
  local storage_entity = ensure_heat_entity(entry)
  if not (storage_entity and powered(entity)) then return end
  local drop = entry.rate * 1000000 * TICKS / 60 / 10000000 -- MJ pro Takt durch 10 MJ pro Grad
  storage_entity.temperature = math.max(15, storage_entity.temperature - drop)
  entry.temperature = storage_entity.temperature
  if storage_entity.temperature < c.MIN_TEMPERATURE then
    entry.frost = entry.frost + c.RISE * TICKS / 60
  else
    entry.frost = math.max(0, entry.frost - c.THAW * TICKS / 60)
  end
  if entry.frost >= 100 then
    fail(entry, core, {"ncs-extractor.frozen"})
  end
end

-- Nauvis, Verschmutzung: starke Verschmutzung und regelmaessig Beisser aus der Umgebung auf den Extraktor.
local function pollution(entry, core)
  local entity = entry.entity
  local p = config.POLLUTION
  local progress = entity.crafting_progress
  entry.rate = p.START + (p.END - p.START) * progress
  if not powered(entity) then return end
  entity.surface.pollute(entity.position, entry.rate * TICKS / 60, NAME)
  entry.next_attack = entry.next_attack or (game.tick + p.INTERVAL * 60)
  if game.tick >= entry.next_attack then
    entry.next_attack = game.tick + p.INTERVAL * 60
    local wanted = math.floor(p.UNITS_START + (p.UNITS_END - p.UNITS_START) * progress)
    entry.attackers = entity.surface.set_multi_command{
      command = {type = defines.command.attack, target = entity, distraction = defines.distraction.by_enemy},
      unit_count = wanted, unit_search_distance = p.SEARCH, force = "enemy"}
    if entry.attackers > 0 then
      entity.force.print({"ncs-extractor.attack", entry.attackers, entity.gps_tag})
    end
  end
end

local CHALLENGES = {avalanche = avalanche, heat = heat, waves = waves, cold = cold, pollution = pollution}

function extractor.on_nth_tick()
  for key, entry in pairs(storage.extractors) do
    if entry.running and entry.entity.valid then
      local core = BY_NAME[entry.core]
      local challenge = core and CHALLENGES[core.challenge]
      if challenge then challenge(entry, core) end
      if not entry.entity.valid then -- bei Ueberhitzung zerstoert
        destroy_heat_entity(entry)
        storage.extractors[key] = nil
      end
    end
  end
end
extractor.TICKS = TICKS

-- Nur auf einer Fundstelle baubar (Wunsch des Users 2026-11-04). Ein Assembler kann keine Lagerstaette unter sich
-- verlangen, deshalb wie bei den Planeten-Regeln: ohne Fundstelle sofort wieder abbauen (Item zurueck an Spieler
-- bzw. Roboter), Geist entfernen, mit Hinweis. Nur Bauen durch Spieler und Roboter, nicht Skripte.
local function reject_without_core(event)
  local entity = event.entity
  if not (event.player_index or event.robot) then return false end
  local name = entity.type == "entity-ghost" and entity.ghost_name or entity.name
  if name ~= NAME then return false end
  if cores_under(entity)[1] then return false end

  local player = event.player_index and game.get_player(event.player_index)
  if player and player.valid then
    player.create_local_flying_text{text = {"ncs-extractor.no-core"}, position = entity.position, create_at_cursor = true}
  end
  if entity.type == "entity-ghost" then
    entity.destroy()
  elseif player and player.valid then
    if not player.mine_entity(entity, true) and entity.valid then entity.destroy() end
  elseif event.robot and event.robot.valid then
    local cargo = event.robot.get_inventory(defines.inventory.robot_cargo)
    if not entity.mine{inventory = cargo, force = true, ignore_minable = true} and entity.valid then entity.destroy() end
  else
    entity.destroy()
  end
  return true
end

function extractor.on_built(event)
  local entity = event.entity
  if not (entity and entity.valid) then return end
  if reject_without_core(event) then return end
  if entity.name == NAME then
    register(entity)
    update(storage.extractors[entity.unit_number])
  end
end

function extractor.on_removed(event)
  local entity = event.entity
  if entity and entity.valid and entity.name == NAME then
    local entry = storage.extractors[entity.unit_number]
    if entry and entry.running and event.name == defines.events.on_entity_died then
      entity.force.print({"ncs-extractor.failed", {"ncs-extractor.destroyed"}, entity.gps_tag})
    end
    destroy_heat_entity(entry)
    storage.extractors[entity.unit_number] = nil
  end
end

---------------------------------------------------------------------------
-- Fenster neben dem Extraktor-GUI

local function fill_gui(frame, entity)
  frame.clear()
  local cores = cores_under(entity)
  local core = core_kind(cores)
  local entry = storage.extractors[entity.unit_number]
  if core then
    frame.add{type = "label", caption = {"ncs-extractor.core", "[item=" .. core.product .. "]", {"item-name." .. core.product}}}
    frame.add{type = "label", caption = {"ncs-extractor.runs-left", runs_left(cores), core.count}}
    if not researched(entity.force, core) then
      frame.add{type = "label", caption = {"ncs-extractor.need-research", {"technology-name." .. core.technology}}}
    end
  else
    frame.add{type = "label", caption = {"ncs-extractor.no-core"}}
  end
  local label = frame.add{type = "label", caption = {"ncs-extractor.help", math.floor(config.RUN_SECONDS / 60)}}
  label.style.single_line = false
  label.style.maximal_width = 260
  local button = frame.add{type = "button", name = START_BUTTON, caption = {"ncs-extractor.start"}, style = "confirm_button"}
  button.enabled = core ~= nil and not (entry and entry.running)
end

function extractor.on_gui_opened(event)
  local entity = event.entity
  if not (entity and entity.valid and entity.name == NAME) then return end
  local player = game.get_player(event.player_index)
  if player.gui.relative[GUI] then player.gui.relative[GUI].destroy() end
  local frame = player.gui.relative.add{type = "frame", name = GUI, direction = "vertical", caption = {"ncs-extractor.title"},
    anchor = {gui = defines.relative_gui_type.assembling_machine_gui, position = defines.relative_gui_position.right, name = NAME}}
  fill_gui(frame, entity)
end

function extractor.on_gui_closed(event)
  local player = game.get_player(event.player_index)
  if player and player.gui.relative[GUI] then player.gui.relative[GUI].destroy() end
end

-- Lauf starten. Gibt nil zurueck, wenn er laeuft, sonst den Grund (LocalisedString).
function extractor.start(entity)
  local entry = storage.extractors[entity.unit_number]
  if not entry then
    register(entity)
    entry = storage.extractors[entity.unit_number]
  end
  if entry.running then return nil end
  local core = core_kind(cores_under(entity))
  if not core then return {"ncs-extractor.no-core"} end
  if not researched(entity.force, core) then
    return {"ncs-extractor.need-research", {"technology-name." .. core.technology}}
  end
  set_recipe(entity, core.recipe)
  if product_waiting(entity) then return {"ncs-extractor.collect"} end
  if not has_ingredients(entity, core) then return {"ncs-extractor.need-ingredients"} end
  if core.challenge == "cold" then
    local heat = ensure_heat_entity(entry)
    if heat and heat.temperature < config.COLD.MIN_TEMPERATURE then
      return {"ncs-extractor.need-heat", config.COLD.MIN_TEMPERATURE, math.floor(heat.temperature)}
    end
  end
  entry.running = true
  entry.started = game.tick -- fuer die Errungenschaft "Lawinenreiter"
  entry.wave = 0
  entry.frost = 0
  entry.next_attack = nil
  entry.attackers = 0
  entry.core = core.name
  entry.carry = 0
  entry.blocked = 0
  entry.heat = 0
  entry.finished = entity.products_finished
  entity.disabled_by_script = false
  update(entry)
  return nil
end

function extractor.on_gui_click(event)
  local element = event.element
  if not (element and element.valid and element.name == START_BUTTON) then return end
  local player = game.get_player(event.player_index)
  local entity = player.opened
  if not (entity and entity.object_name == "LuaEntity" and entity.valid and entity.name == NAME) then return end
  local reason = extractor.start(entity)
  if reason then player.print(reason) end
  if player.gui.relative[GUI] then fill_gui(player.gui.relative[GUI], entity) end
end

-- Jede Sekunde aus control.lua
function extractor.update_all()
  for key, entry in pairs(storage.extractors) do
    if entry.entity.valid then
      update(entry)
    else
      destroy_heat_entity(entry)
      storage.extractors[key] = nil
    end
  end
  for _, player in pairs(game.connected_players) do
    local opened = player.opened
    local frame = player.gui.relative[GUI]
    if frame and opened and player.opened_gui_type == defines.gui_type.entity and opened.valid and opened.name == NAME then
      fill_gui(frame, opened)
    end
  end
end

function extractor.init()
  storage.extractors = storage.extractors or {}
  storage.core_scanned = storage.core_scanned or {}
  storage.core_guarantee = storage.core_guarantee or {}
end

return extractor
