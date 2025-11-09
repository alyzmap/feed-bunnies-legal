extends Node2D

# Malzemeden tarife çevirme tablosu
var ingredient_to_recipe_name: Dictionary = {
	"egg_base": "egg",
	"bread": "bread",
	"banana_chalk": "banana",
	"blueberry_chalk": "blueberry",
	"cheese": "cheese",
	"salami": "salami",
	"flour_base": "flour",
	"milk": "milk",
	"butter": "butter",
	"salt": "salt",
	"sugar": "sugar"
}

# Bozulmuş yemek eşlemeleri (normal -> mess)
var spoiled_food_map: Dictionary = {
	"Banana_Mess": "Banana_Mess",
	"Blueberry_Mess": "Blueberry_Mess",
	"Monster_Cocktail": "Monster_Cocktail",
	"Scat_Porridge": "Scat_Porridge",
	"Salty_Porridge": "Salty_Porridge"
}

# Yemek bozulma süresi
var food_spoil_time: float = 30.0  # 30 saniye sonra bozulur
var food_timers: Dictionary = {}  # food_sprite -> kalan süre
var timer_update_interval: float = 0.1  # 0.1 saniyede bir güncelle (optimize)
var timer_update_accumulator: float = 0.0

@onready var pot_base: Sprite2D = $"../PotBase"
@onready var pot_lid = $PotLid
@onready var pot_hot_indicator = $PotHotIndicator
@onready var recipe_buttons_container = $RecipeButtonsContainer
@onready var food_spawn_area = $"../FoodSpawnArea"  # Yemeklerin spawn olacağı alan
@onready var clear_pot_button = $ClearPotButton  # Kazanı sıfırlama butonu

# Texture'lar
var pot_base_normal: Texture2D = preload("res://assets/pot_base.png")
var pot_base_hot: Texture2D = preload("res://assets/pot_base_hot.png")

# Pot içindeki malzemeler
var ingredients_in_pot: Array[String] = []

# Pişirme durumu
var is_cooking: bool = false
var current_recipe = null

# Yemek spawn sistemi
var food_spawn_index: int = 0  # Sıradaki yemek pozisyonu
var food_spawn_points: Array[Marker2D] = []  # Point6, Point7, Point8

func _ready():
	# Pot_lid başlangıçta gizli
	pot_lid.visible = false
	pot_hot_indicator.visible = false
	recipe_buttons_container.visible = false
	
	# Yemek spawn pointlerini topla
	var main_screen = get_node("/root/MainScreen")
	for point_name in ["point6", "point7", "point8", "point9", "point10"]:
		var point = main_screen.get_node_or_null(point_name)
		if point:
			food_spawn_points.append(point)
	
	# Process aktif et (yemek bozulması için)
	set_process(true)
	print("✓ Yemek spawn pointleri: ", food_spawn_points.size())
	
	# Clear button sinyali
	if clear_pot_button:
		clear_pot_button.pressed.connect(_on_clear_pot_pressed)
		_update_clear_button_visibility()

func _process(delta):
	# Yemek bozulma zamanlayıcıları (optimize: her 0.1s'de bir güncelle)
	timer_update_accumulator += delta
	var should_update_labels: bool = timer_update_accumulator >= timer_update_interval
	
	if should_update_labels:
		timer_update_accumulator = 0.0
	
	var foods_to_spoil: Array = []
	for food in food_timers.keys():
		if is_instance_valid(food):
			food_timers[food] -= delta
			
			# Label güncellemesini sadece 0.1s'de bir yap
			if should_update_labels:
				_update_food_timer_label(food, food_timers[food])
			
			if food_timers[food] <= 0:
				foods_to_spoil.append(food)
		else:
			food_timers.erase(food)
	
	# Toplu bozulma işlemi
	for food in foods_to_spoil:
		_spoil_food(food)

