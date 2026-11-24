@tool
extends Node2D
## Zone 1 pack props, drawn at their ground contact for reliable Y sorting.
const STORY_SHEET = preload("res://assets/zones/zone_1/storybook/storybook_world1_frozen.png")
const WAYPOINT_SPRITE = preload("res://assets/zones/zone_1/storybook/frostguard_waypoint.png")
const STORY_COLUMNS := [0, 330, 648, 950, 1254]
const STORY_ROWS := [0, 368, 656, 938, 1254]
@export var kind: String = "ice"
@export var active: bool = false:
	set(value):
		if active == value:
			return
		active = value
		if kind == "crystal":
			for child in get_children():
				if child is StaticBody2D:
					child.get_child(0).set_deferred("disabled", active)
		syncNativeArt()
		queue_redraw()
@export var amount: float = 0.0:
	set(value):
		if amount == value:
			return
		if kind == "ice" and (value < 1.0 or amount < 1.0):
			puddle_age = 0.0
		amount = value
		# Liquid belongs to the ground layer, below every Y-sorted actor.
		if kind == "ice":
			z_index = -1 if amount >= 1.0 else 0
		syncNativeArt()
		queue_redraw()
@export var direction: int = 0:
	set(value):
		if direction == value:
			return
		direction = value
		_turn_rotor()
		syncNativeArt()
		queue_redraw()
var rotor: Sprite2D
var rotor_tween: Tween
var mirror_frame := 0.0
var clock: float = 0.0
var redraw_elapsed := 0.0
const PUDDLE_HOLD := 1.5
const PUDDLE_LIFETIME := 4.5
var puddle_age := 0.0
var bodySprite: Sprite2D
var artHome := Vector2.ZERO
var puddleScale := Vector2.ONE


func _set_mirror_frame(value: float) -> void:
	mirror_frame = value
	rotor.frame = int(round(value)) % 8


func beam_direction() -> Vector2:
	# Use the displayed frame, including intermediate frames during a turn.
	var angle := float(rotor.frame) * PI / 4.0
	return Vector2(sin(angle), cos(angle) * 0.5).normalized()


func mirror_turning() -> bool:
	return rotor_tween != null and rotor_tween.is_running()


func _turn_rotor() -> void:
	if kind == "fan" or not is_instance_valid(rotor):
		return
	if rotor_tween != null:
		rotor_tween.kill()
	if kind == "reflector":
		var target_frame := float(direction)
		var steps := fposmod(target_frame - fposmod(mirror_frame, 8.0), 8.0)
		rotor_tween = create_tween()
		rotor_tween.tween_method(_set_mirror_frame, mirror_frame, mirror_frame + steps, 0.4)
		return
	var target := float(direction) * TAU / 3.0
	var distance := fposmod(target - rotor.rotation, TAU)
	rotor_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	rotor_tween.tween_property(rotor, "rotation", rotor.rotation + distance, 0.45)


func _ready() -> void:
	bodySprite = get_node_or_null("BodySprite")
	if bodySprite:
		artHome = bodySprite.position
	if kind == "ice":
		puddleScale = $MeltedPuddle.scale
	if kind == "reflector":
		rotor = $MirrorRotation
		_set_mirror_frame(float(direction))
	if kind == "fan":
		rotor = $VentRotor
	set_process(kind in ["brazier", "exit", "crystal", "camp", "fan", "blades", "ice"])
	syncNativeArt()


func _process(delta: float) -> void:
	clock += delta
	syncNativeArt()
	if kind == "ice":
		if amount >= 1.0 and puddle_age < PUDDLE_LIFETIME:
			puddle_age = minf(PUDDLE_LIFETIME, puddle_age + delta)
			syncNativeArt()
		return
	if kind == "fan" and is_instance_valid(rotor):
		rotor.visible = active
		if active:
			rotor.rotation = fposmod(rotor.rotation + delta * 10.0, TAU)
	redraw_elapsed += delta
	if redraw_elapsed < 1.0 / 30.0:
		return
	redraw_elapsed = fmod(redraw_elapsed, 1.0 / 30.0)
	var screen_at := get_global_transform_with_canvas() * Vector2.ZERO
	if not get_viewport_rect().grow(180.0).has_point(screen_at):
		return
	if (
		(kind == "brazier" and active)
		or (kind == "exit" and active)
		or (kind == "crystal" and not active)
		or kind in ["camp", "blades"]
	):
		syncNativeArt()
		queue_redraw()


func _draw() -> void:
	if kind in ["wood", "crystal", "blades"] and active:
		return
	if kind == "waypoint" and active:
		draw_circle(Vector2(0, -58), 9, Color(0.35, 0.90, 1.0, 0.20))
	if kind == "blades":
		draw_circle(Vector2(0, -14), 23, Color(0.7, 0.95, 1.0, 0.12))
	if ((kind == "brazier" and active) or kind == "camp") and not has_node("WarmAura"):
		draw_circle(Vector2(0, -25), 35 + sin(clock * 4) * 2, Color(1, 0.65, 0.25, 0.12))
	if kind == "crystal" and amount < 1.0:
		draw_arc(
			Vector2(0, -22), 29, -PI / 2, -PI / 2 + TAU * (1.0 - amount), 24, Color("d3f3ff"), 2
		)


func syncNativeArt() -> void:
	for label in ["WarmAura", "WarmSnowPool"]:
		var saved_light := get_node_or_null(label)
		if saved_light: saved_light.visible = kind == "camp" or (kind == "brazier" and active)
	if not is_instance_valid(bodySprite):
		return
	bodySprite.visible = not (kind in ["wood", "crystal", "blades"] and active)
	if kind in ["wood","crystal","blades"] and has_node("GroundContact"):
		$GroundContact.visible=not active
	if kind == "waypoint":
		bodySprite.modulate = Color.WHITE if active else Color(0.53, 0.65, 0.73)
	if kind in ["crystal", "blades"]:
		bodySprite.position.y = artHome.y + sin(clock * (2.5 if kind == "blades" else 2.0)) * 2.0
	if kind == "brazier":
		bodySprite.visible = not active
		$LitBrazier.visible = active
	if kind == "ice":
		bodySprite.visible = amount < 0.34
		$CrackedIce.visible = amount >= 0.34 and amount < 1.0
		var fade := clampf((puddle_age - PUDDLE_HOLD) / (PUDDLE_LIFETIME - PUDDLE_HOLD), 0.0, 1.0)
		$MeltedPuddle.visible = amount >= 1.0 and fade < 1.0
		$MeltedPuddle.modulate.a = 1.0 - fade
		$MeltedPuddle.scale = puddleScale * (1.0 - fade * 0.18)
