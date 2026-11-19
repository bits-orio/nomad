-- Ende von Nomad (Prototyp: prototypes/nomad-ending.lua): Ist "Nomade vollendet" erforscht, gewinnt die Force.
-- Siegesbildschirm mit eigenem Text, weiterspielen geht (can_continue). Nur einmal pro Spiel.
-- With several forces each one finishes Nomad for itself (chat line, achievement). The victory screen belongs to
-- the whole game, so it comes up once, for the force that gets there first.

local achievements = require("scripts.achievements")

local ending = {}

ending.TECH = "ncs-nomad-achieved"

function ending.on_research_finished(event)
  local research = event.research
  if not (research and research.name == ending.TECH) then return end
  local force = research.force
  storage.nomad_won_forces = storage.nomad_won_forces or {}
  if storage.nomad_won_forces[force.index] then return end
  storage.nomad_won_forces[force.index] = true
  force.print({"ncs-ending.chat"})
  achievements.on_nomad_won(force) -- "Nomade": hoechstens 2 Stunden auf Planeten
  if storage.nomad_won then return end
  storage.nomad_won = true
  game.set_win_ending_info{
    title = {"ncs-ending.title"},
    message = {"ncs-ending.message"},
    final_message = {"ncs-ending.final"}
  }
  game.set_game_state{game_finished = true, player_won = true, can_continue = true}
end

-- The force starts over (remote reset_force): it can finish Nomad again
function ending.reset_force(force)
  if storage.nomad_won_forces then storage.nomad_won_forces[force.index] = nil end
end

return ending