# Malzeme pot'a atıldığında
func add_ingredient_to_pot(ingredient_name: String):
	if is_cooking:
		print("Pişirme devam ediyor, yeni malzeme eklenemez!")
		return
	
	# Asset ismini tarif ismine çevir
	var recipe_ingredient = ingredient_to_recipe_name.get(ingredient_name, ingredient_name)
	print("➕ Malzeme ekleniyor: ", ingredient_name, " → ", recipe_ingredient)
	
	ingredients_in_pot.append(recipe_ingredient)
	print("  Pot'taki malzemeler: ", ingredients_in_pot)
	
	# Clear button'u göster
	_update_clear_button_visibility()
	
	# Tarifleri kontrol et ve seçenekleri göster
	_check_recipes()

# RecipeDatabase'den eşleşen tarifleri bul
func _check_recipes():
	print("=== TARİF KONTROLÜ ===")
	print("Pot'taki malzemeler: ", ingredients_in_pot)
	
	var recipe_db = get_node_or_null("/root/RecipeDatabase")
	if not recipe_db:
		print("❌ RecipeDatabase bulunamadı!")
		return
	
	print("✓ RecipeDatabase bulundu")
	print("Toplam tarif sayısı: ", recipe_db.recipes.size())
	
	# Mevcut malzemelerle yapılabilecek tarifleri bul
	var possible_recipes = []
	for recipe_name in recipe_db.recipes.keys():
		var recipe_ingredients = recipe_db.recipes[recipe_name]  # Direkt Array
		
		print("Tarif kontrol: ", recipe_name, " -> ", recipe_ingredients)
		
		# Malzeme sayısı eşit mi ve tüm malzemeler var mı?
		if recipe_ingredients.size() == ingredients_in_pot.size():
			var all_match = true
			var temp_pot = ingredients_in_pot.duplicate()
			
			for ingredient in recipe_ingredients:
				if ingredient in temp_pot:
					temp_pot.erase(ingredient)
				else:
					all_match = false
					break
			
			if all_match and temp_pot.is_empty():
				possible_recipes.append(recipe_name)
				print("  ✓ Eşleşti!")
	
	print("Bulunan tarifler: ", possible_recipes)
	
	if possible_recipes.size() > 0:
		_show_recipe_options(possible_recipes)
	else:
		print("❌ Bu malzemelerle tarif bulunamadı")

# Tarif seçeneklerini yuvarlak butonlarda göster
func _show_recipe_options(recipes: Array):
	print("=== TARİF SEÇENEKLERİ GÖSTERİLİYOR ===")
	print("Bulunan tarifler: ", recipes)
	
	# Eski butonları temizle
	for child in recipe_buttons_container.get_children():
		child.queue_free()
	
	# Pot'un ekran pozisyonunu al (CanvasLayer için global_position kullan)
	var pot_screen_pos = pot_base.global_position
	print("✓ Pot global pozisyonu: ", pot_screen_pos)
	
	# Her tarif için yuvarlak buton oluştur
	var button_size = 80  # Buton boyutu
	var button_spacing = 90  # Butonlar arası mesafe
	var total_width = recipes.size() * button_spacing - 10
	var start_x = pot_screen_pos.x - (total_width / 2.0) + (button_size / 2.0)
	var buttons_y = pot_screen_pos.y - 200  # Pot'un 200px üstü
	
	for i in range(recipes.size()):
		var recipe_name = recipes[i]
		
		# Control container (tam yuvarlak arka plan)
		var container = Control.new()
		container.custom_minimum_size = Vector2(button_size, button_size)
		container.size = Vector2(button_size, button_size)
		container.position = Vector2(start_x + i * button_spacing - button_size/2, buttons_y - button_size/2)
		
		# Yuvarlak arka plan (Panel)
		var panel = Panel.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 0.9, 0.7, 0.95)
		style.corner_radius_top_left = button_size / 2
		style.corner_radius_top_right = button_size / 2
		style.corner_radius_bottom_left = button_size / 2
		style.corner_radius_bottom_right = button_size / 2
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.8, 0.6, 0.4, 1.0)
		panel.add_theme_stylebox_override("panel", style)
		panel.size = Vector2(button_size, button_size)
		panel.position = Vector2(0, 0)
		container.add_child(panel)
		
		# Texture button (yemek görseli)
		var button = TextureButton.new()
		var food_texture_path = "res://assets/" + recipe_name + ".png"
		var food_texture = load(food_texture_path)
		
		if food_texture:
			button.texture_normal = food_texture
			button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			button.ignore_texture_size = true
			button.size = Vector2(button_size - 16, button_size - 16)  # Kenarlarda boşluk
			button.position = Vector2(8, 8)
			
			button.pressed.connect(_on_recipe_selected.bind(recipe_name))
			container.add_child(button)
			recipe_buttons_container.add_child(container)
			print("✓ Buton eklendi: ", recipe_name, " pozisyon: ", container.position)
	
	recipe_buttons_container.visible = true
	print("✓ Container görünür, child count: ", recipe_buttons_container.get_child_count())

