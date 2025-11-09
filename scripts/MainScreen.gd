extends Control

func _ready():
	# Kayıtlı oyunu yükle
	SaveManager.load_game()
	
	# Arka plan müziği vs buraya eklenebilir
