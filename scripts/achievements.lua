-- Nomad-Errungenschaften (Prototypen: prototypes/achievements.lua). unlock_achievement wirkt nur beim lokalen
-- Spieler; in Mehrspieler laeuft das Skript auf jedem Rechner, also bekommt jeder seine eigenen.
--   Ereignisse aus anderen Skripten: Aussteigen (spacesuit), Rueckholstrahl (recall), Extraktor-Lauf fertig
--   (extractor), Clusterbombe abgefeuert (orbital-cannon), Roboter aus Granaten (robot-shells).
--   Selbst: Landung (on_player_changed_surface), explodierter instabiler Schrott (Skript-Trigger), alle 60 s
--   Pruefung der Schiffe (Fundament, Spezialboeden, legendaere Items im Rekombinator). Jede Sekunde: Zeit auf Planeten
--   zaehlen (fuer "Nomade", geprueft beim Erforschen von "Nomade vollendet", scripts/ending.lua).

local achievements = {}

local PLANETS = {"nauvis", "vulcanus", "gleba", "fulgora", "aquilo"}
local MOTHERSHIP_TILES = 10000
local SWARM = 100
local FLOORS = {"ncs-lava-pool", "ncs-ammonia-pool", "ncs-bio-foundation", "ncs-jellynut-foundation", "ncs-promethium-foundation"}
local RECOMBINATOR = "ncs-matter-recombinator"
-- "Nomade": Nomad beenden mit hoechstens so viel Zeit auf Planeten (seit 1.24.1; vorher "nie auf Nauvis gelandet",
-- ging nicht: Biolabore und Promethium-Science brauchen Beisser-Eier von Nauvis)
local NOMAD_GROUND_LIMIT = 2 * 60 * 60 * 60 -- 2 Stunden in Ticks
achievements.GROUND_TICKS = 60
achievements.SCRAP_EFFECT = "ncs-unstable-scrap-exploded"

local function unlock(player, name)
  if player and player.valid then player.unlock_achievement(name) end
end

local function unlock_force(force, name)
  for _, player in pairs(force.players) do unlock(player, name) end
  -- Merken, damit die Minuten-Pruefung erledigte Errungenschaften ueberspringt (Optimierung 1.24.1)
  storage.ach_done = storage.ach_done or {}
  storage.ach_done[force.index] = storage.ach_done[force.index] or {}
  storage.ach_done[force.index][name] = true
end

local function done(force, name)
  local list = storage.ach_done and storage.ach_done[force.index]
  return list and list[name] or false
end

function achievements.init()
  storage.ach_nauvis_landed = nil -- bis 1.24.1-Entwurf
  storage.ach_ground_ticks = storage.ach_ground_ticks or {}   -- [player_index] = Ticks mit eigener Figur auf Planeten
  storage.ach_planets = storage.ach_planets or {}             -- [force_index] = {planet = true}
  storage.ach_scrap_boom = storage.ach_scrap_boom or {}       -- [surface_index] = tick der letzten Explosion
end

-- Landung auf einem Planeten mit eigener Figur (nicht Fernansicht)
function achievements.on_player_changed_surface(event)
  local player = game.get_player(event.player_index)
  if not player then return end
  local surface = player.physical_surface
  if not (surface and surface.planet and not surface.platform) then return end
  if player.physical_controller_type ~= defines.controllers.character then return end
  unlock(player, "ncs-first-landing")
end

function achievements.on_spacewalk(player)
  unlock(player, "ncs-spacewalk")
end

function achievements.on_recall(player)
  unlock(player, "ncs-recall")
end

-- Extraktor-Lauf geschafft. started: Tick, an dem der Lauf begann (fuer die Schrott-Lawine)
function achievements.on_extractor_done(entity, core, started)
  local force, surface = entity.force, entity.surface
  unlock_force(force, "ncs-first-extraction")
  local planet = surface.planet and surface.planet.name
  if planet then
    local done = storage.ach_planets[force.index] or {}
    storage.ach_planets[force.index] = done
    done[planet] = true
    local all = true
    for _, name in pairs(PLANETS) do
      if not done[name] then all = false end
    end
    if all then unlock_force(force, "ncs-all-planets") end
  end
  if core.challenge == "avalanche" and (storage.ach_scrap_boom[surface.index] or -1) < (started or 0) then
    unlock_force(force, "ncs-avalanche-rider")
  end
end

-- Instabiler Schrott explodiert (Skript-Trigger in prototypes/extractor.lua)
function achievements.on_script_trigger_effect(event)
  if event.effect_id ~= achievements.SCRAP_EFFECT then return end
  storage.ach_scrap_boom[event.surface_index] = event.tick
end

function achievements.on_cluster_bomb(force)
  unlock_force(force, "ncs-carpet-bombing")
end

function achievements.on_robots(force, count)
  if count >= SWARM then unlock_force(force, "ncs-swarm") end
end

-- Alle 60 s: Schiffe pruefen
function achievements.check()
  local legendary = prototypes.quality["legendary"]
  for _, force in pairs(game.forces) do
    if #force.players > 0 then
      for _, platform in pairs(force.platforms) do
        local surface = platform.valid and platform.surface
        if surface then
          if not done(force, "ncs-mothership")
            and surface.count_tiles_filtered{name = "empty-space", invert = true} >= MOTHERSHIP_TILES then
            unlock_force(force, "ncs-mothership")
          end
          if not done(force, "ncs-ark") then
            local all = true
            for _, floor in pairs(FLOORS) do
              if all and prototypes.tile[floor] and surface.count_tiles_filtered{name = floor, limit = 1} == 0 then all = false end
            end
            if all then unlock_force(force, "ncs-ark") end
          end
          if legendary and not done(force, "ncs-legendary") then
            for _, entity in pairs(surface.find_entities_filtered{name = RECOMBINATOR}) do
              local output = entity.get_output_inventory()
              if output then
                for _, stack in pairs(output.get_contents()) do
                  if stack.quality == "legendary" or (type(stack.quality) ~= "string" and stack.quality and stack.quality.name == "legendary") then
                    unlock_force(force, "ncs-legendary")
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end

-- Jede Sekunde (aus control.lua): Zeit auf Planeten zaehlen, nur mit eigener Figur (nicht Fernansicht, nicht im Hub)
function achievements.count_ground()
  local ground = storage.ach_ground_ticks
  if not ground then return end
  for _, player in pairs(game.connected_players) do
    local surface = player.physical_surface
    if surface and surface.planet and not surface.platform
      and player.physical_controller_type == defines.controllers.character then
      ground[player.index] = (ground[player.index] or 0) + achievements.GROUND_TICKS
    end
  end
end

-- "Nomade vollendet" erforscht (scripts/ending.lua)
function achievements.on_nomad_won(force)
  for _, player in pairs(force.players) do
    if (storage.ach_ground_ticks[player.index] or 0) <= NOMAD_GROUND_LIMIT then unlock(player, "ncs-nomad") end
  end
end

return achievements
