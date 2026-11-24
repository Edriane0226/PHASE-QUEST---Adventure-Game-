extends RefCounted
## Exact base fills from the accepted cube SVGs. One palette for mainland and minimap.
const TOP := {"snow":Color("e8f1ed"),"grass":Color("91b96b"),"lab":Color("d9dfd9")}
const LEFT := {"snow":Color("876f60"),"grass":Color("8d7059"),"lab":Color("869195")}
const RIGHT := {"snow":Color("665850"),"grass":Color("6a5746"),"lab":Color("576570")}
static func top(biome: String) -> Color:return TOP[biome]
