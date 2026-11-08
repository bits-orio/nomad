data:extend(
{
  {
    -- Regeln fuer Planeten:
    --   A "mining" (Standard): auf Planeten nur Abbau, verarbeitet wird im All (prototypes/variant-a.lua)
    --   B "all": auf Planeten alles erlaubt
    --   C "space-age": Space-Age-Gebaeude nur im All, ausser Recycler und Agrarturm (prototypes/variant-b.lua)
    type = "string-setting",
    name = "ncs-rules-variant",
    setting_type = "startup",
    default_value = "mining",
    allowed_values = {"mining", "all", "space-age"},
    order = "0"
  },
  {
    -- Faktor fuer die Science-Kosten aller Nomad-Forschungen (ncs-*), Vanilla bleibt (data-final-fixes.lua)
    type = "double-setting",
    name = "ncs-research-cost",
    setting_type = "startup",
    default_value = 1,
    minimum_value = 0.1,
    maximum_value = 10,
    order = "1"
  },
  {
    -- Wer auf einem Planeten stirbt, wacht im Hub des Mutterschiffs auf (scripts/recall.lua)
    type = "bool-setting",
    name = "ncs-respawn-on-ship",
    setting_type = "runtime-global",
    default_value = true,
    order = "a"
  }
})
