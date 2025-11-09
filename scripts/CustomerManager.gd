extends Node # Bu komut dosyası bir Node düğümüne bağlı

# @onready, düğümler hazır olduğunda onlara erişmemizi sağlar.
# Artık bu düğümler, script'in bağlı olduğu düğümün (CustomerManager) altındadır.
@onready var spawn_timer = $SpawnTimer	     
@onready var spawn_points_node = $SpawnPoints  # Müşteri spawn noktaları

# Müşteri çağırma süresi aralığı (Daha az sık gelsin)
var min_spawn_time := 10.0 
var max_spawn_time := 25.0 

# Progresif zorluk sistemi
var game_time: float = 0.0  # Oyun süresi (saniye)
var max_concurrent_customers: int = 1  # Aynı anda maksimum müşteri sayısı

# Müşteri sabır sistemi
var customer_patience_time: float = 45.0  # Ortalama sabır süresi
var patience_min: float = 35.0  # Minimum sabır (sabırsız müşteriler)
var patience_max: float = 55.0  # Maximum sabır (sabırlı müşteriler)
var customer_patience: Dictionary = {}  # customer -> kalan süre
var customer_patience_circles: Dictionary = {}  # customer -> Node2D (circle görseli)

# Kullanıma hazır müşterilerin tutulacağı dinamik liste
var available_customers: Array = []

# Hangi noktanın/hangi müşterinin dolu olduğunu takip etmek için sözlükler
var point_to_customer: Dictionary = {}
var customer_to_point: Dictionary = {}
var active_wobble_tweens: Dictionary = {} # customer -> Tween
var customer_order: Dictionary = {} # customer -> Sprite2D (sipariş görseli)
var is_shop_open: bool = false

func _ready():
	# 1) Başlangıçta müşteri havuzunu (m1, m2, ... isimli Sprite2D'ler) otomatik topla
	for child in get_children():
		if _is_customer_node(child):
			available_customers.append(child)
			# Hepsini görünmez yap (güvence)
			child.visible = false

	# 2) Timer'ın sinyalini koda bağla
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	# 3) Timer'ı başlatma - sadece dükkan açıldığında başlayacak
	# set_random_spawn_time()
	# spawn_timer.start()
	
	# 4) Progresif zorluk için process aktif et
	set_process(true)

func _process(delta):
	if is_shop_open:
		game_time += delta
		_update_difficulty()
		_update_customer_patience(delta)

# Basit müşteri düğümü kontrolü: adı n + sayı ve Sprite2D olmalı
func _is_customer_node(n: Node) -> bool:
	if n is Sprite2D and n.name.begins_with("n") and n.name.length() > 1:
		var tail := n.name.substr(1)
		var only_digits := true
		for c in tail:
			if c < "0" or c > "9":
				only_digits = false
				break
		return only_digits
	return false

# Rastgele bir süre belirler ve Timer'a ayarlar
func set_random_spawn_time():
	var random_time := randf_range(min_spawn_time, max_spawn_time)
	spawn_timer.wait_time = random_time

# Progresif zorluk güncelle
func _update_difficulty():
	# 0-60s: 1 müşteri, 60-150s: 2 müşteri, 150s+: 3 müşteri (daha sık gelsinler!)
	if game_time < 60.0:
		max_concurrent_customers = 1
		min_spawn_time = 12.0  # 20 → 12 (daha sık!)
		max_spawn_time = 20.0  # 35 → 20
	elif game_time < 150.0:
		max_concurrent_customers = 2
		min_spawn_time = 10.0  # 18 → 10
		max_spawn_time = 18.0  # 30 → 18
	else:
		max_concurrent_customers = 3
		min_spawn_time = 8.0   # 15 → 8
		max_spawn_time = 15.0  # 25 → 15

# Timer bittiğinde çalışacak fonksiyon
func _on_spawn_timer_timeout():
	# Dükkan kapalıysa spawn yapma, yalnızca timer'ı döndür
	if not is_shop_open:
		set_random_spawn_time()
		spawn_timer.start()
		return
	
	# Aktif müşteri sayısını kontrol et
	var active_count = point_to_customer.size()
	if active_count >= max_concurrent_customers:
		# Limit doldu, bekle
		set_random_spawn_time()
		spawn_timer.start()
		return
	
	# Müşteriyi havuzdan çağır (uygun nokta varsa)
	spawn_customer_from_pool()
	# Yeni rastgele süreyi ayarla ve Timer'ı yeniden başlat
	set_random_spawn_time()
	spawn_timer.start()

