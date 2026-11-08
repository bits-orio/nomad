-- Hilfsfunktionen fuer Oberflaechen-Bedingungen (Datenphase).

local util = {}

-- Wert einer Oberflaechen-Eigenschaft auf der Raumplattform (sonst Standardwert der Eigenschaft).
function util.platform_value(property)
  local platform_surface = data.raw.surface["space-platform"]
  local value = platform_surface and platform_surface.surface_properties and platform_surface.surface_properties[property]
  if value ~= nil then return value end
  local definition = data.raw["surface-property"] and data.raw["surface-property"][property]
  return definition and definition.default_value or 0
end

-- Erfuellt die Raumplattform alle diese Bedingungen?
function util.allowed_in_space(conditions)
  for _, condition in pairs(conditions or {}) do
    local value = util.platform_value(condition.property)
    if (condition.min and value < condition.min) or (condition.max and value > condition.max) then
      return false
    end
  end
  return true
end

return util
