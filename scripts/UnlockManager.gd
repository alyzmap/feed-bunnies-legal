extends Node

# Malzeme kilit sistemi
signal ingredient_unlocked(ingredient_name: String)
signal recipe_unlocked(recipe_name: String)

# Başlangıçta açık malzemeler
var unlocked_ingredients: Array[String] = ["egg"]  # Sadece yumurta

# Malzeme açma fiyatları (tarif kitabı sırasına göre) - ÇOK PAHALI! (10x)
var ingredient_unlock_costs: Dictionary = {
	"egg": 0,         # Baştan açık
	"flour": 500,     # 150 → 500
	"bread": 800,     # 250 → 800
	"banana": 1200,   # 400 → 1200
	"cheese": 2500,   # 800 → 2500
	"salami": 3500,   # 1000 → 3500
	"milk": 1000,     # 300 → 1000
	"butter": 1800,   # 500 → 1800
	"oats": 1400,     # 350 → 1400
	"blueberry": 2000,# 600 → 2000
	"sugar": 900,     # 250 → 900
	"salt": 600       # 150 → 600
}

# Açık tarifler - başta boş, ilk tarif yapınca açılacak
var unlocked_recipes: Array[String] = []

func _ready():
	pass

# Malzeme kilitli mi?
func is_ingredient_locked(ingredient: String) -> bool:
	return not unlocked_ingredients.has(ingredient)

# Tarif kilitli mi?
func is_recipe_locked(recipe_name: String) -> bool:
	return not unlocked_recipes.has(recipe_name)

# Malzeme açma fiyatı
func get_unlock_cost(ingredient: String) -> int:
	return ingredient_unlock_costs.get(ingredient, 999)

# Malzeme aç
func unlock_ingredient(ingredient: String) -> bool:
	if not is_ingredient_locked(ingredient):
		return true  # Zaten açık
	
	unlocked_ingredients.append(ingredient)
	emit_signal("ingredient_unlocked", ingredient)
	print("✓ Malzeme açıldı: ", ingredient)
	
	# Otomatik kayıt
	SaveManager.save_game()
	
	return true

# Tarif aç (otomatik - ilk kez yapınca)
func unlock_recipe(recipe_name: String):
	if not is_recipe_locked(recipe_name):
		return  # Zaten açık
	
	unlocked_recipes.append(recipe_name)
	emit_signal("recipe_unlocked", recipe_name)
	print("✓ Tarif açıldı: ", recipe_name)

# Açık malzemelerle yapılabilecek tarifler
func get_available_recipes() -> Array[String]:
	var available = []
	var recipe_db = RecipeDatabase
	
	for recipe_name in recipe_db.recipes.keys():
		var ingredients = recipe_db.recipes[recipe_name]
		var can_make = true
		
		# Tüm malzemeler açık mı?
		for ingredient in ingredients:
			if is_ingredient_locked(ingredient):
				can_make = false
				break
		
		if can_make:
			available.append(recipe_name)
	
	return available