# Öncelikli boş nokta bul (Point1, Point2, ... sırasına göre)
func _get_next_free_spawn_point() -> Node:
	var points := _get_sorted_spawn_points()
	for p in points:
		if not point_to_customer.has(p):
			return p
	return null

# SpawnPoints altındaki Marker2D'leri isimlerindeki sayıya göre sırala
func _get_sorted_spawn_points() -> Array:
	var points: Array = []
	for child in spawn_points_node.get_children():
		if child is Marker2D:
			points.append(child)
	points.sort_custom(func(a, b):
		return _extract_index(a.name) < _extract_index(b.name)
	)
	return points

# "Point12" -> 12 (bulamazsa büyük bir sayı dönsün ki sona düşsün)
func _extract_index(node_name: String) -> int:
	var digits := ""
	for c in node_name:
		if c >= "0" and c <= "9":
			digits += c
	if digits == "":
		return 99999
	return int(digits)

# Havuzdan rastgele bir müsait müşteri seç
func _get_available_customer() -> Node:
	if available_customers.is_empty():
		return null
	var chosen = available_customers.pick_random()
	available_customers.erase(chosen)
	return chosen

# Havuzdan müşteri seçip öncelikli boş noktaya yerleştir
func spawn_customer_from_pool():
	var point := _get_next_free_spawn_point()
	if point == null:
		# Tüm noktalar dolu -> spawn yok
		print("Spawn iptal: tüm noktalar dolu.")
		return

	var customer := _get_available_customer()
	if customer == null:
		# Müsait müşteri yok
		print("Spawn iptal: müsait müşteri kalmadı.")
		return

	# Konumlandır ve görünür yap
	customer.global_position = point.global_position
	customer.visible = true

	# Eşlemeleri kaydet
	point_to_customer[point] = customer
	customer_to_point[customer] = point

	# Hafif sallanma animasyonu ekle (y ekseninde sine benzeri yukarı-aşağı)
	_start_wobble(customer)

	# Rastgele yemek seç ve ilgili food point'e göster
	_show_order(customer, point)

# Müşteriyi havuza geri gönderme (işi bittiğinde çağır)
func return_customer_to_pool(customer_node: Node):
	# Görünmez yap ve ekran dışına taşı
	customer_node.visible = false
	customer_node.global_position = Vector2.ZERO
	
	# Rotasyonu sıfırla (ters dönme sorunu çözümü)
	if customer_node is Node2D:
		customer_node.rotation_degrees = 0

	# Sallanma tween'ini temizle
	_stop_wobble(customer_node)

	# Sipariş görselini kaldır
	_remove_order(customer_node)

	# Eşleştiği noktayı boşalt
	if customer_to_point.has(customer_node):
		var point = customer_to_point[customer_node]
		customer_to_point.erase(customer_node)
		if point_to_customer.get(point) == customer_node:
			point_to_customer.erase(point)

	# Havuz listesine geri ekle
	if not available_customers.has(customer_node):
		available_customers.append(customer_node)

	print("Müşteri ", customer_node.name, " havuza geri döndü.")

# Açık/Kapalı bilgisini SignController'dan alır
func set_shop_open(open: bool) -> void:
	is_shop_open = open
	var state_text: String = "OPEN" if open else "CLOSE"
	print("Dükkan durumu: ", state_text)
	
	if open:
		# Dükkan açıldığında timer'ı başlat - İLK MÜŞTERİ HEMEN GELSİN!
		if spawn_timer and not spawn_timer.is_stopped():
			spawn_timer.stop()
		# İlk müşteri için kısa süre (3 saniye)
		spawn_timer.wait_time = 3.0
		spawn_timer.start()
		print("✓ Müşteri timer'ı başlatıldı (ilk müşteri 3 saniyede)")
	else:
		# Dükkan kapandığında timer'ı durdur ve müşterileri gönder
		if spawn_timer:
			spawn_timer.stop()
		force_clear_customers()
		print("✓ Müşteri timer'ı durduruldu")

# Tüm aktif müşterileri geri havuza gönder
func force_clear_customers() -> void:
	var to_return: Array = []
	for point in point_to_customer.keys():
		var c = point_to_customer[point]
		if c:
			to_return.append(c)
	for c in to_return:
		return_customer_to_pool(c)

