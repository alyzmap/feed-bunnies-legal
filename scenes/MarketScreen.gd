extends CanvasLayer

@onready var market_panel = $MarketPanel
var money_manager
var ingredient_manager

var is_open: bool = false
var drag_start_x: float = 0.0
var is_dragging: bool = false

# Malzeme fiyatları - asset dosya ismine göre (uzantısız) - Daha ucuz!
var ingredient_prices: Dictionary = {
	# Temel malzemeler (3-5)
	"egg_base": 3,
	"flour_base": 4,
	"bread": 5,
	"mulk": 5,
	"sugar_bowl": 3,
	"salt": 3,
	# Orta seviye (6-10)
	"banana_chalk": 8,
	"oats_base": 6,
	"blueberrys": 10,
	"butter": 9,
	# Premium (12-18)
	"cheese": 15,
	"salami": 18
}

func _ready():
	market_panel.position.x = -market_panel.size.x # Başlangıçta ekran dışında sol
	
	# Manager'ları bul
	money_manager = get_node("../MoneyManager")
	ingredient_manager = get_node("../Malzemeler")
	
	# Tüm market item'larını bul ve sinyalleri bağla
	_connect_market_items()

func _input(event: InputEvent):
	# Mouse drag başlangıcı
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_start_x = event.position.x
				is_dragging = true
			else:
				is_dragging = false
				_check_drag_threshold()
	
	# Mouse motion - tutup çekerken
	if event is InputEventMouseMotion and is_dragging:
		_handle_drag(event)
	
	# Touch drag
	if event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_drag(event):
	var current_x = event.position.x if event is InputEventMouseMotion else event.position.x
	var delta_x = current_x - drag_start_x
	
	# Sol kenardan sağa kaydırma (açma)
	if not is_open and drag_start_x < 100 and delta_x > 50:
		open_market()
		is_dragging = false
	
	# Açıkken sola kaydırma (kapama)
	if is_open and delta_x < -50:
		close_market()
		is_dragging = false

func _check_drag_threshold():
	# Mouse bırakıldığında eşik kontrolü yapılabilir
	pass

func open_market():
	if is_open:
		return
	
	# Kitap açıksa market açılmasın
	var cookbook_ui = get_node("../CookBookUI")
	if cookbook_ui and cookbook_ui.is_open:
		print("Kitap açıkken market açılamaz!")
		return
	
	# Elimde malzeme varsa market açılmasın!
	if ingredient_manager:
		var is_dragging_ingredient = ingredient_manager.is_any_dragging()
		if is_dragging_ingredient:
			print("Elimde malzeme varken market açılamaz!")
			return
	
	# Elimde yemek varsa market açılmasın!
	var main_screen = get_node("/root/MainScreen")
	if main_screen:
		for child in main_screen.get_children():
			if child is Sprite2D and child.has_meta("is_food"):
				# Yemek drag scriptinde is_dragging var mı kontrol et
				if child.get("is_dragging") == true:
					print("Elimde yemek varken market açılamaz!")
					return
	
	is_open = true
	
	# Oyunu duraklat (yemek bozulmasın, müşteriler beklesin)
	get_tree().paused = true
	
	# Para miktarını güncelle
	_update_money_display()
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(market_panel, "position:x", 0, 0.3)

func close_market():
	if not is_open:
		return
	is_open = false
	
	# Oyunu devam ettir
	get_tree().paused = false
	
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(market_panel, "position:x", -market_panel.size.x, 0.3)

func toggle_market():
	if is_open:
		close_market()
	else:
		open_market()

# Market item'larına tıklama fonksiyonlarını bağla
func _connect_market_items():
	var item_list = market_panel.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/ItemList")
	if not item_list:
		print("ItemList bulunamadı!")
		return
	
	# TARİF KİTABI SIRASINA GÖRE SIRALAMAK ÇOK ÖNEMLİ!
	# Doğru sıra: Egg, Flour, Bread, Banana, Cheese, Salami, Milk, Butter, Oats, Blueberry, Sugar, Salt
	var correct_order = ["Egg", "Flour", "Bread", "Banana", "Cheese", "Salami", "Milk", "Butter", "Oats", "Blueberry", "Sugar", "Salt"]
	
	# Mevcut child'ları toplama
	var items_dict = {}
	for child in item_list.get_children():
		if child is PanelContainer:
			items_dict[child.name] = child
			item_list.remove_child(child)
	
	# Doğru sırayla tekrar ekleme
	for item_name in correct_order:
		if items_dict.has(item_name):
			item_list.add_child(items_dict[item_name])
	
	# Her malzeme için click event ekle
	for child in item_list.get_children():
		if child is PanelContainer:
			# Mouse filter'ı stop yap ki tıklanabilir olsun
			child.mouse_filter = Control.MOUSE_FILTER_STOP
			child.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			
			# PanelContainer'a gui_input sinyali bağla
			if not child.gui_input.is_connected(_on_item_clicked):
				child.gui_input.connect(_on_item_clicked.bind(child.name))
			
			print("Item bağlandı (sıralı): ", child.name)
	
	# Kilit durumlarını güncelle
	_update_ingredient_visuals()

