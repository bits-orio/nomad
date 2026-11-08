-- Schiffs-Quellen (Daten in scripts/sources-config.lua): Die Markierung (3x3) bekommt darunter eine unendliche
-- Lagerstaette. Abbauen oder Zerstoeren der Markierung entfernt sie wieder.
-- Einmal erforscht gibt es beliebig viele; begrenzt sind sie durch ihre sehr teure Herstellung.

local config = require("scripts.sources-config")
local floors = require("scripts.floors")

local sources = {}

local BY_MARKER = {}
local MARKERS = {}
for _, source in pairs(config.sources) do
  BY_MARKER[source.marker] = source
  table.insert(MARKERS, source.marker)
end

local function used(force, source)
  local count = 0
  for _, platform in pairs(force.platforms) do
    if platform.valid and platform.surface then
      count = count + platform.surface.count_entities_filtered{name = source.marker}
    end
  end
  return count
end

-- Fuer das Info-Fenster, gleiche Form wie floors.status
function sources.status(force)
  local list = {}
  for _, source in pairs(config.sources) do
    table.insert(list, {name = source.item, used = used(force, source), unlocked = floors.unlocked(force, source.chain)})
  end
  return list
end

local function remove_resources(marker, source)
  local p = marker.position
  for _, resource in pairs(marker.surface.find_entities_filtered{name = source.resource, area = {{p.x - 1.5, p.y - 1.5}, {p.x + 1.5, p.y + 1.5}}}) do
    resource.destroy()
  end
end

-- Markierung gebaut: die Lagerstaette darunter anlegen.
local function on_marker_built(marker)
  local source = BY_MARKER[marker.name]
  local p = marker.position
  local range = source.tiles and 1 or 0
  for dx = -range, range do
    for dy = -range, range do
      marker.surface.create_entity{name = source.resource, position = {p.x + dx, p.y + dy}, amount = source.amount}
    end
  end
end

-- Fuer alle Bau-Ereignisse (Spieler, Hub, Skript)
function sources.on_built(event)
  local marker = event.entity
  if marker and marker.valid and BY_MARKER[marker.name] then on_marker_built(marker) end
end

function sources.on_removed(event)
  local marker = event.entity
  if marker and marker.valid and BY_MARKER[marker.name] then remove_resources(marker, BY_MARKER[marker.name]) end
end

-- Ereignis-Filter fuer alle Markierungen
sources.FILTER = {}
for _, name in pairs(MARKERS) do
  table.insert(sources.FILTER, {filter = "name", name = name})
end

return sources
