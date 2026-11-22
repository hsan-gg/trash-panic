extends Node
## Dev tool: one client of a real online match against a local server. Quick-matches, plays with random scripted input,
## then saves a 1280x720 screenshot and prints a state digest to compare between the two clients.
## godot --path game res://tests/net_smoke.tscn -- --play-url=ws://localhost:8787/play --name=A --seconds=40 --out=/abs/a.png

var _session: Session
var _vp := SubViewport.new()
var _rng := RandomNumberGenerator.new()
var _out := "user://net.png"
var _seconds := 40.0
var _t := 0.0
var _act_t := 0.0


func _ready() -> void:
	var player_name := "BOT"
	var map := 0
	var mode := "quick"
	var code := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--name="):
			player_name = a.trim_prefix("--name=")
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--seconds="):
			_seconds = float(a.trim_prefix("--seconds="))
		elif a == "--create":  # a private room: prints its code; the partner joins with --join=CODE
			mode = "create"
		elif a.begins_with("--join="):
			mode = "join"
			code = a.trim_prefix("--join=")
		elif a.begins_with("--map="):  # 1-3: the host's pick is played
			map = int(a.trim_prefix("--map=")) - 1
	_rng.seed = hash(player_name)
	Gate.set_process(false)  # the gate watches the production server; this test talks to --play-url only
	Gate.visible = false
	get_tree().paused = false
	Controls.register_actions()
	_vp.size = Vector2i(1280, 720)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	Match.started.connect(_on_started)
	Match.failed.connect(func(code: String) -> void: _finish("FAILED " + code))
	Match.waiting.connect(func(info: Dictionary) -> void: print("[%s] waiting %s" % [player_name, str(info)]))
	Match.join(player_name, _rng.randi() % Avatar.SKINS.size(), mode, code, map)


func _on_started(info: Dictionary) -> void:
	print("[%s] started host=%s seed=%s players=%s" % [Match.players.get(Match.my_id, {}).get("name", "?"), Match.is_host(), str(info.seed), str(Match.players.values().map(func(p: Dictionary) -> String: return p.name))])
	_session = Session.new()
	_vp.add_child(_session)
	_session.setup(info)


func _process(delta: float) -> void:
	if _session == null:
		return
	_t += delta
	_act_t -= delta
	if _act_t <= 0.0:  # a restless worker: new direction, and grab / throw now and then
		_act_t = _rng.randf_range(0.3, 0.8)
		for a in ["move_left", "move_right", "move_forward", "move_back"]:
			Input.action_release(a)
		Input.action_press(["move_left", "move_right", "move_forward", "move_back"][_rng.randi() % 4])
		if _rng.randf() < 0.7:
			_session.controls.action_pressed.emit()
			_session.controls.action_released.emit()
		elif _rng.randf() < 0.5:
			_session.controls.dash_pressed.emit()
	if _t >= _seconds:
		_finish("ok")


func _finish(status: String) -> void:
	set_process(false)
	if _session != null:
		_vp.get_texture().get_image().save_png(_out)
		var sh := _session.shift
		var tiles := sh.items.values().filter(func(it: Dictionary) -> bool: return it.at != null).map(func(it: Dictionary) -> String: return "%s@%d,%d" % [it.k, it.at.x, it.at.y])
		tiles.sort()
		print("DIGEST map=%d host=%s elapsed=%.1f coins=%d items=%d creatures=%d orders=%d tiles=%s" % [Rules.map + 1, Match.is_host(), sh.elapsed, sh.coins, sh.items.size(), sh.mayhem.creatures.size(), sh.orders.size(), ",".join(tiles)])
	print("STATUS ", status)
	get_tree().quit()
