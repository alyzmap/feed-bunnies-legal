extends CanvasLayer

@onready var book_back = $BookBack
@onready var book_mid = $BookBack/BookMid
@onready var book_pages = $BookBack/BookPages
@onready var left_page = $LeftPage
@onready var left_content = $LeftPage/LeftContent
@onready var right_page = $RightPage
@onready var close_button = $CloseButton

var is_open: bool = false
var current_recipe_index: int = 0

# Tüm tarifler ve açıklamaları - MALZEME SAYISINA GÖRE SIRALANMIŞ (az→çok)
var recipes: Array[Dictionary] = [
	# 1 malzemeli (en basit)
	{
		"name": "Sunny Side Up Egg",
		"ingredients": ["egg"],
		"description": "Güneş gibi parlak! Tavuğun en büyük eseri."
	},
	{
		"name": "Boiled Egg",
		"ingredients": ["egg"],
		"description": "Sert kabuk, yumuşak kalp. Tam bir zırhlı şövalye!"
	},
	{
		"name": "Flat Bread",
		"ingredients": ["flour"],
		"description": "Düz, sade ama vazgeçilmez. Ekmeğin minimalist versiyonu."
	},
	{
		"name": "Crispy Toast",
		"ingredients": ["bread"],
		"description": "Çıtır çıtır! Sessizce yemek imkansız."
	},
	{
		"name": "Bland Sandwich",
		"ingredients": ["bread"],
		"description": "Sade... çok sade... belki fazla sade?"
	},
	{
		"name": "Baked Banana",
		"ingredients": ["banana"],
		"description": "Fırından çıkan tatlı sürpriz!"
	},
	{
		"name": "Fried Banana",
		"ingredients": ["banana"],
		"description": "Çıtır dışı, yumuşak içi. Muz'un golden versiyonu!"
	},
	{
		"name": "Fondue",
		"ingredients": ["cheese"],
		"description": "Erimiş peynir havuzu! Daldır ve mutlu ol."
	},
	{
		"name": "Salami Rose",
		"ingredients": ["salami"],
		"description": "Romantik salam sanatı. Instagram'a hazır!"
	},
	{
		"name": "Hot Milk",
		"ingredients": ["milk"],
		"description": "Sıcacık sarılma hissi kupa kupa!"
	},
	{
		"name": "Ghee",
		"ingredients": ["butter"],
		"description": "Altın yağ! Hint mutfağının sırrı."
	},
	# 2 malzemeli
	{
		"name": "Banana Bread",
		"ingredients": ["bread", "banana"],
		"description": "Muz: 'Ekmek olmak istiyorum!' Gerçekleşti hayali!"
	},
	{
		"name": "French Toast",
		"ingredients": ["bread", "egg"],
		"description": "Fransa'nın kahvaltı diplomasisi. 'Bonjour!'"
	},
	{
		"name": "Egg Sandwich",
		"ingredients": ["bread", "egg"],
		"description": "Basit ama etkili. Klasikler asla ölmez!"
	},
	{
		"name": "Cheese Sandwich",
		"ingredients": ["bread", "cheese"],
		"description": "Peynirli mutluluk iki dilim arasında!"
	},
	{
		"name": "Salami Sandwich",
		"ingredients": ["bread", "salami"],
		"description": "İtalyan usulü lezzet bombası!"
	},
	{
		"name": "Pancakes",
		"ingredients": ["flour", "egg"],
		"description": "Yumuşacık bulutlar! Akçaağaç şurubu eklemek serbest."
	},
	{
		"name": "Plain Porridge",
		"ingredients": ["oats", "milk"],
		"description": "Sıcacık, rahatlatıcı. Babaannenin favorisi!"
	},
	{
		"name": "Banana Milk",
		"ingredients": ["milk", "banana"],
		"description": "Sarı güç suyu! Maymunların favorisi (ve tavşanların da)."
	},
	{
		"name": "Blueberry Milk",
		"ingredients": ["milk", "blueberry"],
		"description": "Mor sihir sıvı halde! Büyülü lezzet."
	},
	{
		"name": "Blueberry Jam",
		"ingredients": ["blueberry", "sugar"],
		"description": "Ekmeğin en iyi arkadaşı! Tatlı dostluk."
	},
	{
		"name": "Granola",
		"ingredients": ["oats", "sugar"],
		"description": "Çıtır çıtır enerji paketleri!"
	},
	{
		"name": "Fruit Salad",
		"ingredients": ["banana", "blueberry"],
		"description": "Renkli vitamin bombası! Doğanın şeker bombası."
	},
	{
		"name": "Charcuterie Board",
		"ingredients": ["cheese", "salami"],
		"description": "Sosyal medyada paylaşmak için yapılmış!"
	},
	# 3 malzemeli
	{
		"name": "Banana French Toast",
		"ingredients": ["bread", "egg", "banana"],
		"description": "Fransa + Tropik. Eiffel Kulesi palmiye ağacının altında!"
	},
	{
		"name": "Blueberry French Toast",
		"ingredients": ["bread", "egg", "blueberry"],
		"description": "Mor renkli Fransız şıklığı. Très chic!"
	},
	{
		"name": "Egg Cheese Sandwich",
		"ingredients": ["bread", "egg", "cheese"],
		"description": "Protein + Kalsiyum = Güçlü tavşanlar!"
	},
	{
		"name": "Egg Salami Sandwich",
		"ingredients": ["bread", "egg", "salami"],
		"description": "Sabah enerjisi maksimum seviyede!"
	},
	{
		"name": "Cheese Salami Sandwich",
		"ingredients": ["bread", "cheese", "salami"],
		"description": "İki dost bir arada. Lezzet garantili!"
	},
	{
		"name": "Banana Pancakes",
		"ingredients": ["flour", "egg", "banana"],
		"description": "Tropik tatil hissi veren pankekler!"
	},
	{
		"name": "Healthy Pancakes",
		"ingredients": ["flour", "egg", "oats"],
		"description": "Sağlıklı ama hala lezzetli. Win-win!"
	},
	{
		"name": "Banana Porridge",
		"ingredients": ["oats", "milk", "banana"],
		"description": "Muzlu mutluluk kase kase!"
	},
	{
		"name": "Blueberry Porridge",
		"ingredients": ["oats", "milk", "blueberry"],
		"description": "Mor rüyalar! Her kaşık bir macera."
	},
	{
		"name": "Mug Cake",
		"ingredients": ["flour", "egg", "sugar"],
		"description": "5 dakikada kek! Sabırsızlar için mükemmel."
	},
	{
		"name": "Quiche",
		"ingredients": ["egg", "cheese", "flour"],
		"description": "Fancy omlet! Fransız usulü şık kahvaltı."
	},
	{
		"name": "Smoothie",
		"ingredients": ["milk", "banana", "blueberry"],
		"description": "Sağlıklı tsunami! Güne enerjik başla."
	},
	# 4 malzemeli (en karmaşık)
	{
		"name": "Egg Cheese Salami Sandwich",
		"ingredients": ["bread", "egg", "cheese", "salami"],
		"description": "Süper lüks kombo! VIP sandviç deneyimi."
	},
	{
		"name": "Healthy Blueberry Pancakes",
		"ingredients": ["flour", "egg", "oats", "blueberry"],
		"description": "Antioksidan dolu mor güç! Süper kahraman pankekleri."
	},
	{
		"name": "Blueberry Banana Porridge",
		"ingredients": ["oats", "milk", "blueberry", "banana"],
		"description": "Meyve partisi kasede! Davetlisin!"
	}
]

