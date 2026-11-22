class_name Records
extends RefCounted
## This device's HALL OF FAME: the last shifts played (newest first) and the best score per map, kept on the device.

const KEEP := 20
static var path := "user://records.cfg"  ## tests point this elsewhere


## entry: {t, map, coins, stars, mine, title, rank, partner, partner_pts}
static func add(entry: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	var recent: Array = cfg.get_value("scores", "recent", [])
	recent.push_front(entry)
	cfg.set_value("scores", "recent", recent.slice(0, KEEP))
	var key := "best_%d" % int(entry.map)
	if int(entry.coins) > int(cfg.get_value("scores", key, {"coins": -1}).coins):
		cfg.set_value("scores", key, entry)
	var err := cfg.save(path)
	if err != OK:
		push_warning("could not save the scores: %s" % error_string(err))


static func recent() -> Array:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return cfg.get_value("scores", "recent", [])


## The best shift on `map`, or {} when it was never played.
static func best(map: int) -> Dictionary:
	var cfg := ConfigFile.new()
	cfg.load(path)
	return cfg.get_value("scores", "best_%d" % map, {})
