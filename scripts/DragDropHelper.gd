extends Node
# Bu script drag & drop sistemi için yardımcı fonksiyonlar içerir

# Bir item'ı çöp kutusuna at
static func trash_item(item: Node, trash_basket: Sprite2D):
	if trash_basket and trash_basket.has_method("add_trash_item"):
		trash_basket.add_trash_item(item)
		return true
	return false

# Item bir çöp kutusu alanı içinde mi kontrol et
static func is_over_trash(item_global_pos: Vector2, trash_basket: Sprite2D) -> bool:
	if not trash_basket:
		return false
	
	var trash_pos := trash_basket.global_position
	var trash_size := trash_basket.texture.get_size() * trash_basket.scale
	var trash_rect := Rect2(
		trash_pos.x - trash_size.x / 2,
		trash_pos.y - trash_size.y / 2,
		trash_size.x,
		trash_size.y
	)
	
	return trash_rect.has_point(item_global_pos)