# Tarif seçildi
func _on_recipe_selected(recipe_name: String):
	print("Tarif seçildi: ", recipe_name)
	current_recipe = recipe_name
	_hide_recipe_options()
	
	# Direkt pişirmeye başla (pot'a tıklamayı bekleme)
	start_cooking()

# Tarif seçeneklerini gizle
func _hide_recipe_options():
	recipe_buttons_container.visible = false
	# Tüm butonları temizle
	for child in recipe_buttons_container.get_children():
		child.queue_free()

# Pot'a tıklandığında pişirmeyi başlat
func start_cooking():
	if not current_recipe:
		print("Önce tarif seçmelisiniz!")
		return
	
	if is_cooking:
		print("Zaten pişiyor!")
		return
	
	is_cooking = true
	print("Pişirme başladı: ", current_recipe)
	
	# Clear button'u gizle
	_update_clear_button_visibility()
	
	# Pot_base_hot göster
	pot_base.texture = pot_base_hot
	pot_hot_indicator.visible = true
	
	# Pot_lid göster ve animasyon başlat
	pot_lid.visible = true
	_animate_lid()
	
	# 3 saniye sonra pişirme biter
	await get_tree().create_timer(3.0).timeout
	_finish_cooking()

# Kapak animasyonu (yukarı-aşağı hafif hareket)
func _animate_lid():
	if not is_cooking:
		return
	
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(pot_lid, "position:y", pot_lid.position.y - 1.5, 0.3)  # Daha az hareket
	tween.tween_property(pot_lid, "position:y", pot_lid.position.y, 0.3)

# Pişirme bitti
func _finish_cooking():
	is_cooking = false
	print("Pişti: ", current_recipe)
	
	# TARİFİ AÇMA - İLK KEZ YAPINCA OTOMATİK AÇILSIN
	UnlockManager.unlock_recipe(current_recipe)
	
	# Pot normal haline dön
	pot_base.texture = pot_base_normal
	pot_hot_indicator.visible = false
	pot_lid.visible = false
	
	# Yemek sprite'ı oluştur ve ekrana ekle
	_spawn_cooked_food(current_recipe)
	
	# Temizle
	ingredients_in_pot.clear()
	current_recipe = null
	
	# Clear button'u gizle
	_update_clear_button_visibility()

# Pişmiş yemeği spawn et
func _spawn_cooked_food(recipe_name: String):
	var food_sprite = Sprite2D.new()
	var food_texture_path = "res://assets/" + recipe_name + ".png"
	food_sprite.texture = load(food_texture_path)
	
	# Point6, Point7, Point8'e sırayla spawn et
	var spawn_position = Vector2.ZERO
	if food_spawn_points.size() > 0:
		var point = food_spawn_points[food_spawn_index % food_spawn_points.size()]
		spawn_position = point.global_position  # global_position kullan!
		food_spawn_index += 1
		print("✓ Yemek spawn oldu: ", recipe_name, " point: ", point.name, " global_pozisyon: ", spawn_position)
	else:
		# Fallback: pot'un yanı
		spawn_position = pot_base.global_position + Vector2(0, -50)
		print("⚠ Spawn point bulunamadı, fallback kullanıldı")
	
	food_sprite.scale = Vector2(0.2, 0.2)  # Daha küçük yemek
	food_sprite.z_index = 100
	
	# Yemeklere metadata ekle
	food_sprite.set_meta("food_type", recipe_name)
	food_sprite.set_meta("is_food", true)
	
	# SÜRÜKLEME SCRİPTİ EKLE
	_add_food_drag_script(food_sprite)
	
	# MainScreen'e ekle ve global pozisyon ayarla
	get_node("/root/MainScreen").add_child(food_sprite)
	food_sprite.global_position = spawn_position  # Eklendikten SONRA global_position ata!
	
	# Yemek bozulma zamanlayıcısı başlat
	food_timers[food_sprite] = food_spoil_time
	
	# Timer label ekle
	_create_food_timer_label(food_sprite)
	
	print("✓ Yemek eklendi: ", recipe_name, " global_pozisyon: ", food_sprite.global_position)

