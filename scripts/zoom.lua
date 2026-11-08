-- Weiter herauszoomen, bevor die vereinfachte Karte kommt (seit 1.24.1, Wunsch des Users). Die Grenze ist
-- ZoomLimits.furthest_game_view und gilt pro Spieler und Steuerung. Die Engine-Vorgabe laesst sich nur fuer die
-- aktuelle Steuerung lesen; deshalb wird bei jedem Wechsel der Steuerung (auch beim Oeffnen der Karte) einmal pro
-- Steuerung die Vorgabe gelesen und um FACTOR verschoben. storage.zoom_done merkt sich den Faktor, damit es sich
-- nicht aufschaukelt; aendert sich FACTOR, wird zuerst auf die Vorgabe zurueckgesetzt.

local zoom = {}

local FACTOR = 2.5 -- 2,5-mal so weit (bis 1.24.1-Entwurf 2)

-- Kopie einer ZoomSpecification FACTOR-mal weiter draussen, nil bei unbekanntem Aufbau
local function further(spec)
  if not spec then return nil end
  if spec.zoom then return {zoom = spec.zoom / FACTOR} end
  if spec.distance then
    return {distance = spec.distance * FACTOR, max_distance = (spec.max_distance or 500) * FACTOR}
  end
  return nil
end

-- true, wenn `a` naeher ist als `b` (nur bei gleichem Aufbau vergleichbar)
local function closer(a, b)
  if a.zoom and b.zoom then return a.zoom > b.zoom end
  if a.distance and b.distance then return a.distance < b.distance end
  return false
end

function zoom.update(player)
  if not (player and player.valid) then return end
  zoom.init() -- Spielstaende, die schon mit dieser Version gespeichert wurden
  local done = storage.zoom_done[player.index] or {}
  storage.zoom_done[player.index] = done
  local controller = player.controller_type
  if done[controller] == FACTOR then return end
  -- Schon mit einem anderen Faktor gesetzt: erst auf die Engine-Vorgabe zuruecksetzen
  if done[controller] then player.set_zoom_limits(controller, {}) end
  done[controller] = FACTOR

  local limits = player.zoom_limits
  local game_view = further(limits.furthest_game_view)
  if not game_view then return end
  local new = {closest = limits.closest, furthest = limits.furthest, furthest_game_view = game_view}
  -- Ganz herauszoomen muss mindestens bis zur neuen Grenze gehen
  if limits.furthest and closer(limits.furthest, game_view) then
    new.furthest = game_view
  end
  player.zoom_limits = new
end

function zoom.init()
  storage.zoom_done = storage.zoom_done or {}
end

return zoom
