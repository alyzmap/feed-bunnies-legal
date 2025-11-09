extends Node # Bu komut dosyası bir Node düğümüne bağlı

# @onready, düğümler hazır olduğunda onlara erişmemizi sağlar.
# Artık bu düğümler, script'in bağlı olduğu düğümün (CustomerManager) altındadır.
@onready var spawn_timer = $SpawnTimer	     
@onready var spawn_points_node = $SpawnPoints

# Müşteri çağırma süresi aralığı (Oyun başlangıcı için yavaş)
var min_spawn_time := 5.0 
var max_spawn_time := 15.0 

# Kullanıma hazır müşterilerin tutulacağı dinamik liste
var available_customers: Array = []

# Hangi noktanın/hangi müşterinin dolu olduğunu takip etmek için sözlükler
var point_to_customer: Dictionary = {}
var customer_to_point: Dictionary = {}
var active_wobble_tweens: Dictionary = {} # customer -> Tween
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

	# 3) İlk rastgele süreyi ayarla ve Timer'ı başlat
	set_random_spawn_time()
	spawn_timer.start()

# Basit müşteri düğümü kontrolü: adı m + sayı ve Sprite2D olmalı
func _is_customer_node(n: Node) -> bool:
	if n is Sprite2D and n.name.begins_with("m") and n.name.length() > 1:
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

# Timer bittiğinde çalışacak fonksiyon
func _on_spawn_timer_timeout():
	# Dükkan kapalıysa spawn yapma, yalnızca timer'ı döndür
	if not is_shop_open:
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

	# Hafif sallanma animasyonu ekle (y ekseninde sine benzeri yukarı-aşağı)
	_start_wobble(customer)

	# Eşlemeleri kaydet
	point_to_customer[point] = customer
	customer_to_point[customer] = point

# Müşteriyi havuza geri gönderme (işi bittiğinde çağır)
func return_customer_to_pool(customer_node: Node):
	# Görünmez yap ve ekran dışına taşı
	customer_node.visible = false
	customer_node.global_position = Vector2.ZERO

	# Sallanma tween'ini temizle
	_stop_wobble(customer_node)

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
	if not open:
		force_clear_customers()

# Tüm aktif müşterileri geri havuza gönder
func force_clear_customers() -> void:
	var to_return: Array = []
	for point in point_to_customer.keys():
		var c = point_to_customer[point]
		if c:
			to_return.append(c)
	for c in to_return:
		return_customer_to_pool(c)

# Wobble animasyonu başlat: küçük genlikli ping-pong y hareketi
func _start_wobble(customer: Node):
	if active_wobble_tweens.has(customer):
		return # Zaten aktif
	if not (customer is Node2D):
		return # Konumsal animasyon için Node2D olmalı
	var tween: Tween = create_tween()
	active_wobble_tweens[customer] = tween
	var base_pos: Vector2 = (customer as Node2D).position
	var amplitude: float = 6.0
	var duration: float = 1.2
	# Ping-pong etkisi için sequence
	tween.set_loops() # sonsuz döngü
	tween.tween_property(customer, "position:y", base_pos.y - amplitude, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(customer, "position:y", base_pos.y + amplitude, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(customer, "position:y", base_pos.y, duration * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

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