# Yemeğe sürükleme scripti ekle
func _add_food_drag_script(food: Sprite2D):
	var drag_script = GDScript.new()
	drag_script.source_code = """
extends Sprite2D

var is_dragging = false
var drag_offset = Vector2.ZERO

func _ready():
	set_process_input(true)

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var food_rect = Rect2(global_position - texture.get_size() * scale / 2, texture.get_size() * scale)
		
		if event.pressed and food_rect.has_point(mouse_pos):
			# Aynı noktada birden fazla yemek varsa, en üsttekini tut
			if _is_topmost_food_at_position(mouse_pos):
				is_dragging = true
				drag_offset = global_position - mouse_pos
				z_index = 200  # Sürüklerken en üstte
		elif not event.pressed and is_dragging:
			is_dragging = false
			z_index = 100  # Bırakınca normal
			_check_customer_delivery()

func _is_topmost_food_at_position(pos: Vector2) -> bool:
	# Optimize: Tüm çocukları taramamak için direkt food check
	var main_screen = get_node_or_null('/root/MainScreen')
	if not main_screen:
		return true
	
	var max_z_index = z_index
	var children_count = main_screen.get_child_count()
	
	# Optimize: Geriye doğru döngü (yüksek z_index'ler genelde sonda)
	for i in range(children_count - 1, -1, -1):
		var child = main_screen.get_child(i)
		
		# Optimize: Type check + meta check birleşik
		if child is Sprite2D and child != self:
			if not child.has_meta('is_food'):
				continue
			
			# Optimize: Rect hesabı sadece is_food olanlar için
			var child_rect = Rect2(
				child.global_position - child.texture.get_size() * child.scale / 2,
				child.texture.get_size() * child.scale
			)
			
			if child_rect.has_point(pos) and child.z_index > max_z_index:
				return false  # Daha üstte yemek var
	
	return true  # Bu yemek en üstte

func _process(delta):
	if is_dragging:
		global_position = get_global_mouse_position() + drag_offset

func _check_customer_delivery():
	var customer_manager = get_node_or_null('/root/MainScreen/CustomerManager')
	if not customer_manager:
		return
	
	var food_type = get_meta('food_type', '')
	if food_type == '':
		return
	
	# Tüm müşterileri kontrol et
	var customers = customer_manager.get_children()
	for customer in customers:
		if customer is Sprite2D and customer.visible:
			# Müşterinin rect'ini hesapla
			var customer_rect = Rect2(
				customer.global_position - customer.texture.get_size() * customer.scale / 2,
				customer.texture.get_size() * customer.scale
			)
			
			# Yemek müşterinin üzerinde mi?
			if customer_rect.has_point(global_position):
				# Müşterinin siparişini kontrol et
				var customer_order_dict = customer_manager.customer_order
				if customer_order_dict.has(customer):
					var order_sprite = customer_order_dict[customer]
					var desired_food = order_sprite.get_meta('food_name', '')
					
					print('🍽️ Teslim denemesi: ', food_type, ' → Müşteri istedi: ', desired_food)
					
					# BOZUK YEMEK KONTROLÜ
					var is_spoiled = get_meta('is_spoiled', false)
					if is_spoiled:
						print(tr("SPOILED_FOOD_PENALTY").format({"penalty": 20}))
						
						# GameOverUI'ye bildir
						var game_over_ui = get_node_or_null('/root/MainScreen/GameOverUI')
						if game_over_ui and game_over_ui.has_method('add_spoiled_food'):
							game_over_ui.add_spoiled_food()
						
						var money_manager = get_node_or_null('/root/MainScreen/MoneyManager')
						if money_manager:
							money_manager.remove_money(20)  # 50 → 20 (daha az ceza)
						
						# Müşteriyi kızgın şekilde gönder
						customer_manager.return_customer_to_pool(customer)
						
						# Yemeği sil
						queue_free()
						return
					
					if food_type == desired_food:
						# DOĞRU SİPARİŞ!
						print('✅ Doğru sipariş! Para kazandın!')
						
						# TARİF KARMAŞIKLIĞINA GÖRE PARA - DAHA FAZLA VER!
						var recipe_db = RecipeDatabase
						var ingredient_count = 1
						if recipe_db.recipes.has(food_type):
							ingredient_count = recipe_db.recipes[food_type].size()
						
						# Malzeme sayısına göre ödül: 1→8, 2→12, 3→18, 4+→25 (daha yavaş ilerleme)
						var reward = 8
						if ingredient_count == 2:
							reward = 12
						elif ingredient_count == 3:
							reward = 18
						elif ingredient_count >= 4:
							reward = 25
						
						var money_manager = get_node_or_null('/root/MainScreen/MoneyManager')
						if money_manager:
							money_manager.add_money(reward)
							print('💰 Para kazandın: ', reward, ' (', ingredient_count, ' malzemeli tarif)')
							
							# Para animasyonu göster - DOĞRUDAN BURADAKİ KODLA
							var money_container = Node2D.new()
							money_container.global_position = customer.global_position
							money_container.z_index = 200
							
							var money_icon = Sprite2D.new()
							var icon_texture = load('res://assets/coinr.png')
							if icon_texture:
								money_icon.texture = icon_texture
								money_icon.scale = Vector2(0.15, 0.15)
								money_container.add_child(money_icon)
							
							var money_label = Label.new()
							money_label.text = '+' + str(reward)
							money_label.position = Vector2(25, -10)
							money_label.add_theme_font_size_override('font_size', 24)
							money_label.add_theme_color_override('font_color', Color.GOLD)
							money_label.add_theme_color_override('font_outline_color', Color.BLACK)
							money_label.add_theme_constant_override('outline_size', 4)
							money_container.add_child(money_label)
							
							get_node('/root/MainScreen').add_child(money_container)
							
							var money_label_node = get_node_or_null('/root/MainScreen/MoneyLabel')
							var target_pos = Vector2(650, 50)
							if money_label_node:
								target_pos = money_label_node.global_position
							
							var tween = get_tree().create_tween()
							tween.set_parallel(true)
							tween.tween_property(money_container, 'global_position', customer.global_position + Vector2(0, -50), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
							tween.tween_property(money_container, 'modulate:a', 1.0, 0.3)
							tween.set_parallel(false)
							tween.tween_interval(0.1)
							tween.tween_property(money_container, 'global_position', target_pos, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
							tween.tween_property(money_container, 'scale', Vector2(0.3, 0.3), 0.5).set_trans(Tween.TRANS_QUAD)
							tween.tween_property(money_container, 'modulate:a', 0.0, 0.2)
							tween.tween_callback(money_container.queue_free)
						
						# Müşteriyi geri gönder
						customer_manager.return_customer_to_pool(customer)
						
						# Yemeği sil
						queue_free()
						return
					else:
						# YANLIŞ SİPARİŞ - CEZA VE MÜŞTERİ GİTSİN!
						print(tr("WRONG_FOOD_PENALTY").format({"penalty": 30}))
						
						# GameOverUI'ye bildir
						var game_over_ui = get_node_or_null('/root/MainScreen/GameOverUI')
						if game_over_ui and game_over_ui.has_method('add_wrong_food'):
							game_over_ui.add_wrong_food()
						
						var money_manager = get_node_or_null('/root/MainScreen/MoneyManager')
						if money_manager:
							money_manager.remove_money(30)  # 30 para ceza
						
						# Müşteriyi kızgın şekilde gönder
						customer_manager.return_customer_to_pool(customer)
						
						# Yemeği sil
						queue_free()
						return
"""
	drag_script.reload()
	food.set_script(drag_script)

