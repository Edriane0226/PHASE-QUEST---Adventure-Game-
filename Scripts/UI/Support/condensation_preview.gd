extends "res://Scripts/UI/Support/science_card.gd"
## Read-only model using the shared before/heat-transfer/after diagram.
signal narrated(text: String)

const CAPTIONS := [
	"The humid-air feed carries invisible water vapor from the evaporation tray.",
	"Heat leaves the humid air at the +6°C pane. That is below its +12°C dew point and above freezing.",
	"Liquid droplets collect on the air side of the sealed glass. The separate cartridge freezes liquid water into ice.",
]
var _elapsed := 0.0
var _playing := true

func diagram_id() -> String:
	return "condensation"

func captions() -> Array:
	return CAPTIONS

func _ready() -> void:
	super._ready()
	replay()
	# The shared guide connects narration after adding this Control.
	_emit_caption.call_deferred()

func replay() -> void:
	_elapsed = 0.0
	_playing = true
	present(diagram_id(),0)
	_emit_caption()

func toggle_playback() -> void:
	_playing = not _playing

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed = fmod(_elapsed+delta,12.0)
	var step := int(_elapsed/4.0)
	if step != stage:
		present(diagram_id(),step)
		_emit_caption()

func _emit_caption() -> void:
	narrated.emit(captions()[stage])
