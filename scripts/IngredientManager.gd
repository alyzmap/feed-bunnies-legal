extends Node2D

# Malzemelerin yerleştirileceği alan - AreaBackground'dan otomatik alınacak
@export var item_scale: Vector2 = Vector2(0.6, 0.6)  # Daha küçük
@export var show_area: bool = false  # Alan görünür mü? (varsayılan: gizli)

# Malzeme listesi
var ingredient_items: Array[Node2D] = []

# Alan boyutları (AreaBackground'dan alınacak)
var spawn_area_rect: Rect2

func _ready():
	# AreaBackground'dan gerçek alan boyutlarını al
	var background = get_node_or_null("AreaBackground")
	if background and background is ColorRect:
		spawn_area_rect = Rect2(
			background.offset_left,
			background.offset_top,
			background.offset_right - background.offset_left,
			background.offset_bottom - background.offset_top
		)
	else:
		# Fallback: varsayılan alan
		spawn_area_rect = Rect2(-200, -75, 400, 150)
	
	# Alan görünürlüğünü ayarla
	_set_area_visibility(show_area)

# Alan çerçevesini göster/gizle
func _set_area_visibility(should_show: bool):
	var background = get_node_or_null("AreaBackground")
	var border = get_node_or_null("AreaBorder")
	
	if background:
		background.visible = should_show
	if border:
		border.visible = should_show

# Alanı göster
func show_area_border():
	_set_area_visibility(true)

# Alanı gizle
func hide_area_border():
	_set_area_visibility(false)

