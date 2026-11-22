class_name Profile
extends RefCounted
## The guest identity saved on this device: a nickname, a skin and the map last picked. No account needed to play.

const PATH := "user://profile.cfg"
const OLD_NAMES := ["Sorter", "Scrapper", "Rusty", "Binny", "Sparky", "Copper", "Pixel", "Tinker"]  ## pre-v11 auto names
## Silly nicknames: an adjective and a noun, 12 characters at most (the server's limit).
const ADJECTIVES := ["Soggy", "Stinky", "Crusty", "Wobbly", "Sneaky", "Grumpy", "Sticky", "Funky", "Moldy", "Zesty", "Dizzy", "Smelly"]
const NOUNS := ["Sock", "Bin", "Banana", "Pickle", "Noodle", "Burrito", "Can", "Nugget", "Waffle", "Goblin", "Potato", "Raccoon"]


static func load_or_create() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		var p := {"name": funny_name(), "skin": randi() % Avatar.SKINS.size(), "map": 0}
		save(p)
		return p
	var saved := str(cfg.get_value("me", "name", "Player"))
	if OLD_NAMES.any(func(n: String) -> bool: return saved.begins_with(n) and saved.trim_prefix(n).is_valid_int()):
		saved = funny_name()  # an old boring auto name: give them a silly one (kept from now on)
		cfg.set_value("me", "name", saved)
		cfg.save(PATH)
	return {"name": saved, "skin": posmod(int(cfg.get_value("me", "skin", 0)), Avatar.SKINS.size()),
		"map": posmod(int(cfg.get_value("me", "map", 0)), Rules.MAPS.size())}


static func funny_name() -> String:
	var out := ""
	while out == "" or out.length() > 12:
		out = ADJECTIVES.pick_random() + NOUNS.pick_random()
	return out


static func tutorial_done() -> bool:
	var cfg := ConfigFile.new()
	return cfg.load(PATH) == OK and bool(cfg.get_value("me", "tutorial_done", false))


static func finish_tutorial() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("me", "tutorial_done", true)
	cfg.save(PATH)


static func save(p: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)  # keep the tutorial flag
	cfg.set_value("me", "name", p.name)
	cfg.set_value("me", "skin", p.skin)
	cfg.set_value("me", "map", p.get("map", 0))
	cfg.save(PATH)


## Options saved on the device: music, sound, vibration (all on by default).
static func option(key: String) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	return bool(cfg.get_value("options", key, true))


static func set_option(key: String, on: bool) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("options", key, on)
	cfg.save(PATH)
	apply_options()


static func apply_options() -> void:
	Sfx.set_music(option("music"))
	Sfx.sfx_on = option("sound")
	Juice.haptics = option("haptics")
