extends Node

const SAVE_FILE_PATH = "user://savegame.save"

# Kayıt verisi
var save_data = {
	"money": 50,
	"unlocked_ingredients": ["egg_base"],  # Başlangıçta sadece yumurta açık
	"version": "1.0"
}

func _ready():
	load_game()

# Oyunu kaydet
func save_game():
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		# Güncel verileri al
		var money_manager = get_node_or_null("/root/MainScreen/MoneyManager")
		if money_manager:
			save_data["money"] = money_manager.money
		
		var unlock_manager = UnlockManager
		if unlock_manager:
			save_data["unlocked_ingredients"] = unlock_manager.unlocked_ingredients.duplicate()
		
		# JSON olarak kaydet
		var json_string = JSON.stringify(save_data)
		file.store_line(json_string)
		file.close()
		print("💾 Oyun kaydedildi!")
		return true
	else:
		print("❌ Kayıt dosyası açılamadı!")
		return false

# Oyunu yükle
func load_game():
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("📝 Kayıt dosyası yok, yeni oyun başlatılıyor")
		return false
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_line()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		
		if parse_result == OK:
			var loaded_data = json.data
			if loaded_data:
				save_data = loaded_data
				_apply_save_data()
				print("✅ Oyun yüklendi! Para: ", save_data["money"], " Unlock: ", save_data["unlocked_ingredients"].size())
				return true
		
		print("❌ Kayıt dosyası bozuk!")
		return false
	
	return false

# Kayıtlı veriyi oyuna uygula
func _apply_save_data():
	# Para miktarını ayarla
	await get_tree().process_frame  # MainScreen yüklenene kadar bekle
	
	var money_manager = get_node_or_null("/root/MainScreen/MoneyManager")
	if money_manager:
		money_manager.money = save_data.get("money", 50)
		money_manager._update_ui()
	
	# Unlock'ları ayarla
	var unlock_manager = UnlockManager
	if unlock_manager:
		unlock_manager.unlocked_ingredients = save_data.get("unlocked_ingredients", ["egg_base"]).duplicate()

# Kayıtları sıfırla (debug/test için)
func reset_save():
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		print("🗑️ Kayıt silindi!")
	save_data = {
		"money": 50,
		"unlocked_ingredients": ["egg_base"],
		"version": "1.0"
	}
