extends "res://Scripts/UI/Support/condensation_preview.gd"

func diagram_id() -> String:
	return "deposition"

func captions() -> Array:
	return [
		"Supplied water vapor enters a sealed collector. The dots model invisible vapor.",
		"The chamber regulates pressure while the cold plate removes heat. Pressure alone cannot grow frost.",
		"Solid ice grows directly on the plate while the liquid sensor stays at zero.",
	]
