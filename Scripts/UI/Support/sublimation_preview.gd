extends "res://Scripts/UI/Support/condensation_preview.gd"

func diagram_id() -> String:
	return "sublimation"

func captions() -> Array:
	return [
		"Water ice starts in a sealed chamber. The liquid sensor reads zero.",
		"The chamber maintains suitable low pressure. The regulated exchanger supplies heat to the ice.",
		"The ice becomes captured water vapor directly. The liquid sensor still reads zero. Dots model invisible vapor.",
	]
