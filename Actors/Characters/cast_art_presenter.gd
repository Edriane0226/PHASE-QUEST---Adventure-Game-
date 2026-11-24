@tool
extends Node2D
## Opt-in presentation. State changes do not run dialogue, rewards or progression.
const REGISTRY="res://assets/characters/professors/r3_v1/cast_registry.json"
@export var cast_id: String="professor_z1":
	set(value):
		cast_id=value
		if is_inside_tree():configure(value,interaction_state,facing)
@export_enum("idle","attentive","explaining","success") var interaction_state: String="idle":
	set(value):
		interaction_state=value
		if is_inside_tree():configure(cast_id,value,facing)
@export_enum("east","south_east","south","south_west","west","north_west","north","north_east") var facing: String="south_east":
	set(value):
		facing=value
		if is_inside_tree():configure(cast_id,interaction_state,value)
var definition: Dictionary={}
var _registry: Dictionary={}

func _ready() -> void:configure(cast_id,interaction_state,facing)

func configure(id: String,state: String,direction: String) -> bool:
	if _registry.is_empty():
		if not FileAccess.file_exists(REGISTRY):return false
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
		if not parsed is Dictionary:return false
		_registry=parsed
	var row: Dictionary=_registry.get("actors",{}).get(id,{})
	if row.is_empty():return false
	var frames:=load(str(row.frames_resource)) as SpriteFrames
	var clip:=state+"_"+direction
	if frames==null or not frames.has_animation(clip):return false
	var sprite: AnimatedSprite2D=$Sprite
	sprite.sprite_frames=frames;sprite.position=Vector2(row.sprite_position[0],row.sprite_position[1])
	sprite.scale=Vector2.ONE*float(row.world_scale);sprite.flip_h=false
	sprite.material=null
	if row.alpha_policy=="legacy_cutout":
		var material:=ShaderMaterial.new();material.shader=load("res://assets/shaders/world/level1_flat_cutout.gdshader");sprite.material=material
	sprite.play(clip)
	definition=row
	return true
