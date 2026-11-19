-- Which planet a surface stands for.
--
-- Nomad keeps per-planet rules by planet name (deposits, capsule loads, achievements). Normally that is the name
-- of the planet the surface belongs to. A mod that gives a force its own copy of a planet (a copy of Vulcanus under
-- another name, say) can tell Nomad which planet that surface stands for:
--
--   remote.call("nomad", "set_surface_planet", surface_index, "vulcanus")
--
-- Only the per-planet rules use this. Everything that deals with the real planet (orbit, recall beam, orbital
-- cannon, jump drive) keeps using surface.planet.

local surface_planet = {}

-- Name of the planet whose rules apply on this surface, nil if it is not a planet
function surface_planet.name(surface)
  local known = storage.surface_planet and storage.surface_planet[surface.index]
  if known then return known end
  local planet = surface.planet
  return planet and planet.name or nil
end

-- Returns true if this changed what the surface stands for
function surface_planet.set(surface_index, planet_name)
  storage.surface_planet = storage.surface_planet or {}
  if storage.surface_planet[surface_index] == planet_name then return false end
  storage.surface_planet[surface_index] = planet_name
  return true
end

function surface_planet.on_surface_deleted(event)
  if storage.surface_planet then storage.surface_planet[event.surface_index] = nil end
end

return surface_planet
