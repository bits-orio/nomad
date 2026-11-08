-- 1.13.0: "Aquilo-Quellen" wurde in drei Forschungen aufgeteilt (Lithium-Quelle, Fluor-Quelle, Ammoniak-Becken).
-- Die JSON-Migration benennt die alte Forschung in "ncs-lithium-source" um; wer sie hatte, bekommt die beiden
-- anderen dazu.

for _, force in pairs(game.forces) do
  local lithium = force.technologies["ncs-lithium-source"]
  if lithium and lithium.researched then
    for _, name in pairs({"ncs-fluorine-source", "ncs-ammonia-zone"}) do
      local tech = force.technologies[name]
      if tech then tech.researched = true end
    end
  end
end
