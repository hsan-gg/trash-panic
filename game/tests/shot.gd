extends Node
## Dev tool: play a host shift offline with an idle partner and save screenshots.
## godot --path game res://tests/shot.tscn -- --at=40 --out=/abs/path/shot.png [--creatures=elephant,pig] [--chaos=blackout] [--hold=can]

func _ready() -> void:
	var at := 20.0
	var out := "user://shot.png"
	var creatures: PackedStringArray = []
	var chaos := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--at="):
			at = float(a.trim_prefix("--at="))
		elif a.begins_with("--out="):
			out = a.trim_prefix("--out=")
		elif a.begins_with("--creatures="):
			creatures = a.trim_prefix("--creatures=").split(",")
		elif a.begins_with("--chaos="):
			chaos = a.trim_prefix("--chaos=")
	Gate.set_process(false)  # offline shots: no "signal lost" pause
	Gate.visible = false
	get_tree().paused = false
	var vp := SubViewport.new()  # fixed landscape frame: the tiling window manager resizes the real window
	vp.size = Vector2i(1920, 1080) if "--hd" in OS.get_cmdline_user_args() else Vector2i(1280, 720)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	Records.path = "user://shot_records.cfg"  # screenshots never touch the real scores
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Records.path))
	if "--scores" in OS.get_cmdline_user_args():  # some made-up history for the HALL OF FAME
		for c in [[0, 120, 1], [1, 260, 2], [0, 390, 3], [2, 90, 1]]:
			Records.add({"t": int(Time.get_unix_time_from_system()), "map": c[0], "coins": c[1], "stars": c[2], "mine": c[1] / 2,
				"title": "BOMB HUGGER", "rank": 1, "partner": "SoggyPickle", "partner_pts": c[1] / 3})
	if "--title" in OS.get_cmdline_user_args():
		var main: Node = load("res://app/main.tscn").instantiate()
		vp.add_child(main)
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--skin="):  # show that worker on the menu (not saved)
				main._profile.skin = int(a.trim_prefix("--skin="))
				main._show_title()
			if a.begins_with("--map="):  # show that map on the menu (not saved)
				main._profile.map = int(a.trim_prefix("--map=")) - 1
				main._show_backdrop()
				main._show_title()
		if "--scores" in OS.get_cmdline_user_args() and "--menu" not in OS.get_cmdline_user_args():
			main._show_scores()
		await get_tree().create_timer(2.5).timeout
		await _save(vp, out)
		get_tree().quit()
		return
	var keep_tut := "--tutorial" in OS.get_cmdline_user_args()
	Match.my_id = 1
	Match.host_id = 1
	var ch := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):  # 1-3
			ch = int(a.trim_prefix("--map=")) - 1
	Match.players = {1: {"id": 1, "name": "ME", "skin": 1, "tut": not keep_tut, "ch": ch}, 2: {"id": 2, "name": "PAL", "skin": 0, "tut": true}}
	var s := Session.new()
	var now := Clock.now()
	vp.add_child(s)
	s.setup({"seed": 7, "start_at": (now - 4.0) * 1000.0, "ends_at": (now - 4.0 + Rules.SHIFT_S) * 1000.0, "solo": false})
	await get_tree().create_timer(0.3).timeout
	var keep_tutorial := "--tutorial" in OS.get_cmdline_user_args()
	if s.tutorial != null and not keep_tutorial:
		s.tutorial.queue_free()
		s.shift.training = false
	for i in int(maxf(0.0, at - 2.0) * 10.0):  # fast-forward the simulation, then let the view catch up
		s.shift.tick(0.1)
	for k in creatures:
		var spot: Variant = s.shift.mayhem.free_tile(randi() % 2 + 1)
		if spot != null:
			s.shift.mayhem._add_creature(k, spot, false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hold="):  # the local worker carries this item kind
			var id := s.shift._spawn(a.trim_prefix("--hold="), "5", s.room.spawns[1])
			s.shift.items[id].at = null
			s.shift.items[id].by = 1
	if chaos != "":
		s.shift.mayhem.chaos = chaos
		s.shift.mayhem.chaos_left = Rules.CHAOS_S
	await get_tree().create_timer(4.0).timeout  # the countdown slams finish
	if s.tutorial != null and not keep_tutorial:
		s.tutorial.queue_free()
		await get_tree().process_frame
	if "--shark" in OS.get_cmdline_user_args():  # catch the shark mid-leap at a left-edge tile
		s.shift.cues.append({"e": "shark_alert", "at": Vector2i(1, 3)})
		await get_tree().create_timer(1.8).timeout
		if "--zone" not in OS.get_cmdline_user_args():  # --zone: shoot the warning (red squares) instead of the leap
			s.shift.cues.append({"e": "shark", "at": Vector2i(1, 3)})
			await get_tree().create_timer(0.3).timeout
	if "--results" in OS.get_cmdline_user_args():  # the results card with a made-up scoreboard
		for e in [{"e": "load", "who": 1, "pts": 130}, {"e": "rescued", "who": 2, "pts": 60}, {"e": "load", "who": 2, "pts": 95},
				{"e": "wrong", "who": 1, "pts": -5}, {"e": "wrong", "who": 1, "pts": -5}, {"e": "repaired", "who": 1}, {"e": "safe", "who": 2, "pts": 90}]:
			s.hud._board.track(e)
		s.shift.coins = 365  # a believable 3-star shift for the results card
		s.shift.stats = {"orders": 5, "wrong": 2, "late": 1, "booms": 1}
		s.shift.best_combo = 9
		s.controls.hide_buttons()
		s.hud.show_results(s.shift)
		await get_tree().create_timer(3.0).timeout
	_stage_beats(s)
	if "--autopilot" in OS.get_cmdline_user_args():
		var pilot: Node = load("res://tests/autopilot.gd").new()
		pilot.session = s
		add_child(pilot)
	await _save(vp, out)
	print("draw calls: ", RenderingServer.viewport_get_render_info(vp.get_viewport_rid(), RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE, RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME))
	get_tree().quit()


## One PNG, or with --frames=N a clip: <out>0000.png, <out>0001.png ... (run Godot with --fixed-fps 30 for smooth time).
func _save(vp: SubViewport, out: String) -> void:
	var frames := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames = int(a.trim_prefix("--frames="))
	if frames <= 0:
		vp.get_texture().get_image().save_png(out)
		return
	for f in frames:
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("%s%04d.png" % [out, f])


## Trailer beats: --bomb (a lit bomb next to you, about to blow), --combo=N (a hot streak), --door (exit doors open,
## you hold a battery), --clean (no tip bubbles or ping on screen).
func _stage_beats(s: Session) -> void:
	var args := OS.get_cmdline_user_args()
	var me: Vector2i = s.shift.players[1].tile
	if "--clean" in args:
		for k in Hud.FACTS:
			s.hud._told[k] = true
		s.hud._bubble.visible = false
		Net.set_process(false)
		Net.rtt_ms = -1
	if "--bomb" in args:
		s.shift.mayhem._land("bomb", me + Vector2i.RIGHT)
		for id in s.shift.mayhem._fuses:
			s.shift.mayhem._fuses[id] = 2.4
	for a in args:
		if a.begins_with("--combo="):
			s.shift.combo = int(a.trim_prefix("--combo="))
			s.shift._combo_t = 30.0
	if "--door" in args:
		for at in s.shift.stations:
			if s.room.type_at(at) == "exit":
				s.shift.stations[at].t = 30.0
		var id := s.shift._spawn("battery", "", me)
		s.shift.items[id].at = null
		s.shift.items[id].by = 1
