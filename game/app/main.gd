extends Node
## Title → QUICK PLAY / CREATE ROOM / JOIN → waiting for a partner → shift → results → again or title.

var _profile: Dictionary = Profile.load_or_create()
var _screen: Control
var _status: Label
var _session: Session
var _code_edit: LineEdit
var _backdrop: TitleScene
var _update_waiting := false  ## web: a new deploy is ready; applied on the title screen, never mid-shift


func _ready() -> void:
	Controls.register_actions()
	add_child(RotateHint.new())
	Profile.apply_options()
	Match.waiting.connect(_on_waiting)
	Match.started.connect(_on_started)
	Match.failed.connect(_on_failed)
	Match.disconnected.connect(_on_disconnected)
	if OS.has_feature("web"):  # the PWA service worker serves its cached build until told to update
		JavaScriptBridge.pwa_update_available.connect(func() -> void:
			_update_waiting = true
			if not is_instance_valid(_session):
				_apply_update())
		_update_waiting = JavaScriptBridge.pwa_needs_update()
	_show_title()


func _show_title() -> void:
	if _update_waiting:
		_apply_update()
		return
	_clear()
	_screen = _new_screen()
	var shade := ColorRect.new()  # calm the 3D floor behind so the menu reads
	shade.color = Color(0.05, 0.08, 0.16, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(shade)
	_trash_rain()
	var logo := TextureRect.new()
	logo.texture = load("res://core/assets/ui/logo.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(logo, Vector2(-330, -356), Vector2(660, 226))
	_screen.add_child(logo)
	# Left card: pick your worker.
	var pick := _card(Vector2(-560, -116), Vector2(430, 452))
	var header := Look.label("PICK YOUR WORKER", 28, Look.PRIMARY, true)
	header.position = Vector2(0, 12)
	header.size = Vector2(430, 40)
	pick.add_child(header)
	var me := WorkerPreview.new()
	me.position = Vector2(95, 52)
	me.size = Vector2(240, 300)
	pick.add_child(me)
	me.show_worker(_profile.skin)
	var skin_name := Look.label(Avatar.SKINS[posmod(_profile.skin, Avatar.SKINS.size())].name, 34, Look.WHITE, true)
	skin_name.position = Vector2(0, 360)
	skin_name.size = Vector2(430, 60)
	pick.add_child(skin_name)
	for step in [-1, 1]:
		var arrow := Look.button("<" if step < 0 else ">", Look.HUD_DARK.lightened(0.12), 44)
		arrow.position = Vector2(20 if step < 0 else 330, 170)
		arrow.size = Vector2(80, 84)
		arrow.pressed.connect(func() -> void:
			_profile.skin = posmod(_profile.skin + step, Avatar.SKINS.size())
			skin_name.text = Avatar.SKINS[_profile.skin].name
			me.show_worker(_profile.skin)
			Juice.squash(skin_name)
			Sfx.play("ui_click"))
		pick.add_child(arrow)
	# Right card: name, PLAY, and playing with a friend.
	var go := _card(Vector2(-100, -116), Vector2(660, 452))
	# The map to play (the room's host picks for both).
	var map_name := Look.label("", 28, Look.YELLOW, true)
	map_name.position = Vector2(120, 14)
	map_name.size = Vector2(420, 66)
	go.add_child(map_name)
	var show_map := func() -> void:
		var rec := Records.best(_profile.map)
		var record := "  ·  BEST %d" % int(rec.coins) if not rec.is_empty() else ""
		map_name.text = "MAP %d%s\n%s" % [_profile.map + 1, record, Rules.MAPS[_profile.map].name]
	show_map.call()
	for step in [-1, 1]:
		var arrow := Look.button("<" if step < 0 else ">", Look.HUD_DARK.lightened(0.12), 36)
		arrow.position = Vector2(40 if step < 0 else 550, 14)
		arrow.size = Vector2(70, 66)
		arrow.pressed.connect(func() -> void:
			_profile.map = posmod(_profile.map + step, Rules.MAPS.size())
			show_map.call()
			_show_backdrop()  # the map behind the menu changes with the pick
			Juice.squash(map_name)
			Sfx.play("ui_click"))
		go.add_child(arrow)
	var name_edit := LineEdit.new()
	name_edit.text = _profile.name
	name_edit.placeholder_text = "YOUR NAME"
	name_edit.max_length = 12
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.add_theme_font_size_override("font_size", 30)
	name_edit.position = Vector2(40, 92)
	name_edit.size = Vector2(500, 58)
	name_edit.text_changed.connect(func(t: String) -> void: _profile.name = t)
	go.add_child(name_edit)
	var reroll := Look.button("", Look.PINK, 20)  # a new silly name
	reroll.icon = Look.glyph("reverse")
	reroll.expand_icon = true
	reroll.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reroll.add_theme_constant_override("icon_max_width", 36)
	reroll.position = Vector2(552, 90)
	reroll.size = Vector2(68, 62)
	reroll.pressed.connect(func() -> void:
		_profile.name = Profile.funny_name()
		name_edit.text = _profile.name
		Juice.squash(name_edit)
		Sfx.play("ui_click"))
	go.add_child(reroll)
	var quick := Look.button("PLAY", Look.PRIMARY, 72)
	quick.position = Vector2(40, 164)
	quick.size = Vector2(580, 108)
	quick.pressed.connect(func() -> void: _go("quick"))
	go.add_child(quick)
	var friend := Look.label("PLAY WITH A FRIEND", 22, Look.WHITE.darkened(0.25), true)
	friend.position = Vector2(40, 292)
	friend.size = Vector2(580, 30)
	go.add_child(friend)
	var create := Look.button("CREATE ROOM", Look.HUD_DARK.lightened(0.12), 26)
	create.position = Vector2(40, 334)
	create.size = Vector2(250, 78)
	create.pressed.connect(func() -> void: _go("create"))
	go.add_child(create)
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "CODE"
	_code_edit.max_length = 4
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.add_theme_font_size_override("font_size", 30)
	_code_edit.position = Vector2(308, 338)
	_code_edit.size = Vector2(150, 70)
	go.add_child(_code_edit)
	var join := Look.button("JOIN", Look.HUD_DARK.lightened(0.12), 26)
	join.position = Vector2(476, 334)
	join.size = Vector2(144, 78)
	join.pressed.connect(func() -> void:
		if _code_edit.text.length() == 4:
			_go("join", _code_edit.text))
	go.add_child(join)
	var scores := Look.button("  SCORES", Look.PINK, 28)
	scores.icon = load("res://core/assets/ui/star.png")
	scores.expand_icon = true
	scores.add_theme_constant_override("icon_max_width", 40)
	scores.position = Vector2(24, 20)
	scores.size = Vector2(220, 72)
	scores.pressed.connect(_show_scores)
	_screen.add_child(scores)
	_pop_in([logo, pick, go, scores])
	Sfx.music("title")


## The HALL OF FAME: best shift per map and the latest shifts on this device.
func _show_scores() -> void:
	Sfx.play("ui_click")
	_clear()
	_screen = _new_screen()
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.08, 0.16, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(shade)
	var board := ScoresScreen.new()
	_place(board, -ScoresScreen.SIZE / 2.0, ScoresScreen.SIZE)
	_screen.add_child(board)
	board.back_pressed.connect(func() -> void:
		Sfx.play("ui_click")
		_show_title())
	Juice.squash(board)


## Junk icons tumble down behind the menu, forever.
func _trash_rain() -> void:
	var junk := ["trash", "bomb", "battery", "plastic", "glass", "paper", "metal", "nuke", "raccoon", "chicken"]
	var view := get_viewport().get_visible_rect().size
	for i in 14:
		var t := TextureRect.new()
		t.texture = Look.glyph(junk[i % junk.size()])
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.size = Vector2.ONE * randf_range(34, 64)
		t.pivot_offset = t.size / 2.0
		t.modulate = Color(1, 1, 1, randf_range(0.18, 0.35))
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen.add_child(t)
		var x := randf_range(0, view.x)
		var fall := randf_range(7.0, 13.0)
		t.position = Vector2(x, randf_range(-view.y, 0))
		var tw := t.create_tween().set_loops()
		tw.tween_interval(randf_range(0.0, 3.0))  # staggered, not a wall of junk
		tw.tween_property(t, "position", Vector2(x + randf_range(-80, 80), view.y + 80), fall).from(Vector2(x, -80))
		var spin := t.create_tween().set_loops()
		spin.tween_property(t, "rotation", TAU * (1 if i % 2 == 0 else -1), randf_range(4.0, 9.0)).from(0.0)


## A dark chunky menu card centred on `offset` (from the screen centre).
func _card(offset: Vector2, box: Vector2) -> Panel:
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", Look.chunky(Color(Look.HUD_DARK, 0.95), 22))
	_place(card, offset, box)
	_screen.add_child(card)
	return card


## Everything springs in one after the other, and the logo keeps breathing.
func _pop_in(nodes: Array) -> void:
	for i in nodes.size():
		var n: Control = nodes[i]
		n.pivot_offset = n.size / 2.0
		n.scale = Vector2.ZERO
		n.create_tween().tween_property(n, "scale", Vector2.ONE, 0.45).set_delay(i * 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var logo: Control = nodes[0]
	var breathe := logo.create_tween().set_loops()
	breathe.tween_interval(1.0)
	breathe.tween_property(logo, "scale", Vector2.ONE * 1.03, 1.4).set_trans(Tween.TRANS_SINE)
	breathe.tween_property(logo, "scale", Vector2.ONE, 1.4).set_trans(Tween.TRANS_SINE)


## Reloads every tab of the game into the newly deployed version.
func _apply_update() -> void:
	var err := JavaScriptBridge.pwa_update()
	if err != OK:
		push_warning("PWA update failed: %s" % error_string(err))
		_update_waiting = false
		_show_title()


func _go(mode: String, code := "") -> void:
	Sfx.play("ui_confirmation")
	Profile.save(_profile)
	_show_waiting("Connecting...")
	Match.join(_profile.name, _profile.skin, mode, code, _profile.map)


func _show_waiting(text: String) -> void:
	_clear()
	_screen = _new_screen()
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", Look.chunky(Color(Look.HUD_DARK, 0.94), 22))
	_place(panel, Vector2(-330, -180), Vector2(660, 340))
	_screen.add_child(panel)
	_status = Look.label(text, 44, Look.WHITE, true)
	_status.position = Vector2(20, 30)
	_status.size = Vector2(620, 180)
	panel.add_child(_status)
	var back := Look.button("BACK", Look.HUD_DARK.lightened(0.12), 30)
	_place(back, Vector2(-120, 60), Vector2(240, 80))
	back.pressed.connect(func() -> void:
		Match.leave()
		_show_title())
	_screen.add_child(back)
	Sfx.music("lobby")


func _on_waiting(info: Dictionary) -> void:
	if info.get("mode") == "create":
		_status.text = "Room code  %s\nShare it with your partner!" % str(info.get("code", "????"))
	else:
		_status.text = "Waiting for a partner...\nShifts are for two!"


func _on_started(info: Dictionary) -> void:
	_clear()
	if is_instance_valid(_backdrop):
		_backdrop.queue_free()
	if is_instance_valid(_session):
		_session.queue_free()
	_session = Session.new()
	add_child(_session)
	_session.setup(info)
	_session.finished.connect(_on_shift_finished)


func _on_shift_finished(again: bool) -> void:
	if again:
		Match.again()
		_session.hud.slam("WAITING FOR PARTNER...", Look.SKY)
		return
	Match.leave()
	_session.queue_free()
	_show_title()


func _on_failed(code: String) -> void:
	var why := {"no_room": "No open room with that code.", "bad_hello": "Something went wrong. Try again.",
		"old_version": "Your partner runs another version. Update or refresh both!"}
	_show_title()
	Juice.slam(_screen, why.get(code, code), Look.PINK, 1.6, 54)
	Match.leave()


func _on_disconnected() -> void:
	if is_instance_valid(_session):
		_session.queue_free()
	_show_title()


func _show_backdrop() -> void:
	if is_instance_valid(_backdrop):
		_backdrop.queue_free()
	_backdrop = TitleScene.new()
	_backdrop.map = _profile.map
	add_child(_backdrop)
	move_child(_backdrop, 0)  # behind the menu


func _new_screen() -> Control:
	if not is_instance_valid(_backdrop):  # the picked map behind every menu
		_show_backdrop()
	var c := Control.new()
	c.theme = Look.theme()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(c)
	return c


func _place(c: Control, offset: Vector2, box: Vector2) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER)
	c.offset_left = offset.x
	c.offset_top = offset.y
	c.offset_right = offset.x + box.x
	c.offset_bottom = offset.y + box.y


func _clear() -> void:
	if is_instance_valid(_screen):
		_screen.queue_free()
	_status = null
