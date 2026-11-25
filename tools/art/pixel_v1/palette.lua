-- Master palette. The only place where colours are defined.
-- Index 0 is transparent. Indices 1-49 follow the order below. New colours go last, so old indices never move.
-- Ramps run dark to light. Shadows lean cool, highlights lean warm.
return {
  version = 2,
  groups = {
    { name = "ink",    kind = "neutral", "14141f", "2b2f3f", "434a58", "5f6973", "7e8886", "a0a7a1", "c2c5bb", "e9e7db" },
    { name = "snow",   kind = "ramp", "4d6a94", "7396bd", "98b9d7", "c8dcea", "fcfdf5" },
    { name = "ice",    kind = "ramp", "0d2f57", "1b5c7a", "2f8fa6", "6cc6cf", "b4f5e3" },
    { name = "leaf",   kind = "ramp", "0f3d33", "1f6247", "4a8c4a", "8dbb5c", "d6e489" },
    { name = "earth",  kind = "ramp", "3a1f24", "574739", "8f6a50", "bd9870", "e6cf9f" },
    { name = "amber",  kind = "ramp", "5a1f12", "9c3f16", "d9741f", "f5b23c", "fff0a3" },
    { name = "red",    kind = "ramp", "560a33", "942036", "d1434a", "f08a7c", "ffb8c6" },
    { name = "violet", kind = "ramp", "241a68", "523a9c", "8c66c8", "c39fe6", "f2d9fb" },
    { name = "skin",   kind = "ramp", "70333d", "ad5a47", "d68a62", "ecb285", "fbdcc0" },
    { name = "olive",  kind = "accent", "5b663f" }, -- the explorer's tunic, approved in PX-03
  },
  -- Colours a sheet may use. "master" allows all 49.
  subsets = {
    gardens    = { "ink1-8", "snow1-5", "ice1-5", "leaf1-4", "earth1-5", "amber2-5", "red2-4", "violet1-5" },
    vale       = { "ink1-8", "ice1-5", "leaf1-5", "earth1-5", "amber1-5", "red2-5", "violet3-4", "snow4-5" },
    laboratory = { "ink1-8", "snow1-5", "ice1-5", "violet1-5", "amber2-5", "red2-4", "leaf2-4", "earth2-4" },
    cast       = { "ink1-8", "skin1-5", "earth1-5", "amber1-5", "red1-5", "violet1-4", "ice1-4", "leaf1-4", "snow3-5", "olive1-1" },
    interface  = { "ink1-8", "snow3-5", "ice2-5", "leaf2-4", "earth1-5", "amber2-5", "red2-4", "violet2-4" },
    master     = { "ink1-8", "snow1-5", "ice1-5", "leaf1-5", "earth1-5", "amber1-5", "red1-5", "violet1-5", "skin1-5", "olive1-1" },
  },
  -- Pairs that carry meaning. They must stay apart for colour-blind players,
  -- and the art must still repeat the meaning with shape or motion.
  meaning = {
    { "thermal / cryo",         "amber3", "ice4" },
    { "thermal / pressure",     "amber3", "violet2" },
    { "thermal / vacuum",       "amber3", "leaf5" },
    { "cryo / pressure",        "ice4",   "violet2" },
    { "cryo / vacuum",          "ice4",   "leaf5" },
    { "pressure / vacuum",      "violet2", "leaf5" },
    { "correct / wrong",        "leaf4",  "red2" },
    { "heat in / heat out",     "amber4", "ice2" },
    { "health / warmth bar",    "red3",   "ice2" },
    { "ready / locked",         "amber4", "ink4" },
    { "snow / path",            "snow4",  "earth3" },
    { "grass / path",           "leaf4",  "earth2" },
    { "ice / water",            "ice5",   "ice3" },
  },
}
