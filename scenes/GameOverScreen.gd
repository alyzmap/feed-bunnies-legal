extends CanvasLayer

@onready var panel = $Panel
@onready var restart_button = $Panel/VBox/RestartButton
@onready var money_label = $Panel/VBox/MoneyLabel
@onready var tip_label = $Panel/VBox/TipLabel

# Kaybetme sebepleri tracker (optimize edilmiş - sadece sayaçlar)
var angry_customers: int = 0
var spoiled_food_count: int = 0
var wrong_food_count: int = 0

func _ready():
	visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	
	# Label'ları çevir
	var title_label = $Panel/VBox/TitleLabel
	if title_label:
		title_label.text = tr("GAME_OVER_TITLE")
	
	restart_button.text = "🔄 " + tr("GAME_OVER_RESTART")

func show_game_over():
	visible = true
	
	# OYUNU DURDUR - Tüm animasyonlar donacak
	get_tree().paused = true
	
	# Para kaç eksildi göster
	var money_manager = get_node_or_null("../MoneyManager")
	if money_manager:
		var balance = money_manager.money
		money_label.text = tr("GAME_OVER_BALANCE").format({"balance": balance})
		
		# Akıllı ipucu - kaybetme sebebine göre
		tip_label.text = _get_smart_tip()

func _get_smart_tip() -> String:
	# En büyük sorunu bul ve ona göre ipucu ver (optimize edilmiş)
	if angry_customers > 5:
		return tr("TIP_TOO_MANY_ANGRY")
	elif wrong_food_count > 3:
		return tr("TIP_WRONG_FOOD")
	elif spoiled_food_count > 3:
		return tr("TIP_SPOILED_FOOD")
	else:
		# Genel ipuçları (pre-defined array, optimize)
		var tips: PackedStringArray = [
			tr("TIP_MANAGE_TIME"),
			tr("TIP_UNLOCK_INGREDIENTS"),
			tr("TIP_WATCH_TIMER"),
			tr("TIP_CHECK_ORDERS"),
			tr("TIP_STAY_CALM")
		]
		return tips[randi() % tips.size()]

func _on_restart_pressed():
	# Oyunu devam ettir (pause'u kaldır)
	get_tree().paused = false
	# Oyunu yeniden başlat
	get_tree().reload_current_scene()

# Kaybetme sebeplerine abone olmak için inline fonksiyonlar (optimize)
func add_angry_customer():
	angry_customers += 1

func add_spoiled_food():
	spoiled_food_count += 1

func add_wrong_food():
	wrong_food_count += 1
