extends "res://Scripts/UI/cryo_device_preview.gd"
## Preview-only apparatus assumptions; never a persistent device grant or lesson.
@export_enum("vacuum","pressure") var chamber_mode := "vacuum"
const CHAMBER_ART = preload("res://assets/effects/chamber/v1/sprite_frames.tres")
const PRESSURE_FX = preload("res://Scripts/World/pressure_vice_effects.gd")
const VACUUM_FX = preload("res://Scripts/World/vacuum_burst_effects.gd")

func device_definition() -> Dictionary:
	var device := {"version":1,"unlocked_modes":{},"learned_capabilities":{"sublimation":true} if chamber_mode == "vacuum" else {"deposition":true},"selected_mode":chamber_mode}
	device.unlocked_modes[chamber_mode] = true
	return device

func target_definition() -> Dictionary:
	return {"id":"chamber_preview_"+chamber_mode,"zone":"sublimation_and_deposition","level":1 if chamber_mode == "vacuum" else 3,"material":"water","process":"sublimation" if chamber_mode == "vacuum" else "deposition","allowed_modes":[chamber_mode],"required_exposure":4.0,"max_range":100.0,"required_flags":["prepared"]}

func valid_sample() -> Dictionary:
	return {"material":"water","state":"solid" if chamber_mode == "vacuum" else "gas","amount":1.0,"phase_region":"solid_gas" if chamber_mode == "vacuum" else "gas_solid","heat_flow":"in" if chamber_mode == "vacuum" else "out","sealed":true,"instrumented":true,"temperature_controlled":true,"pressure_regime":"low" if chamber_mode == "vacuum" else "high","liquid_present":false}

func effect_script() -> Script: return VACUUM_FX if chamber_mode == "vacuum" else PRESSURE_FX
func sample_art() -> SpriteFrames: return CHAMBER_ART
func preview_title() -> String: return chamber_mode.to_upper()+" — SEALED CHAMBER PREVIEW"
func preview_summary(complete: bool) -> String:
	if complete: return "Ice became vapor; energy supplied." if chamber_mode == "vacuum" else "Vapor deposited as frost; heat removed."
	return "Low pressure + energy in. Sealed water sample." if chamber_mode == "vacuum" else "High pressure + heat out. Suitable water vapor."

func _ready() -> void:
	selected_mode = chamber_mode
	sample = valid_sample()
	flags = {"prepared":true}
	super._ready()
	target.name = "PreviewSealedChamber"
	_present_sample(0)

func _present_sample(progress: float) -> void:
	var first := 0 if chamber_mode == "vacuum" else 2
	water.texture = CHAMBER_ART.get_frame_texture("sample",first)
	ice.texture = CHAMBER_ART.get_frame_texture("sample",first+1)
	ice.modulate.a = clampf(progress,0,1)
	if float(sample.amount) <= 0:
		water.texture = CHAMBER_ART.get_frame_texture("sample",1)
		ice.modulate.a = 0
	water.visible = true # Empty chamber remains: mode never deletes apparatus.

func set_heading(index: int) -> void:
	super.set_heading(index)
	if get_viewport_rect().size.y < 440:
		target.global_position = player.device_muzzle().global_position+facing*40
		_frame_preview()

func snapshot() -> Dictionary:
	var model := super.snapshot()
	if model.is_empty(): return model
	model["chamber_qualified"] = model.target and _reason().is_empty()
	if not model.target:
		model.status = {"controlled_chamber_required":"SEAL / CONTROL CHAMBER","unsuitable_pressure":"CHECK PRESSURE","unsuitable_conditions":"CHECK HEAT / PHASE","wrong_material":"WRONG MATERIAL","wrong_state":"WRONG SAMPLE STATE","intermediate_liquid":"NO DIRECT TRANSITION","empty_sample":"EMPTY SAMPLE","prerequisite_missing":"PREPARE CHAMBER"}.get(_reason(),model.status)
	return model

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_B:
				sample.sealed = not sample.sealed
				return
			KEY_T:
				sample.temperature_controlled = not sample.temperature_controlled
				return
			KEY_I:
				sample.instrumented = not sample.instrumented
				return
			KEY_H:
				sample.heat_flow = "out" if sample.heat_flow == "in" else "in"
				return
			KEY_O:
				sample.pressure_regime = "high" if sample.pressure_regime == "low" else "low"
				return
			KEY_R:
				sample = valid_sample()
				flags = {"prepared":true}
	super._unhandled_key_input(event)