# Yeni malzeme ekle - rastgele pozisyonda ve sürüklenebilir
func add_ingredient(ingredient_name: String, texture: Texture2D):
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.scale = item_scale
	sprite.name = ingredient_name + "_" + str(ingredient_items.size())
	
	# Texture boyutunu hesapla (scale ile)
	var texture_size = texture.get_size() * item_scale
	var half_width = texture_size.x / 2
	var half_height = texture_size.y / 2
	
	# Rastgele pozisyon hesapla - texture boyutuna göre alan içinde kal
	var min_x = spawn_area_rect.position.x + half_width
	var max_x = spawn_area_rect.position.x + spawn_area_rect.size.x - half_width
	var min_y = spawn_area_rect.position.y + half_height
	var max_y = spawn_area_rect.position.y + spawn_area_rect.size.y - half_height
	
	var random_x := randf_range(min_x, max_x)
	var random_y := randf_range(min_y, max_y)
	sprite.position = Vector2(random_x, random_y)
	
	# Metadata ekle
	sprite.set_meta("ingredient_type", ingredient_name)
	sprite.set_meta("draggable", true)
	sprite.set_meta("is_dragging", false)
	sprite.set_meta("drag_offset", Vector2.ZERO)
	
	# Drag için script ekle
	var drag_script = GDScript.new()
	drag_script.source_code = """
extends Sprite2D

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var velocity: Vector2 = Vector2.ZERO
var gravity: float = 980.0  # Piksel/saniye^2
var ground_y: float = 0.0  # Ana tezgah seviyesi
var food_area_top_y: float = 0.0  # Yemek alanının üst sınırı
var ingredient_manager: Node2D

func _ready():
	ingredient_manager = get_parent()
	
	# Ana tezgah seviyesi (spawn area'nın ALT kenarı)
	if ingredient_manager:
		ground_y = ingredient_manager.spawn_area_rect.position.y + ingredient_manager.spawn_area_rect.size.y - 20
	
	# Yemek alanının üst sınırı
	var food_spawn_area = get_node_or_null('/root/MainScreen/FoodSpawnArea')
	if food_spawn_area:
		food_area_top_y = food_spawn_area.position.y - 40

func _process(delta):
	# Sürüklenmiyorsa fizik uygula
	if not is_dragging:
		# Herhangi bir platform üzerinde değilse düş
		var on_ground = (position.y >= ground_y - 5 and position.y <= ground_y + 5)
		var on_food_area = (position.y >= food_area_top_y - 5 and position.y <= food_area_top_y + 5)
		
		if not on_ground and not on_food_area:
			velocity.y += gravity * delta
			position.y += velocity.y * delta
			
			# Ana tezgaha yaklaştıysa ve üstündeyse yapış
			if position.y >= ground_y and position.y < food_area_top_y:
				position.y = ground_y
				velocity.y = 0
			# Yemek alanına yaklaştıysa ve üstündeyse yapış
			elif position.y >= food_area_top_y:
				position.y = food_area_top_y
				velocity.y = 0
		else:
			# Platform üzerinde, hız sıfır
			velocity.y = 0

func _input(event: InputEvent):
	# Global drag kontrolü - başka biri sürüklüyorsa bu tıklanamaz
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Başka biri sürüklüyorsa bu başlayamaz
				if ingredient_manager and ingredient_manager.is_any_dragging():
					return
				
				var mouse_pos = get_global_mouse_position()
				var sprite_rect = Rect2(global_position - texture.get_size() * scale / 2, texture.get_size() * scale)
				
				if sprite_rect.has_point(mouse_pos):
					is_dragging = true
					drag_offset = global_position - mouse_pos
					velocity = Vector2.ZERO  # Hızı sıfırla
					z_index = 200  # En üste çıkar
					if ingredient_manager:
						ingredient_manager.set_dragging_item(self)
			elif not event.pressed and is_dragging:
				is_dragging = false
				z_index = 100  # Normal seviyeye dön
				if ingredient_manager:
					ingredient_manager.set_dragging_item(null)
				
				# Pot kontrolü (önce pot, sonra çöp)
				if not check_pot_drop():
					# Çöp kutusu kontrolü
					check_trash_drop()
	
	if event is InputEventMouseMotion and is_dragging:
		var new_pos = get_global_mouse_position() + drag_offset
		
		# Global pozisyonu parent'ın local'ine çevir
		if get_parent():
			var local_pos = get_parent().to_local(new_pos)
			position = local_pos

func check_pot_drop() -> bool:
	var pot_base = get_node_or_null('/root/MainScreen/PotBase')
	if pot_base:
		var mouse_pos = get_global_mouse_position()
		var pot_rect = Rect2(pot_base.global_position - pot_base.texture.get_size() * pot_base.scale / 2, 
							  pot_base.texture.get_size() * pot_base.scale)
		
		if pot_rect.has_point(mouse_pos):
			# Pişerken atılmasın!
			var cooking_manager = get_node_or_null('/root/MainScreen/CookingManager')
			if cooking_manager and cooking_manager.is_cooking:
				print("⚠️ Tencere pişerken malzeme atılamaz!")
				return false
			
			var ingredient_type = get_meta("ingredient_type", "")
			print("🍳 POT'A ATILDI: ", ingredient_type)
			print("  Mouse pos: ", mouse_pos)
			print("  Pot rect: ", pot_rect)
			
			# CookingManager'a malzeme ekle
			if cooking_manager:
				print("  ✓ CookingManager bulundu")
				cooking_manager.add_ingredient_to_pot(ingredient_type)
				
				# Malzemeyi yok et
				if ingredient_manager:
					ingredient_manager.remove_ingredient_node(self)
				queue_free()
				return true
			else:
				print("  ❌ CookingManager bulunamadı!")
	return false

func check_trash_drop():
	var trash_basket = get_node_or_null('/root/MainScreen/TrashBasket')
	if trash_basket and trash_basket.has_method('check_drop'):
		var mouse_pos = get_global_mouse_position()
		if trash_basket.check_drop(mouse_pos):
			# Çöpe atıldı, efekt ile yok et
			if ingredient_manager:
				ingredient_manager.remove_ingredient_node(self)
			
			# Yok olma animasyonu: küçül, dön, fade out
			var tween = create_tween()
			tween.set_parallel(true)
			tween.set_trans(Tween.TRANS_BACK)
			tween.set_ease(Tween.EASE_IN)
			tween.tween_property(self, \"scale\", Vector2(0.0, 0.0), 0.3)
			tween.tween_property(self, \"rotation\", rotation + deg_to_rad(360), 0.3)
			tween.tween_property(self, \"modulate:a\", 0.0, 0.3)
			
			# Animasyon bitince yok et
			await tween.finished
			queue_free()
"""
	drag_script.reload()
	sprite.set_script(drag_script)
	sprite.z_index = 100  # Malzemeler varsayılan olarak üstte
	
	add_child(sprite)
	ingredient_items.append(sprite)
	
	print("Malzeme eklendi: ", ingredient_name, " pozisyon: ", sprite.position)
	return sprite

# Global drag kontrolü
var current_dragging_item: Node2D = null

func set_dragging_item(item: Node2D):
	current_dragging_item = item

func is_any_dragging() -> bool:
	return current_dragging_item != null

# Node referansı ile kaldır
func remove_ingredient_node(node: Node2D):
	if node in ingredient_items:
		ingredient_items.erase(node)

# Malzeme say
func get_ingredient_count(ingredient_name: String) -> int:
	var count := 0
	for item in ingredient_items:
		if item.get_meta("ingredient_type", "") == ingredient_name:
			count += 1
	return count

# Belirli bir malzemeyi kaldır
func remove_ingredient(ingredient_name: String) -> bool:
	for item in ingredient_items:
		if item.get_meta("ingredient_type", "") == ingredient_name:
			ingredient_items.erase(item)
			item.queue_free()
			return true
	return false

# Tüm malzemeleri temizle
func clear_all():
	for item in ingredient_items:
		if is_instance_valid(item):
			item.queue_free()
	ingredient_items.clear()

# Debug için alanı çiz
func _draw():
	if Engine.is_editor_hint() and show_area:
		draw_rect(spawn_area_rect, Color(1, 1, 0, 0.3), false, 2.0)
