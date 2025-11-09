extends Node

signal money_changed(new_amount: int)

var money: int = 50  # 100 → 50 (daha az başlangıç parası)

@onready var money_label: Label = $"../MoneyLabel"

func _ready():
	_update_ui()

func add_money(amount: int):
	money += amount
	_update_ui()
	emit_signal("money_changed", money)
	
	# Otomatik kayıt
	SaveManager.save_game()

func remove_money(amount: int) -> bool:
	money -= amount  # Negatife düşebilir artık
	_update_ui()
	emit_signal("money_changed", money)
	
	# Otomatik kayıt
	SaveManager.save_game()
	
	# Para 0'ın altına düştüyse Game Over
	if money < 0:
		_trigger_game_over()
	
	return true

func _trigger_game_over():
	print(tr("GAME_OVER_MONEY"), ": ", money)
	# Game Over ekranını göster
	var game_over_ui = get_node_or_null("../GameOverUI")
	if game_over_ui and game_over_ui.has_method("show_game_over"):
		game_over_ui.show_game_over()

func _update_ui():
	if money_label:
		money_label.text = _format_money(money)

# Para formatı: 999'dan sonra k, m, b, t kısaltmaları
func _format_money(amount: int) -> String:
	if amount < 1000:
		return str(amount)
	elif amount < 1000000:
		# 1k - 999.9k
		var k := float(amount) / 1000.0
		if k >= 10.0:
			return str(int(k)) + "k"
		else:
			return str(snappedf(k, 0.1)) + "k"
	elif amount < 1000000000:
		# 1m - 999.9m
		var m := float(amount) / 1000000.0
		if m >= 10.0:
			return str(int(m)) + "m"
		else:
			return str(snappedf(m, 0.1)) + "m"
	elif amount < 1000000000000:
		# 1b - 999.9b
		var b := float(amount) / 1000000000.0
		if b >= 10.0:
			return str(int(b)) + "b"
		else:
			return str(snappedf(b, 0.1)) + "b"
	else:
		# 1t+
		var t := float(amount) / 1000000000000.0
		if t >= 10.0:
			return str(int(t)) + "t"
		else:
			return str(snappedf(t, 0.1)) + "t"