# FoodSpawnArea rect'ini al
func _get_spawn_area_rect() -> Rect2:
	if not food_spawn_area:
		print("❌ FoodSpawnArea bulunamadı!")
		return Rect2(0, 0, 100, 100)
	
	var background = food_spawn_area.get_node_or_null("AreaBackground")
	if background and background is ColorRect:
		# Parent'ın pozisyonu + ColorRect offset'leri
		var area_x = food_spawn_area.position.x + background.offset_left
		var area_y = food_spawn_area.position.y + background.offset_top
		var area_w = background.offset_right - background.offset_left
		var area_h = background.offset_bottom - background.offset_top
		
		var rect = Rect2(area_x, area_y, area_w, area_h)
		print("✓ FoodSpawnArea rect: ", rect)
		return rect
	
	print("⚠ AreaBackground bulunamadı, fallback kullanılıyor")
	return Rect2(food_spawn_area.position.x - 100, food_spawn_area.position.y - 50, 200, 100)

# Kazanı sıfırlama butonu basıldığında
func _on_clear_pot_pressed():
	if is_cooking:
		print("⚠ Pişirme devam ediyor, sıfırlama yapılamaz!")
		return
	
	ingredients_in_pot.clear()
	_hide_recipe_options()
	print("✓ Kazan temizlendi, malzemeler sıfırlandı")
	_update_clear_button_visibility()

