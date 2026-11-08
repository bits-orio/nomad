-- Roboter-Granaten (Prototypen: prototypes/robot-shells.lua, Daten: scripts/robot-shells-config.lua).
-- Die Roboter aus den Granaten suchen sich selbst Ziele: Das Skript sucht den naechsten Gegner im Umkreis und laesst
-- sie in kleinen Schritten hinfliegen (Teleport, Kampfroboter haben keine Befehle). In Reichweite kaempfen sie
-- normal. Sie verschwinden nach ihrer normalen Lebenszeit.

local config = require("scripts.robot-shells-config")
local achievements = require("scripts.achievements")

local shells = {}

local function distance(a, b)
  return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

-- Neue Roboter aus dem Einschlag merken (Trigger mit trigger_created_entity)
function shells.on_trigger_created_entity(event)
  local robot = event.entity
  if not (robot and robot.valid and robot.type == "combat-robot" and config.ROBOT_NAMES[robot.name]) then return end
  if robot.combat_robot_owner then return end -- Roboter aus normalen Kapseln folgen dem Spieler
  storage.robot_hunters = storage.robot_hunters or {}
  -- Versetzt starten, damit nicht alle Roboter im selben Tick suchen und aufdecken
  local offset = robot.unit_number % config.SEARCH_TICKS
  storage.robot_hunters[robot.unit_number] = {robot = robot, next_search = 0, next_chart = event.tick + offset}
  achievements.on_robots(robot.force, table_size(storage.robot_hunters))
end

-- Jeden Tick (aus dem on_nth_tick(1)-Handler in control.lua)
function shells.update(event)
  local hunters = storage.robot_hunters
  if not hunters then return end
  for id, hunter in pairs(hunters) do
    local robot = hunter.robot
    if not robot.valid then
      hunters[id] = nil
    else
      -- Radar: Umgebung aufdecken
      if event.tick >= (hunter.next_chart or 0) then
        local p, r = robot.position, config.CHART_RADIUS
        robot.force.chart(robot.surface, {{p.x - r, p.y - r}, {p.x + r, p.y + r}})
        hunter.next_chart = event.tick + config.CHART_TICKS
      end
      local target = hunter.target
      if not (target and target.valid) or event.tick >= hunter.next_search then
        target = robot.surface.find_nearest_enemy{position = robot.position, max_distance = config.SEARCH, force = robot.force}
        hunter.target = target
        hunter.next_search = event.tick + config.SEARCH_TICKS
      end
      if target and target.valid then
        local from, to = robot.position, target.position
        local d = distance(from, to)
        if d > config.STOP then
          local step = math.min(config.STEP, d - config.STOP)
          robot.teleport({from.x + (to.x - from.x) / d * step, from.y + (to.y - from.y) / d * step})
        end
      end
    end
  end
  if not next(hunters) then storage.robot_hunters = nil end
end

return shells
