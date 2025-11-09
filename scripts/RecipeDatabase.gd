extends Node

# TÜM YEMEK TARİFLERİ VE OLMAYAN ÜRÜNLER
var all_foods: Array[String] = [
	# KAHVALTI - Yumurta
	"Sunny_Side_Up_Egg",
	"Boiled_Egg",
	
	# KAHVALTI - Ekmek
	"Flat_Bread",
	"Banana_Bread",
	"Crispy_Toast",
	"French_Toast",
	"Banana_French_Toast",
	"Blueberry_French_Toast",
	
	# SANDVİÇLER
	"Bland_Sandwich",
	"Egg_Sandwich",
	"Cheese_Sandwich",
	"Salami_Sandwich",
	"Egg_Cheese_Sandwich",
	"Egg_Salami_Sandwich",
	"Cheese_Salami_Sandwich",
	"Egg_Cheese_Salami_Sandwich",
	
	# PANKEKLER
	"Pancakes",
	"Banana_Pancakes",
	"Healthy_Pancakes",
	"Healthy_Blueberry_Pancakes",
	
	# LAPALAR
	"Plain_Porridge",
	"Banana_Porridge",
	"Blueberry_Porridge",
	"Blueberry_Banana_Porridge",
	
	# ÖZEL YEMEKLER
	"Baked_Banana",
	"Fried_Banana",
	"Fondue",
	"Mug_Cake",
	"Fruit_Salad",
	"Quiche",
	"Charcuterie_Board",
	"Salami_Rose",
	
	# İÇECEKLER
	"Banana_Milk",
	"Blueberry_Milk",
	"Hot_Milk",
	"Blueberry_Jam",
	"Smoothie",
	"Granola",
	"Ghee",
	
	# OLMAYANLAR (Hatalı/Yanmış)
	"Banana_Mess",
	"Blueberry_Mess",
	"Covered_Mess",
	"Eggy_Mess",
	"Fancy_Mess",
	"Flowery_Mess",
	"Salty_Mess",
	"Mess_in_a_Mug",
	"Getting_Mugged",
	"Monster_Cocktail",
	"Food_Monster",
	"Burned_Toast",
	"Scary_Porridge"
]

# Bir yemeğin "olmayan" olup olmadığını kontrol et
func is_invalid_food(food_name: String) -> bool:
	var invalid_foods := [
		"Banana_Mess", "Blueberry_Mess", "Covered_Mess", "Eggy_Mess",
		"Fancy_Mess", "Flowery_Mess", "Salty_Mess", "Mess_in_a_Mug",
		"Getting_Mugged", "Monster_Cocktail", "Food_Monster", 
		"Burned_Toast", "Scary_Porridge"
	]
	return invalid_foods.has(food_name)

# Zorluk seviyelerine göre yemek kategorileri
var difficulty_tiers: Dictionary = {
	"very_easy": [  # %40 - Tek malzemeli
		"Sunny_Side_Up_Egg", "Boiled_Egg", "Flat_Bread", "Crispy_Toast",
		"Baked_Banana", "Fried_Banana", "Fondue", "Salami_Rose",
		"Hot_Milk", "Ghee", "Bland_Sandwich"
	],
	"easy": [  # %30 - İki malzemeli
		"Banana_Bread", "French_Toast", "Egg_Sandwich", "Cheese_Sandwich",
		"Salami_Sandwich", "Pancakes", "Banana_Pancakes", "Plain_Porridge",
		"Banana_Porridge", "Blueberry_Porridge", "Fruit_Salad",
		"Charcuterie_Board", "Banana_Milk", "Blueberry_Milk",
		"Blueberry_Jam", "Granola"
	],
	"medium": [  # %20 - Üç malzemeli
		"Banana_French_Toast", "Blueberry_French_Toast", "Egg_Cheese_Sandwich",
		"Egg_Salami_Sandwich", "Cheese_Salami_Sandwich", "Healthy_Pancakes",
		"Blueberry_Banana_Porridge", "Mug_Cake", "Quiche", "Smoothie"
	],
	"hard": [  # %10 - Dört+ malzemeli
		"Egg_Cheese_Salami_Sandwich", "Healthy_Blueberry_Pancakes"
	]
}

