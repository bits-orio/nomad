-- Ende von Nomad (Prototyp: prototypes/nomad-ending.lua): Ist "Nomade vollendet" erforscht, gewinnt die Force.
-- Siegesbildschirm mit eigenem Text, weiterspielen geht (can_continue). Nur einmal pro Spiel.

local achievements = require("scripts.achievements")

local ending = {}

ending.TECH = "ncs-nomad-achieved"

function ending.on_research_finished(event)
  local research = event.research
  if not (research and research.name == ending.TECH) then return end
  if storage.nomad_won then return end
  storage.nomad_won = true
  local force = research.force
  force.print({"ncs-ending.chat"})
  game.set_win_ending_info{
    title = {"ncs-ending.title"},
    message = {"ncs-ending.message"},
    final_message = {"ncs-ending.final"}
  }
  game.set_game_state{game_finished = true, player_won = true, can_continue = true}
  achievements.on_nomad_won(force) -- "Nomade": hoechstens 2 Stunden auf Planeten
end

return ending
