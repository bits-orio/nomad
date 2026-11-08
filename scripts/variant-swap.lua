-- Gebaeude-Upgrades per Forschung, obwohl der Wert fest im Prototyp steht (Raketen-Traglast):
-- Pro Stufe gibt es eine versteckte Variante des Gebaeudes (gleiches Item, gleiche Grafik). Dieses Modul tauscht
-- jedes Gebaeude gegen die Variante der erforschten Stufe: beim Bauen, nach jeder Forschungsstufe und
-- (rueckwaerts) beim Zuruecknehmen. Kann ein Gebaeude gerade nicht getauscht werden (can_swap), kommt es in eine
-- Warteliste.
--
-- config: BASES (Original-Namen), FACTORS (pro Stufe), TECH_PREFIX, variant_name(base, level)
-- options.storage_key: eigener Schluessel in storage fuer die Warteliste
-- options.can_swap(entity): darf jetzt getauscht werden? (Standard: immer)
-- options.after_swap(old_state, new_entity), options.save_state(entity): Zustand uebertragen

local variant_swap = {}

function variant_swap.new(config, options)
  local self = {}
  options = options or {}

  local BASE_OF = {}
  for _, base_name in pairs(config.BASES) do
    BASE_OF[base_name] = base_name
    for level in pairs(config.FACTORS) do
      BASE_OF[config.variant_name(base_name, level)] = base_name
    end
  end

  self.FILTER = {}
  local NAMES = {}
  for name in pairs(BASE_OF) do
    table.insert(self.FILTER, {filter = "name", name = name})
    table.insert(NAMES, name)
  end

  function self.base_of(name)
    return BASE_OF[name]
  end

  function self.level(force)
    local level = 0
    for k in pairs(config.FACTORS) do
      local tech = force.technologies[config.TECH_PREFIX .. k]
      if tech and tech.researched and k > level then level = k end
    end
    return level
  end

  local function target_name(entity)
    local base = BASE_OF[entity.name]
    local level = self.level(entity.force)
    if level == 0 then return base end
    return config.variant_name(base, level)
  end

  local function swap(entity)
    local target = target_name(entity)
    if entity.name == target then return true end
    if options.can_swap and not options.can_swap(entity) then return false end

    local surface, position, force = entity.surface, entity.position, entity.force
    local state = options.save_state and options.save_state(entity)
    local health_ratio = entity.health / entity.max_health
    local new = surface.create_entity{name = target, position = position, direction = entity.direction,
      quality = entity.quality, force = force, fast_replace = true, spill = false, create_build_effect_smoke = false,
      raise_built = false}
    if not new then
      log("[nomad] Upgrade-Tausch fehlgeschlagen: " .. entity.name .. " -> " .. target .. " bei " .. serpent.line(position))
      return true
    end
    new.health = new.max_health * health_ratio
    if options.after_swap then options.after_swap(state, new) end
    return true
  end

  -- Tauschen oder fuer spaeter merken
  function self.update(entity)
    if not (entity and entity.valid and BASE_OF[entity.name]) then return end
    local key = entity.unit_number -- vor dem Tausch merken, danach ist entity ungueltig
    local pending = storage[options.storage_key]
    if swap(entity) then
      pending[key] = nil
    else
      pending[key] = entity
    end
  end

  local function update_force(force)
    for _, surface in pairs(game.surfaces) do
      for _, entity in pairs(surface.find_entities_filtered{name = NAMES, force = force}) do
        self.update(entity)
      end
    end
  end

  function self.on_built(event)
    self.update(event.entity)
  end

  function self.on_research_changed(event)
    local name = event.research.name
    if string.sub(name, 1, #config.TECH_PREFIX) == config.TECH_PREFIX then
      update_force(event.research.force)
    end
  end

  -- Warteliste abarbeiten (jede Sekunde aus control.lua)
  function self.process_pending()
    local pending = storage[options.storage_key]
    for key, entity in pairs(pending) do
      if entity.valid then
        if swap(entity) then pending[key] = nil end
      else
        pending[key] = nil
      end
    end
  end

  function self.init()
    storage[options.storage_key] = storage[options.storage_key] or {}
  end

  -- Nach Mod-Aenderungen alle Gebaeude pruefen
  function self.update_all()
    for _, force in pairs(game.forces) do
      update_force(force)
    end
  end

  return self
end

return variant_swap