# Ağırlıklı rastgele yemek seçimi - SADECE AÇIK MALZEMELERİ KULLAN
func get_random_food() -> String:
	# Açık malzemelerle yapılabilecek tarifleri filtrele
	var available_recipes = []
	
	for tier_name in difficulty_tiers.keys():
		for recipe_name in difficulty_tiers[tier_name]:
			if recipes.has(recipe_name):
				var ingredients = recipes[recipe_name]
				var can_make = true
				
				# Tüm malzemeler açık mı kontrol et
				for ingredient in ingredients:
					if UnlockManager.is_ingredient_locked(ingredient):
						can_make = false
						break
				
				if can_make:
					available_recipes.append(recipe_name)
	
	# Eğer hiç tarif yoksa (başlangıç), sadece egg ile yapılanları döndür
	if available_recipes.is_empty():
		available_recipes = ["Sunny_Side_Up_Egg", "Boiled_Egg"]
	
	# Rastgele seç
	return available_recipes[randi() % available_recipes.size()]

# Tarif dictionary'si - hangi malzemelerden ne çıkar
var recipes: Dictionary = {
	# Basit olanlar
	"Sunny_Side_Up_Egg": ["egg"],
	"Boiled_Egg": ["egg"],
	"Flat_Bread": ["flour"],
	"Crispy_Toast": ["bread"],
	
	# İki malzemeli
	"Banana_Bread": ["bread", "banana"],
	"French_Toast": ["bread", "egg"],
	"Banana_French_Toast": ["bread", "egg", "banana"],
	"Blueberry_French_Toast": ["bread", "egg", "blueberrys"],
	
	# Sandviçler
	"Bland_Sandwich": ["bread"],
	"Egg_Sandwich": ["bread", "egg"],
	"Cheese_Sandwich": ["bread", "cheese"],
	"Salami_Sandwich": ["bread", "salami"],
	"Egg_Cheese_Sandwich": ["bread", "egg", "cheese"],
	"Egg_Salami_Sandwich": ["bread", "egg", "salami"],
	"Cheese_Salami_Sandwich": ["bread", "cheese", "salami"],
	"Egg_Cheese_Salami_Sandwich": ["bread", "egg", "cheese", "salami"],
	
	# Pankekler
	"Pancakes": ["flour", "egg"],
	"Banana_Pancakes": ["flour", "egg", "banana"],
	"Healthy_Pancakes": ["flour", "egg", "oats"],
	"Healthy_Blueberry_Pancakes": ["flour", "egg", "oats", "blueberrys"],
	
	# Lapalar
	"Plain_Porridge": ["oats", "mulk"],
	"Banana_Porridge": ["oats", "mulk", "banana"],
	"Blueberry_Porridge": ["oats", "mulk", "blueberrys"],
	"Blueberry_Banana_Porridge": ["oats", "mulk", "blueberrys", "banana"],
	
	# Özel
	"Baked_Banana": ["banana"],
	"Fried_Banana": ["banana"],
	"Fondue": ["cheese"],
	"Mug_Cake": ["flour", "egg", "sugar"],
	"Fruit_Salad": ["banana", "blueberrys"],
	"Quiche": ["egg", "cheese", "flour"],
	"Charcuterie_Board": ["cheese", "salami"],
	"Salami_Rose": ["salami"],
	
	# İçecekler
	"Banana_Milk": ["mulk", "banana"],
	"Blueberry_Milk": ["mulk", "blueberrys"],
	"Hot_Milk": ["mulk"],
	"Blueberry_Jam": ["blueberrys", "sugar"],
	"Smoothie": ["mulk", "banana", "blueberrys"],
	"Granola": ["oats", "sugar"],
	"Ghee": ["butter"]
}
