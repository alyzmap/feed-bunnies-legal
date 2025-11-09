extends Sprite2D

signal shop_open_changed(is_open: bool)

@export var open_texture: Texture2D
@export var close_texture: Texture2D
@export var default_open: bool = false
@export var hover_scale: float = 1.08
@export var hover_tween_time: float = 0.15

var _base_scale: Vector2
var _hovering: bool = false
var _hover_tween: Tween

var is_open: bool

func _ready():
	is_open = default_open
	_base_scale = scale
	_update_visual()
	# İlk durumda CustomerManager'a haber ver (1 frame bekle)
	await get_tree().process_frame
	var manager := get_node_or_null("../CustomerManager")
	if manager and manager.has_method("set_shop_open"):
		manager.set_shop_open(is_open)

func _input(event: InputEvent) -> void:
	# Mouse tıklaması
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _is_point_over(event.position):
			_toggle()
	# Dokunmatik
	elif event is InputEventScreenTouch and event.pressed:
		if _is_point_over(event.position):
			_toggle()
	# Hover (sadece mouse)
	elif event is InputEventMouseMotion:
		var over := _is_point_over(event.position)
		if over and not _hovering:
			_hovering = true
			_start_hover_tween(true)
		elif (not over) and _hovering:
			_hovering = false
			_start_hover_tween(false)

func _is_point_over(global_point: Vector2) -> bool:
	if texture == null:
		return false
	var local_pos: Vector2 = to_local(global_point)
	# Mobil için daha geniş hitbox - %50 büyütüldü
	var scaled_size: Vector2 = texture.get_size() * scale * 1.5
	var half: Vector2 = scaled_size * 0.5
	# Sprite2D varsayılan olarak centered = true kabul ediyoruz
	return abs(local_pos.x) <= half.x and abs(local_pos.y) <= half.y

func _toggle():
	is_open = not is_open
	_update_visual()
	emit_signal("shop_open_changed", is_open)
	# CustomerManager'a aktar
	var manager := get_node_or_null("../CustomerManager")
	if manager and manager.has_method("set_shop_open"):
		manager.set_shop_open(is_open)
	# Kapatınca aktif müşterileri temizleme isteği customer manager'a sinyal üzerinden değil doğrudan yapılabilir.
	if not is_open and manager and manager.has_method("force_clear_customers"):
		manager.force_clear_customers()

func _update_visual():
	if is_open:
		if open_texture:
			texture = open_texture
	else:
		if close_texture:
			texture = close_texture

func _start_hover_tween(entering: bool):
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	var target: Vector2 = _base_scale * (hover_scale if entering else 1.0)
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", target, hover_tween_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
