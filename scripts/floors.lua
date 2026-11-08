-- Spezialboeden auf den Schiffen.
-- Das Schiff waechst frei, ohne Grenzen.
-- Spezialboeden (Lava-Becken, Bio-Boden, Ammoniak-Becken, Promethium-Boden) werden einmal erforscht,
-- danach gibt es beliebig viele; begrenzt sind sie durch ihre sehr teure Herstellung.

local floors = {}

local FOUNDATION = "space-platform-foundation"

-- Item und Boden heissen gleich; technology schaltet das Rezept frei.
floors.TYPES =
{
  {name = "ncs-lava-pool", technology = "ncs-lava-zone"},
  {name = "ncs-bio-foundation", technology = "ncs-bio-zone"},
  {name = "ncs-jellynut-foundation", technology = "ncs-jellynut-zone"},
  {name = "ncs-ammonia-pool", technology = "ncs-ammonia-zone"},
  {name = "ncs-promethium-foundation", technology = "ncs-promethium-zone"}
}

-- Alte Zonenboeden (vor 1.1.0), werden beim Laden zu normalem Fundament.
local LEGACY_TILES = {"ncs-science-foundation", "ncs-lava-foundation"}

function floors.unlocked(force, technology)
  local tech = force.technologies[technology]
  return tech ~= nil and tech.researched
end

local function used(force, kind)
  local count = 0
  for _, platform in pairs(force.platforms) do
    if platform.valid and platform.surface then
      count = count + platform.surface.count_tiles_filtered{name = kind.name}
    end
  end
  return count
end

-- Fuer das Info-Fenster: {{name, used, unlocked}, ...}
function floors.status(force)
  local list = {}
  for _, kind in pairs(floors.TYPES) do
    table.insert(list, {name = kind.name, used = used(force, kind), unlocked = floors.unlocked(force, kind.technology)})
  end
  return list
end

-- Spielstaende vor 1.1.0: alte Zonenboeden zu Fundament machen, Zonen-Linien und alte Daten entfernen.
function floors.migrate()
  for _, force in pairs(game.forces) do
    for _, platform in pairs(force.platforms) do
      if platform.valid and platform.surface then
        local changes = {}
        for _, tile in pairs(platform.surface.find_tiles_filtered{name = LEGACY_TILES}) do
          table.insert(changes, {name = FOUNDATION, position = tile.position})
        end
        if #changes > 0 then
          platform.surface.set_tiles(changes, true, false, true, false)
        end
      end
    end
  end
  if storage.zone_drawings then
    rendering.clear(script.mod_name)
  end
  for _, key in pairs({"zone_drawings", "zone_state", "zone_warned", "science_stage", "lava_pool", "lava_pool_warned",
    "side_stages", "lines_hidden", "floor_warned"}) do
    storage[key] = nil
  end
end

return floors
