extends Control
## Local loaded support/attuned pins only. Provider owns destination eligibility/travel.
signal checkpoint_requested(id: String)
var polygons: Array=[]
var checkpoints: Array=[]
var actor:=Vector2.ZERO
var bounds:=Rect2()
var pins: Array[Button]=[]
func _ready() -> void:
	custom_minimum_size=Vector2(0,220);mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(_layout);_layout()
func present(support: Array,records: Array,player: Vector2) -> void:
	polygons=support;checkpoints=records.duplicate(true);actor=player
	var all: Array[Vector2]=[actor]
	for polygon in polygons:
		for point in polygon:all.append(point)
	bounds=Rect2(all[0],Vector2.ZERO)
	for point in all:bounds=bounds.expand(point)
	bounds=bounds.grow(24)
	for pin in pins:remove_child(pin);pin.queue_free()
	pins.clear()
	for record in checkpoints:
		if not record.get("ground_xy") is Vector2:continue
		var pin:=Button.new();pin.text=str(record.id);pin.custom_minimum_size=Vector2(44,44);pin.disabled=not record.get("attuned",false);pin.tooltip_text=str(record.get("name",record.id));add_child(pin);pins.append(pin)
		var id: String=str(record.id);pin.pressed.connect(func():checkpoint_requested.emit(id))
	_layout()
func mapped(p: Vector2) -> Vector2:
	var scale:=minf(maxf(1,size.x-52)/maxf(1,bounds.size.x),maxf(1,size.y-52)/maxf(1,bounds.size.y))
	return size/2+(p-bounds.get_center())*scale
func _layout() -> void:
	var index:=0
	for record in checkpoints:
		if not record.get("ground_xy") is Vector2:continue
		if index<pins.size():pins[index].size=Vector2(44,44);pins[index].position=mapped(record.ground_xy)-Vector2(22,22)
		index+=1
	queue_redraw()
func _draw() -> void:
	draw_style_box(preload("res://Scripts/UI/Support/support_style.gd").paper(),Rect2(Vector2.ZERO,size))
	for polygon in polygons:
		var points:=PackedVector2Array()
		for p in polygon:points.append(mapped(p))
		if points.size()>=3:draw_colored_polygon(points,Color("bfd0b1"))
	draw_circle(mapped(actor),6,Color("42677e"))