# Malzeme görsellerini güncelle (kilitli/açık)
func _update_ingredient_visuals():
	var item_list = market_panel.get_node_or_null("MarginContainer/VBoxContainer/ScrollContainer/ItemList")
	if not item_list:
		return
	
	for child in item_list.get_children():
		if child is PanelContainer:
			var ingredient_key = child.name.to_lower()
			var is_locked = UnlockManager.is_ingredient_locked(ingredient_key)
			
			# Icon'u modulate et
			var icon = child.get_node_or_null("HBox/Icon")
			var name_label = child.get_node_or_null("HBox/Name")
			var price_label = child.get_node_or_null("HBox/Price")
			
			if is_locked:
				# Kilitli: siyah-beyaz + kilit fiyatı göster
				if icon:
					icon.modulate = Color(0.3, 0.3, 0.3, 1.0)
				if name_label:
					name_label.modulate = Color(0.5, 0.5, 0.5, 1.0)
				if price_label:
					var unlock_cost = UnlockManager.get_unlock_cost(ingredient_key)
					price_label.text = "🔒 " + str(unlock_cost)
					price_label.modulate = Color(1.0, 0.5, 0.0, 1.0)  # Turuncu
			else:
				# Açık: normal renkler
				if icon:
					icon.modulate = Color(1.0, 1.0, 1.0, 1.0)
				if name_label:
					name_label.modulate = Color(0.4, 0.3, 0.2, 1.0)
				if price_label:
					var asset_key = _get_asset_key_from_ingredient(ingredient_key)
					var price = ingredient_prices.get(asset_key, 10)
					price_label.text = str(price)
					price_label.modulate = Color(0.8, 0.6, 0.2, 1.0)  # Altın

func _get_asset_key_from_ingredient(ingredient_key: String) -> String:
	var texture_map: Dictionary = {
		"banana": "banana_chalk",
		"blueberry": "blueberrys",
		"bread": "bread",
		"egg": "egg_base",
		"cheese": "cheese",
		"salami": "salami",
		"butter": "butter",
		"milk": "mulk",
		"oats": "oats_base",
		"flour": "flour_base",
		"salt": "salt",
		"sugar": "sugar_bowl"
	}
	return texture_map.get(ingredient_key, ingredient_key)

# Malzeme tıklandığında
func _on_item_clicked(event: InputEvent, item_name: String):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		print("Item tıklandı: ", item_name)
		
		var ingredient_key = item_name.to_lower()
		
		# Kilitli mi kontrol et
		if UnlockManager.is_ingredient_locked(ingredient_key):
			_try_unlock_ingredient(ingredient_key)
		else:
			_buy_ingredient(item_name)

# Malzeme kilidi açmaya çalış
func _try_unlock_ingredient(ingredient_key: String):
	var unlock_cost = UnlockManager.get_unlock_cost(ingredient_key)
	
	if money_manager and money_manager.money >= unlock_cost:
		var success = money_manager.remove_money(unlock_cost)
		if success:
			UnlockManager.unlock_ingredient(ingredient_key)
			_update_ingredient_visuals()
			_update_money_display()  # Para göstergesini güncelle
			print("✓ Malzeme açıldı: ", ingredient_key, " (", unlock_cost, " para)")
	else:
		print("❌ Yetersiz para! Açma maliyeti: ", unlock_cost)

# Malzeme satın al
func _buy_ingredient(item_name: String):
	# Malzeme adını küçük harfe çevir
	var ingredient_key: String = item_name.to_lower()
	
	# Fiyat için doğru asset key'i al
	var asset_key_for_price = _get_asset_key_from_ingredient(ingredient_key)
	var price: int = ingredient_prices.get(asset_key_for_price, 10) as int
	
	print("Satın alma denemesi: ", item_name, " -> ", asset_key_for_price, " Fiyat: ", price)
	
	# Texture path'i belirle (PanelContainer isimleri ile eşleşir)
	var texture_map: Dictionary = {
		"banana": "banana.png",
		"blueberry": "blueberrys.png",
		"bread": "bread.png",
		"egg": "egg.png",
		"cheese": "cheese.png",
		"salami": "salami.png",
		"butter": "butter.png",
		"milk": "mulk.png",
		"oats": "oats_base.png",
		"flour": "flour_base.png",
		"salt": "salt.png",
		"sugar": "sugar_bowl.png"
	}
	
	var texture_file: String = texture_map.get(ingredient_key, "") as String
	if texture_file == "":
		print("Malzeme texture bulunamadı: ", item_name, " (key: ", ingredient_key, ")")
		return
	
	# Gerçek asset key'i (IngredientManager için)
	var asset_key: String = texture_file.get_basename()
	
	# Para kontrolü
	if money_manager and money_manager.money >= price:
		print("Para var: ", money_manager.money, " >= ", price)
		# Parayı düş
		var success = money_manager.remove_money(price)
		print("Para düşürme başarılı: ", success, " Yeni bakiye: ", money_manager.money)
		
		# Para göstergesini güncelle
		_update_money_display()
		
		# Malzemeyi ekle
		var texture: Texture2D = load("res://assets/" + texture_file) as Texture2D
		if texture and ingredient_manager:
			ingredient_manager.add_ingredient(asset_key, texture)
			print("✓ Satın alındı: ", item_name, " (", price, " para harcandı)")
		else:
			print("✗ Malzeme veya manager bulunamadı!")
			# Para iadesi
			money_manager.add_money(price)
			_update_money_display()
	else:
		var current_money: int = money_manager.money if money_manager else 0
		print("✗ Yetersiz para! Fiyat: ", price, " Mevcut: ", current_money)

# Para göstergesini güncelle
func _update_money_display():
	var money_label = market_panel.get_node_or_null("MarginContainer/VBoxContainer/MoneyDisplay/MoneyAmount")
	if money_label and money_manager:
		money_label.text = str(money_manager.money)