# Wobble animasyonu başlat: sağa-sola ve yukarı-aşağı sallanma
func _start_wobble(customer: Node):
	if active_wobble_tweens.has(customer):
		return # Zaten aktif
	if not (customer is Node2D):
		return # Konumsal animasyon için Node2D olmalı
	var tween: Tween = create_tween()
	active_wobble_tweens[customer] = tween
	var base_pos: Vector2 = (customer as Node2D).position
	var y_amplitude: float = 4.0  # Yukarı-aşağı (daha az)
	var x_amplitude: float = 6.0  # Sağa-sola
	var duration: float = 2.0  # Daha yavaş
	
	# Sonsuz döngü - smooth sağa-sola-sağa-sola hareketi
	tween.set_loops()
	
	# Sağa git
	tween.tween_property(customer, "position:x", base_pos.x + x_amplitude, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Sola git
	tween.tween_property(customer, "position:x", base_pos.x - x_amplitude, duration * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Tekrar sağa (başa dön)
	tween.tween_property(customer, "position:x", base_pos.x, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# Paralel olarak hafif yukarı-aşağı hareketi
	tween.set_parallel(true)
	tween.tween_property(customer, "position:y", base_pos.y - y_amplitude, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_parallel(false)
	tween.tween_property(customer, "position:y", base_pos.y + y_amplitude, duration * 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(customer, "position:y", base_pos.y, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Wobble animasyonunu durdur
func _stop_wobble(customer: Node):
	if active_wobble_tweens.has(customer):
		var tween: Tween = active_wobble_tweens[customer]
		if tween.is_valid():
			# Tween'i öldürmek için durdurmak yeterli (Godot otomatik temizler)
			# Ancak referans kırılması için dictionary'den çıkarıyoruz
			# Tween API'sinde direct kill yok; autostop döngü kırılır.
			# Alternatif: tween.stop() (Godot 4.2+) sürüme göre değişebilir.
			pass
		active_wobble_tweens.erase(customer)

# Müşteriye sipariş görseli ekle (Yemekler/SpawnPoints'teki eşleşen noktada)
func _show_order(customer: Node, customer_point: Node):
	if customer_order.has(customer):
		return # Zaten var
	
	# RecipeDatabase'den rastgele yemek seç
	var food_name: String = RecipeDatabase.get_random_food()
	print("🍽️ Seçilen yemek: ", food_name)
	var food_path := "res://assets/" + food_name + ".png"
	
	# Texture'ı yükle
	var food_texture: Texture2D = load(food_path)
	if food_texture == null:
		print("❌ Yemek texture yüklenemedi: ", food_path)
		return
	
	# Customer point'in numarasını al (Point1 -> 1, Point2 -> 2)
	var point_index := _extract_index(customer_point.name)
	var order_point_name := "Yemekler_SpawnPoints#Point" + str(point_index)
	
	# Yemekler_SpawnPoints#PointX'i MainScreen'den al
	var main_screen = get_node("/root/MainScreen")
	var order_point = main_screen.get_node_or_null(order_point_name)
	if order_point == null:
		print("❌ Sipariş point bulunamadı: ", order_point_name)
		return
	
	var order_sprite := Sprite2D.new()
	order_sprite.texture = food_texture
	order_sprite.scale = Vector2(0.2, 0.2)
	order_sprite.global_position = order_point.global_position
	order_sprite.z_index = 150  # Üstte görünsün
	order_sprite.name = "OrderSprite_" + customer.name
	
	# Metadata olarak yemek adını sakla (sonra drag&drop kontrolü için)
	order_sprite.set_meta("food_name", food_name)
	order_sprite.set_meta("customer", customer)
	
	# Yemekler node'una ekle (scene root altında)
	get_node("../Yemekler").add_child(order_sprite)
	customer_order[customer] = order_sprite
	
	# Müşteri sabır süresini RASTGELE başlat (35-55 saniye arası)
	var patience_time = randf_range(patience_min, patience_max)
	customer_patience[customer] = patience_time
	
	# Patience circle ekle (max süreyi de sakla)
	_create_patience_circle(customer, order_sprite, patience_time)
	
	print("✓ Sipariş görseli eklendi: ", food_name, " müşteri: ", customer.name, " sabır: ", patience_time, "s")

# Sipariş görselini kaldır
func _remove_order(customer: Node):
	if customer_order.has(customer):
		var order_sprite = customer_order[customer]
		if order_sprite and is_instance_valid(order_sprite):
			order_sprite.queue_free()
		customer_order.erase(customer)
	
	# Patience verilerini temizle
	customer_patience.erase(customer)
	if customer_patience_circles.has(customer):
		var circle = customer_patience_circles[customer]
		if circle and is_instance_valid(circle):
			circle.queue_free()
		customer_patience_circles.erase(customer)

# Patience circle oluştur
func _create_patience_circle(customer: Node, order_sprite: Sprite2D, max_patience: float):
	var circle_container = Node2D.new()
	circle_container.name = "PatienceCircle_" + customer.name
	circle_container.global_position = order_sprite.global_position
	circle_container.z_index = 151  # Sipariş görseli üzerinde
	circle_container.set_meta("max_patience", max_patience)  # Max süreyi sakla
	
	# Circle çizimi için script ekle
	var script_code = """
extends Node2D

var progress: float = 1.0  # 1.0 (beyaz) -> 0.0 (kırmızı)
var radius: float = 30.0

func _draw():
	var color = Color.WHITE.lerp(Color.RED, 1.0 - progress)
	var angle = progress * TAU  # 0 - 2π (tam daire)
	
	# Daire çiz (progress'e göre)
	var points = []
	var center = Vector2.ZERO
	points.append(center)
	
	var segments = 32
	for i in range(segments + 1):
		var t = float(i) / segments
		if t > progress:
			break
		var angle_offset = t * TAU - PI / 2  # -90° başlangıç
		var point = center + Vector2(cos(angle_offset), sin(angle_offset)) * radius
		points.append(point)
	
	if points.size() > 2:
		draw_colored_polygon(points, color * Color(1, 1, 1, 0.6))
	
	# Dış çember
	draw_arc(center, radius, 0, TAU, 32, color, 2.0)

func update_progress(p: float):
	progress = clamp(p, 0.0, 1.0)
	queue_redraw()
"""
	
	var circle_script = GDScript.new()
	circle_script.source_code = script_code
	circle_script.reload()
	circle_container.set_script(circle_script)
	
	get_node("../Yemekler").add_child(circle_container)
	customer_patience_circles[customer] = circle_container

# Müşteri sabrını güncelle
func _update_customer_patience(delta: float):
	# Optimize: Array yerine direkt iterate
	var customers_to_remove: Array = []
	
	for customer in customer_patience.keys():
		customer_patience[customer] -= delta
		var remaining: float = customer_patience[customer]
		
		# Süre bitti mi kontrol et (önce, daha az işlem)
		if remaining <= 0:
			customers_to_remove.append(customer)
			continue  # Circle güncelleme gereksiz
		
		# Circle varsa güncelle (cache lookup)
		var circle = customer_patience_circles.get(customer)
		if circle:
			# Max patience'ı meta'dan al (cached)
			var max_patience: float = circle.get_meta("max_patience", customer_patience_time)
			var progress: float = remaining / max_patience
			
			# Circle'ı güncelle
			if circle.has_method("update_progress"):
				circle.update_progress(progress)
	
	# Sabırsız müşterileri gönder (toplu işlem)
	for customer in customers_to_remove:
		_customer_leave_angry(customer)

# Müşteri sabırsızlık sonucu ayrılır
func _customer_leave_angry(customer: Node):
	print(tr("CUSTOMER_ANGRY"), ": ", customer.name)
	
	# GameOverUI'ye bildir
	var game_over_ui = get_node_or_null("../GameOverUI")
	if game_over_ui and game_over_ui.has_method("add_angry_customer"):
		game_over_ui.add_angry_customer()
	
	# Müşterinin istediği yemeğin değerinin yarısı kadar para kaybedelim
	var penalty = 4  # Varsayılan (1 malzemeli yemeğin yarısı: 8/2=4)
	
	if customer_order.has(customer):
		var order_sprite = customer_order[customer]
		var food_name = order_sprite.get_meta('food_name', '')
		
		# Tarif karmaşıklığını bul
		var recipe_db = RecipeDatabase
		if recipe_db.recipes.has(food_name):
			var ingredient_count = recipe_db.recipes[food_name].size()
			# Ödülün yarısı = ceza (8/12/18/25 → 4/6/9/12)
			if ingredient_count == 1:
				penalty = 4
			elif ingredient_count == 2:
				penalty = 6
			elif ingredient_count == 3:
				penalty = 9
			elif ingredient_count >= 4:
				penalty = 12
	
	var money_manager = get_node_or_null("../MoneyManager")
	if money_manager:
		money_manager.remove_money(penalty)
		print(tr("CUSTOMER_PENALTY").format({"penalty": penalty}))
	
	# Müşteriyi direkt gönder (dönme animasyonu YOK)
	return_customer_to_pool(customer)