# Clear button görünürlüğünü güncelle
func _update_clear_button_visibility():
	if clear_pot_button:
		clear_pot_button.visible = ingredients_in_pot.size() > 0 and not is_cooking

# Yemeği bozulmuş hale getir
func _spoil_food(food_sprite: Sprite2D):
	if not is_instance_valid(food_sprite):
		food_timers.erase(food_sprite)
		return
	
	# Rastgele bozulmuş yemek seç
	var spoiled_foods = ["Banana_Mess", "Blueberry_Mess", "Monster_Cocktail", "Scat_Porridge", "Salty_Porridge"]
	var spoiled_name = spoiled_foods.pick_random()
	
	# Texture'ı değiştir
	var spoiled_texture_path = "res://assets/" + spoiled_name + ".png"
	var spoiled_texture = load(spoiled_texture_path)
	if spoiled_texture:
		food_sprite.texture = spoiled_texture
		food_sprite.set_meta("food_type", spoiled_name)
		food_sprite.set_meta("is_spoiled", true)
		print("🤢 Yemek bozuldu: ", spoiled_name)
	
	food_timers.erase(food_sprite)
	
	# Timer label'ı sil
	_remove_food_timer_label(food_sprite)

# Timer label oluştur
func _create_food_timer_label(food_sprite: Sprite2D):
	var timer_label = Label.new()
	timer_label.name = "TimerLabel"
	timer_label.add_theme_font_size_override("font_size", 20)
	timer_label.add_theme_color_override("font_color", Color.WHITE)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_label.add_theme_constant_override("outline_size", 3)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.z_index = 101
	
	# Yemeğin üstüne yerleştir
	food_sprite.add_child(timer_label)
	timer_label.position = Vector2(0, -80)  # Yemeğin üstünde

# Timer label'ı güncelle
func _update_food_timer_label(food_sprite: Sprite2D, time_left: float):
	var timer_label = food_sprite.get_node_or_null("TimerLabel")
	if timer_label:
		var seconds = int(ceil(time_left))
		timer_label.text = str(seconds) + "s"
		
		# Renkli uyarı (10sn kaldıysa kırmızı)
		if seconds <= 10:
			timer_label.add_theme_color_override("font_color", Color.RED)
		elif seconds <= 20:
			timer_label.add_theme_color_override("font_color", Color.YELLOW)
		else:
			timer_label.add_theme_color_override("font_color", Color.WHITE)

# Timer label'ı sil
func _remove_food_timer_label(food_sprite: Sprite2D):
	if is_instance_valid(food_sprite):
		var timer_label = food_sprite.get_node_or_null("TimerLabel")
		if timer_label:
			timer_label.queue_free()

# Bozuk yemek kontrol fonksiyonu (müşteri tesliminde kullanılır)
func is_food_spoiled(food_sprite: Sprite2D) -> bool:
	return food_sprite.get_meta("is_spoiled", false)