# Malzeme adlarından chalk dosyalarına map
var ingredient_to_chalk := {
	"banana": "banana_chalk",
	"blueberry": "blueberry_chalk",
	"bread": "bread_chalk",
	"egg": "egg_chalk",
	"cheese": "cheese_chalk",
	"salami": "salami_chalk",
	"butter": "butter_chalk",
	"milk": "milk_chalk",
	"oats": "oats_chalk",
	"flour": "flour_chalk",
	"salt": "salt_chalk",
	"sugar": "glass_chalk"  # sugar için glass_chalk kullanılıyor
}

func _ready():
	visible = false
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

func open_book():
	visible = true
	is_open = true
	current_recipe_index = 0
	_update_pages()

func close_book():
	visible = false
	is_open = false

func _on_close_pressed():
	close_book()

func next_recipe():
	if current_recipe_index < recipes.size() - 1:
		current_recipe_index += 1
		_update_pages()

func previous_recipe():
	if current_recipe_index > 0:
		current_recipe_index -= 1
		_update_pages()

func _update_pages():
	if current_recipe_index >= recipes.size():
		return
	
	var recipe := recipes[current_recipe_index]
	
	# Sol sayfa - Ürün listesi (tüm tarifler)
	_update_left_page()
	
	# Sağ sayfa - Seçili tarifin detayları
	_update_right_page(recipe)

