extends Node

# Oyun başlangıcında cihaz diline göre dil ayarla
func _ready():
	set_language_from_system()

func set_language_from_system():
	# Cihazın dilini al (örn: "tr_TR", "en_US")
	var system_locale = OS.get_locale()
	var language_code = system_locale.split("_")[0]  # "tr_TR" -> "tr"
	
	print("🌍 Sistem dili: ", system_locale, " -> ", language_code)
	
	# Desteklenen diller: tr, en
	if language_code in ["tr", "en"]:
		TranslationServer.set_locale(language_code)
		print("✅ Dil ayarlandı: ", language_code)
	else:
		# Desteklenmeyen dil -> İngilizce varsayılan
		TranslationServer.set_locale("en")
		print("⚠️ Desteklenmeyen dil, İngilizce kullanılıyor")

# Manuel dil değiştirme (gelecekte ayarlar menüsü için)
func set_language(language_code: String):
	if language_code in ["tr", "en"]:
		TranslationServer.set_locale(language_code)
		print("🔄 Dil değiştirildi: ", language_code)
		# Tüm UI'ları güncelle
		get_tree().reload_current_scene()
