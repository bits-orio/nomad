-- Triebwerk-Boost (seit 1.24.1): Forschungen, die das Reisetempo aller Schiffe der Force erhoehen.
-- Die API kennt keinen Schub-Bonus (kein Modifier wie "worker-robot-speed"). Stattdessen schreibt das Skript alle
-- 5 Ticks zusaetzlichen Strecken-Fortschritt (LuaSpacePlatform.distance, 0 = Start, 1 = Ziel): Was die Engine in
-- diesem Tick zurueckgelegt hat, kommt mal (Faktor - 1) noch einmal dazu. Normale Triebwerke, kein Tausch.
-- Daten: scripts/thruster-boost-config.lua, Forschungen: prototypes/ship-balance.lua.

local config = require("scripts.thruster-boost-config")

local boost = {}

-- Faktor der hoechsten erforschten Stufe (1 = kein Boost)
local function factor_of(force)
  local factor = 1
  for level, f in pairs(config.FACTORS) do
    local tech = force.technologies[config.TECH_PREFIX .. level]
    if tech and tech.researched and f > factor then factor = f end
  end
  return factor
end

local function refresh_factors()
  storage.thruster_boost_factor = {}
  for _, force in pairs(game.forces) do
    storage.thruster_boost_factor[force.index] = factor_of(force)
  end
end

function boost.init()
  storage.thruster_boost_last = storage.thruster_boost_last or {}
  storage.thruster_boost_pending = nil -- alter Tausch (bis 1.24.0)
  refresh_factors()
end

function boost.on_research_changed(event)
  local name = event.research.name
  if string.sub(name, 1, #config.TECH_PREFIX) == config.TECH_PREFIX then
    refresh_factors()
  end
end

-- Alle TICKS Ticks (aus control.lua): Fortschritt der Engine seit dem letzten Aufruf verstaerken.
-- Seit 1.24.1 alle 5 statt jeden Tick und ohne neue Tabellen pro Aufruf (Optimierung); das Ergebnis ist gleich,
-- weil der ganze Fortschritt seit dem letzten Aufruf verstaerkt wird.
boost.TICKS = 5
local MAX_STEP = 0.05 -- groessere Spruenge (Richtungswechsel, Sprungantrieb, andere Mods) nicht verstaerken

function boost.on_tick(event)
  local last = storage.thruster_boost_last
  local tick = event and event.tick or game.tick
  for force_index, factor in pairs(storage.thruster_boost_factor) do
    if factor > 1 then
      local force = game.forces[force_index]
      if force then
        for _, platform in pairs(force.platforms) do
          local connection = platform.valid and not platform.paused and platform.space_connection
          local distance = connection and platform.distance
          if distance then
            local name = connection.name
            local entry = last[platform.index]
            local new = distance
            if entry and entry.connection == name then
              local step = distance - entry.distance
              if step ~= 0 and math.abs(step) < MAX_STEP then
                new = distance + step * (factor - 1)
                -- Ankunft der Engine ueberlassen: knapp vor dem Ende bleiben
                if new > 0.9999 then new = math.max(distance, 0.9999) end
                if new < 0.0001 then new = math.min(distance, 0.0001) end
                if new ~= distance then platform.distance = new end
              end
              entry.distance = new
              entry.tick = tick
            else
              last[platform.index] = {connection = name, distance = new, tick = tick}
            end
          end
        end
      end
    end
  end
  -- Selten aufraeumen: Schiffe, die nicht mehr reisen
  if tick % 600 < boost.TICKS then
    for key, entry in pairs(last) do
      if (entry.tick or 0) < tick - 60 then last[key] = nil end
    end
  end
end

return boost