func _update_left_page():
	# Sol sayfaya tüm yemek görsellerini grid olarak ekle
	if not left_content:
		return
	
	# Eski içeriği temizle
	for child in left_content.get_children():
		child.queue_free()
	
	# Yemek listesi - sadece görseller
	for i in range(recipes.size()):
		var recipe_dict = recipes[i]
		var food_name: String = recipe_dict["name"] as String
		var food_texture_path: String = "res://assets/" + food_name.replace(" ", "_") + ".png"
		var is_locked = UnlockManager.is_recipe_locked(food_name.replace(" ", "_"))
		
		if ResourceLoader.exists(food_texture_path):
			var food_button := TextureButton.new()
			food_button.texture_normal = load(food_texture_path) as Texture2D
			food_button.custom_minimum_size = Vector2(100, 100)
			food_button.ignore_texture_size = true
			food_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			
			# KİLİTLİ TARİFLER SİYAH + "?"
			if is_locked:
				food_button.modulate = Color(0.2, 0.2, 0.2, 1.0)  # Çok koyu gri/siyah
				# "?" overlay ekle
				var question_label = Label.new()
				question_label.text = "?"
				question_label.add_theme_font_size_override("font_size", 48)
				question_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
				question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				question_label.size = Vector2(100, 100)
				question_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
				food_button.add_child(question_label)
			elif i == current_recipe_index:
				# Seçili tarif kenarlıklı olsun
				food_button.modulate = Color(1.2, 1.2, 0.8)
			else:
				food_button.modulate = Color(1.0, 1.0, 1.0)
			
			# Tıklamayı bağla
			var recipe_idx := i
			food_button.pressed.connect(func(): _on_recipe_selected(recipe_idx))
			
			left_content.add_child(food_button)

func _on_recipe_selected(idx: int):
	current_recipe_index = idx
	_update_pages()

func _update_right_page(recipe: Dictionary):
	# Sağ sayfayı temizle
	if not right_page:
		return
	
	for child in right_page.get_children():
		child.queue_free()
	
	# Ana container - merkeze almak için
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(0, 20)
	vbox.size = Vector2(300, 480)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	right_page.add_child(vbox)
	
	# Büyük yemek görseli
	var recipe_name: String = recipe["name"] as String
	var food_texture_path: String = "res://assets/" + recipe_name.replace(" ", "_") + ".png"
	if ResourceLoader.exists(food_texture_path):
		var food_image := TextureRect.new()
		food_image.texture = load(food_texture_path) as Texture2D
		food_image.custom_minimum_size = Vector2(180, 180)
		food_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		food_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vbox.add_child(food_image)
	
	# Boşluk
	var spacer1 := Control.new()
	spacer1.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer1)
	
	# Tarif adı
	var title := Label.new()
	title.text = recipe_name
	title.add_theme_color_override("font_color", Color(0.2, 0.4, 0.6))
	title.add_theme_font_size_override("font_size", 16)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(title)
	
	# Boşluk
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer2)
	
	# Malzemeler (chalk görselleri) - yatay sırada
	var ingredients_hbox := HBoxContainer.new()
	ingredients_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	for ingredient in recipe["ingredients"]:
		var chalk_name: String = ingredient_to_chalk.get(ingredient, ingredient + "_chalk") as String
		var chalk_path: String = "res://assets/" + chalk_name + ".png"
		
		if ResourceLoader.exists(chalk_path):
			var chalk_texture := load(chalk_path) as Texture2D
			if chalk_texture:
				var sprite := TextureRect.new()
				sprite.texture = chalk_texture
				sprite.custom_minimum_size = Vector2(40, 40)
				sprite.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ingredients_hbox.add_child(sprite)
	
	vbox.add_child(ingredients_hbox)
	
	# Boşluk
	var spacer3 := Control.new()
	spacer3.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer3)
	
	# Açıklama
	var desc := Label.new()
	desc.text = recipe["description"]
	desc.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	desc.add_theme_font_size_override("font_size", 11)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.custom_minimum_size = Vector2(280, 0)
	vbox.add_child(desc)
