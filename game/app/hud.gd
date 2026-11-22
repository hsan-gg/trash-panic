class_name Hud
extends Control
## Shift HUD: score, timer, truck tickets, FRU-01's speech bubble, slams and the results card.

signal again_pressed
signal menu_pressed

const MATERIAL_COLORS := ItemArt.MATERIAL_COLORS
const MISTAKES := {"wrong": "WRONG INPUT"}
## The Dropper (and the factory) explain each new trouble the first time it shows up.
const FACTS := {
	"door_open": "DOOR OPEN! The HAZMAT truck waits outside: toss bombs, barrels and batteries out the door before it shuts!",
	"left_side": "Waste rains on YOUR side: put it on the BELT to the machine. Your partner sends you bombs, barrels and batteries: they go in the bins over here!",
	"right_side": "Your partner belts the waste over: sort it into the machine. Bombs, barrels and batteries fall on YOUR side: send them back on the lower belt, fast!",
	"rot": "Food left on the floor ROTS and pollutes! Get apples and peels into COMPOST fast.",
	"tilt": "The floor tilts! Round waste rolls downhill: don't let it roll to the shark.",
	"trip": "A machine input TRIPPED! Empty your hands and hold the action button on it to reset the breaker.",
	"partner_left": "Your partner left. I opened the gate: you can reach both sides now!",
	"wrong": "Wrong input! The machine only takes the material on its sign.",
	"rush": "RUSH HOUR! Everything is faster, but every point counts DOUBLE. Go go go!",
	"contract": "FINAL CONTRACT! Eight items of one material, double pay. Everything you've got!",
	"jam": "Something is JAMMED! Stand beside it and HOLD the action button to repair it. Throw items over meanwhile!",
	"drop_bomb": "DROPPER: Oops. Was that a bomb? Belt it or THROW it to your partner: the BOMB CHUTE is on their side. Hurry!",
	"drop_nuke": "DROPPER: Glowing barrel! Send it to your partner: the NUCLEAR bin is on their side, before it leaks!",
	"drop_battery": "DROPPER: A leaky battery. Send it to your partner's BATTERIES bin!",
	"drop_robot": "DROPPER: One rogue robot. Stand next to it and HOLD the action button to switch it off. It throws your waste around!",
	"drop_raccoon": "DROPPER: A raccoon! HOLD the action button on it before it runs away with your waste!",
	"drop_elephant": "DROPPER: That is an elephant. I did not order an elephant. One of you open an EXIT door (hold the action button on it), the other scare it (hold the action button)!",
	"chaos_blackout": "FACTORY: Lights out! Follow the machine lamps.",
	"chaos_reverse": "FACTORY: REVERSE WORLD! Both belts run backwards. Throw things over instead!",
	"chaos_hurricane": "FACTORY: Hurricane! Everything slides sideways.",
	"chaos_robots": "FACTORY: Robot invasion! HOLD the action button next to each robot to switch it off.",
	"chaos_lowgrav": "FACTORY: LOW GRAVITY! Everything floats, and throws fly twice as far.",
	"chaos_magnet": "FACTORY: MAGNETIC MADNESS! The magnet is dragging every can to the back wall!",
	"drop_chicken": "DROPPER: A chicken?! It knocks waste off the belts. HOLD the action button to catch it!",
	"drop_shark": "SHARK! Get away from the edge: it bites workers and drags waste into the sea!",
	"drop_pig": "DROPPER: A pig that eats PAPER, CARDBOARD and FOOD. Catch it while it chews (HOLD the action button)!",
}

var _coins: Label
var _timer: Label
var _tickets := HBoxContainer.new()
var _stars: ProgressBar
var _rush_banner: Label
var _bubble: PanelContainer
var _bubble_text: Label
var _told := {}
var _tickets_by_id := {}  ## order id -> ticket card
var _last_result := ""  ## "ship" or "late": how the ticket that just left ended
var _star_icons: Array[TextureRect] = []
var _star_got := [false, false, false]
var _shown := 0.0  ## the score on screen counts up toward the real one
var _target := 0
var _board := Scoreboard.new()  ## per-worker points and deeds for the results
var _blame_at := -10.0
var _blame: Label
var _meter: Array[StyleBoxFlat] = []  ## POLLUTION gauge segments (rounded, glossy)
var _booms: Label
var _ping: Label
var _chaos_label: Label
var _menu: Control
var _slams: Array = []  ## big announcements wait their turn so two never overlap
var _slam_busy := 0.0
var _bubble_tween: Tween
var _goals := HudGoals.new()  ## quests, combo, level


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Look.theme()
	var dumpster := _panel(Look.HUD_DARK, Vector2(14, 12), Vector2(196, 80))
	_icon(dumpster, "trash", Vector2(12, 10), 50, Look.WHITE)
	_coins = Look.label("0", 50, Look.WHITE, true)
	_coins.position = Vector2(64, 2)
	_coins.size = Vector2(124, 66)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dumpster.add_child(_coins)
	_build_star_bar()
	_rush_banner = _banner("RUSH HOUR  x2", Look.PINK, 132)
	_timer = Look.label("3:00", 50, Color("22252B"), true)
	_timer.add_theme_constant_override("outline_size", 0)
	var monitor := _panel(Color("5A606B"), Vector2(0, 10), Vector2(200, 88))
	monitor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	monitor.offset_left = -100
	monitor.offset_right = 100
	monitor.offset_top = 10
	monitor.offset_bottom = 98
	var screen := ColorRect.new()
	screen.color = Color("D6DDE3")
	screen.position = Vector2(14, 12)
	screen.size = Vector2(172, 64)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor.add_child(screen)
	_timer.position = Vector2(14, 6)
	_timer.size = Vector2(172, 70)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monitor.add_child(_timer)
	var skull := _panel(Color("C98B4E"), Vector2(150, 66), Vector2(84, 44), monitor)
	_icon(skull, "skull", Vector2(6, 4), 30, Color("22252B"))
	_booms = Look.label("0", 26, Color("22252B"), true)
	_booms.add_theme_constant_override("outline_size", 0)
	_booms.position = Vector2(38, 0)
	_booms.size = Vector2(40, 38)
	skull.add_child(_booms)
	var ping := _panel(Color("2B2F36"), Vector2(-104, 66), Vector2(154, 44), monitor)
	_ping = Look.label("", 18, Color.WHITE, true)
	_ping.add_theme_constant_override("outline_size", 0)
	_ping.size = Vector2(154, 40)
	_ping.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ping.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ping.add_child(_ping)
	_tickets.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tickets.offset_left = -560
	_tickets.offset_right = -14
	_tickets.offset_top = 12
	_tickets.offset_bottom = 132
	_tickets.alignment = BoxContainer.ALIGNMENT_END
	_tickets.add_theme_constant_override("separation", 10)
	_tickets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tickets)
	add_child(_goals)
	_build_bubble()
	_build_menu()
	_build_meter()


## A chunky white-outlined HUD panel at `pos` (a plain Control child, so its contents are placed by hand).
func _panel(color: Color, pos: Vector2, box: Vector2, parent: Control = self) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", Look.chunky(color))
	p.position = pos
	p.size = box
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)
	return p


func _icon(parent: Control, glyph: String, pos: Vector2, size: float, color: Color) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Look.glyph(glyph)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.position = pos
	t.size = Vector2(size, size)
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


## A slanted announcement strip across the top centre (RUSH HOUR, CHAOS STATE), hidden until needed.
func _banner(text: String, color: Color, y: float) -> Label:
	var l := Look.label(text, 34, Look.WHITE, true)
	var style := Look.chunky(color, 12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	l.add_theme_stylebox_override("normal", style)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.offset_left = -230
	l.offset_right = 230
	l.offset_top = y
	l.offset_bottom = y + 58
	l.rotation_degrees = -2.0
	l.pivot_offset = Vector2(230, 29)
	l.visible = false
	add_child(l)
	return l


func _process(delta: float) -> void:
	_shown = move_toward(_shown, _target, maxf(40.0, absf(_target - _shown) * 4.0) * delta)
	_coins.text = "%d" % roundi(_shown)
	_slam_busy = maxf(0.0, _slam_busy - delta)
	if _slam_busy <= 0.0 and not _slams.is_empty():
		var next: Array = _slams.pop_front()
		Juice.slam(self, next[0], next[1], next[2], next[3])
		_slam_busy = next[2] + 0.2


func refresh(shift: Shift) -> void:
	if shift.coins != _target:
		_target = shift.coins
		Juice.squash(_coins)
	var left := ceili(shift.time_left())
	_timer.text = "%d:%02d" % [left / 60, left % 60]
	_timer.add_theme_color_override("font_color", Color("E0303A") if left <= 20 else Color("22252B"))
	if left <= 10 and left > 0:
		_timer.scale = Vector2.ONE * (1.0 + 0.12 * absf(sin(Time.get_ticks_msec() / 160.0)))
		_timer.pivot_offset = _timer.size / 2.0
	_stars.value = lerpf(_stars.value, shift.coins, 0.2)
	for i in Rules.STARS.size():
		if shift.coins >= Rules.STARS[i] and not _star_got[i]:
			_light_star(i)
	_rush_banner.visible = Rules.is_rush(shift.elapsed) and left > 0
	_rush_banner.modulate.a = 0.6 + 0.4 * absf(sin(Time.get_ticks_msec() / 200.0))
	var hot := shift.mayhem.meter >= Rules.CHAOS_AT or shift.mayhem.chaos != ""
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	for i in _meter.size():
		var lit := shift.mayhem.meter >= (i + 0.5) * 100.0 / _meter.size() or shift.mayhem.chaos != ""
		var c := Color("4ADE3A").lerp(Color("FF3B2F"), float(i) / (_meter.size() - 1))
		_meter[i].bg_color = c.lerp(Color.WHITE, blink * 0.5) if lit and hot else (c if lit else Color("4A505B"))
	_booms.text = str(shift.stats.booms)
	_ping.get_parent().visible = Net.rtt_ms >= 0
	_ping.text = "%s  %dms" % [Net.badge().text, Net.rtt_ms]  # the radio (5G SA, 4G, WI-FI...) and the round trip
	_ping.add_theme_color_override("font_color", Color("4ADE3A") if Net.rtt_ms < 90 else (Color("FFD93D") if Net.rtt_ms < 180 else Color("FF3B2F")))
	_chaos_label.visible = shift.mayhem.chaos != ""
	_chaos_label.text = "CHAOS: %s  %ds" % [str(Rules.CHAOS_NAMES.get(shift.mayhem.chaos, shift.mayhem.chaos)), ceili(shift.mayhem.chaos_left)]
	_sync_tickets(shift.orders, Rules.rush_mult(shift.elapsed))
	_goals.refresh(shift)


func on_cue(e: Dictionary) -> void:
	_track(e)
	_goals.on_cue(e)
	match e.e:
		"level":
			_queue_slam("LEVEL %d!  FASTER!" % int(e.n), Color("B48CFF"), 0.6, 120)
			Juice.flash(self, Color("7A3DF0", 0.25), 0.4)
			Juice.shockwave(size / 2.0)
		"quest":
			_queue_slam("QUEST DONE!  +%d" % int(e.pts), Look.MINT, 0.5, 110)
		"combo_lost":
			_queue_slam("COMBO BROKEN", Look.DANGER, 0.3, 80)
		"ship":
			_queue_slam("ORDER DONE! +%d" % int(e.coins), Look.YELLOW, 0.5, 110)
			Juice.squash(_coins)
		"wrong":
			say("wrong")
		"rot", "tilt", "trip":
			say(e.e)
		"late":
			_queue_slam("ORDER EXPIRED!", Look.PINK, 0.5, 100)
		"safe":
			var yeet: String = "YEET! HAZMAT GOT IT" if e.get("out", false) else {"bomb": "DEFUSED!", "nuke": "CONTAINED!", "battery": "SAFE!"}[e.k]
			_queue_slam(yeet, Look.MINT, 0.4, 100)
		"door_open":
			_queue_slam("DOOR OPEN!", Look.SKY, 0.4, 90)
			say("door_open")
		"contract":
			_queue_slam("FINAL CONTRACT!", Look.YELLOW, 0.9, 130)
			Juice.flash(self, Color(Look.YELLOW, 0.3), 0.5)
			say("contract")
		"jam":
			_queue_slam("JAMMED!", Look.ORANGE, 0.6, 110)
			say("jam")
		"repaired":
			_queue_slam("FIXED!", Look.MINT, 0.4, 90)
		"rush":
			_queue_slam("RUSH HOUR!", Look.PINK, 0.9, 130)
			Juice.flash(self, Color(Look.PINK, 0.3), 0.5)
			Juice.speed_lines(2.0)
			say("rush")
		"drop_alert":
			Juice.flash(self, Color(Look.ORANGE, 0.18), 0.3)
			say("drop_" + str(e.k))
		"boom":
			_queue_slam("BOOM!", Look.ORANGE, 0.5, 140)
			Juice.flash(self, Color(Look.ORANGE, 0.45), 0.4)
		"leak":
			_queue_slam("RADIATION LEAK!" if e.get("k") == "nuke" else "BATTERY LEAK!", Color("3DFF5A"), 0.6, 110)
		"chaos":
			_queue_slam("CHAOS STATE!", Look.PINK, 0.9, 140)
			Juice.flash(self, Color(Look.PINK, 0.4), 0.6)
			say("chaos_" + str(e.m))
		"chaos_end":
			_queue_slam("FACTORY RECOVERED", Look.MINT, 0.6, 100)
		"robot_down":
			_queue_slam("ROBOT DOWN!", Look.MINT, 0.5, 110)
		"rescued":
			_queue_slam({"elephant": "ELEPHANT RESCUED!", "raccoon": "RACCOON CAUGHT!", "chicken": "CHICKEN CAUGHT!", "pig": "PIG CAUGHT!"}.get(e.k, "CAUGHT!"), Look.MINT, 0.6, 110)
		"eat":
			_queue_slam("CHOMP!", Look.ORANGE, 0.3, 90)
		"shark_alert":
			_queue_slam("SHARK!", Look.SKY, 0.5, 120)
			say("drop_shark")
		"shark":
			if e.has("pts"):
				_queue_slam("LOST TO THE SEA!", Look.PINK, 0.4, 90)
		"steal":
			_queue_slam("THIEF!", Look.ORANGE, 0.4, 100)
		"raccoon_gone":
			_queue_slam("IT GOT AWAY", Look.PINK, 0.4, 90)
		"final":
			_queue_slam("10 SECONDS!", Look.PINK, 0.8, 130)
			Juice.flash(self, Color(Look.PINK, 0.35), 0.6)
		"catch":
			_queue_slam("NICE CATCH!", Look.MINT, 0.3, 80)


## FRU-01 says a fact once per shift (always for fires).
func say(key: String) -> void:
	if _told.has(key):
		return
	_told[key] = true
	_bubble_text.text = FACTS.get(key, key)
	_bubble.visible = true
	_bubble.modulate.a = 1.0
	Juice.squash(_bubble)
	if _bubble_tween != null:
		_bubble_tween.kill()  # a newer message gets its full time on screen
	_bubble_tween = _bubble.create_tween()
	_bubble_tween.tween_interval(2.6)  # brief: the bubble sits over the bottom of the rail
	_bubble_tween.tween_property(_bubble, "modulate:a", 0.0, 0.25)
	_bubble_tween.tween_callback(func() -> void: _bubble.visible = false)


func slam(text: String, color: Color) -> void:
	_queue_slam(text, color, 0.5, 150)


func _queue_slam(text: String, color: Color, hold: float, size: int) -> void:
	if _slams.size() < 2:  # never let announcements pile up behind the action
		_slams.append([text, color, hold * 0.5, roundi(size * 0.8)])  # short and smaller: they sit over the rail


## Three stars dropping in one after the other, each with a rising ding.
func _result_stars(earned: int) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	for i in 3:
		var star := TextureRect.new()
		star.texture = Look.emoji("star")
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.custom_minimum_size = Vector2(96, 96)
		star.pivot_offset = Vector2(48, 48)
		star.scale = Vector2.ZERO
		row.add_child(star)
		var got := i < earned
		star.modulate = Color.WHITE if got else Color(0.25, 0.25, 0.32, 0.9)
		var tw := star.create_tween()
		tw.tween_interval(0.4 + i * 0.5)
		tw.tween_property(star, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		if got:
			tw.parallel().tween_callback(func() -> void: Sfx.play("gem_gather", 1.0 + i * 0.15))
	return row


func show_results(shift: Shift) -> void:
	var stars := Rules.stars(shift.coins)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", Look.chunky(Look.HUD_DARK, 24))
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -330
	card.offset_right = 330
	card.offset_top = -270
	card.offset_bottom = 270
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)
	box.add_child(Look.label("SHIFT OVER", 64, Look.YELLOW, true))
	box.add_child(_result_stars(stars))
	box.add_child(Look.label("%d coins" % shift.coins, 44, Look.WHITE, true))
	var stats_line := "Orders %d · Wrong inputs %d · Explosions %d · Expired %d" % [shift.stats.orders, shift.stats.wrong, shift.stats.booms, shift.stats.late]
	box.add_child(Look.label(stats_line, 22, Look.SKY))
	box.add_child(Look.label("Quests done %d  ·  Best combo %d (x%s)" % [shift.quests.done_count(), shift.best_combo, str(Rules.combo_mult(shift.best_combo)).trim_suffix(".0")], 24, Look.MINT, true))
	box.add_child(_board.build(Match.players, Match.my_id))
	Records.add(_board.summary(Match.players, Match.my_id).merged(
		{"t": int(Time.get_unix_time_from_system()), "map": Rules.map, "coins": shift.coins, "stars": stars}))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	var again := Button.new()
	again.text = "AGAIN"
	Look.style_button(again, Look.PRIMARY)
	again.pressed.connect(again_pressed.emit)
	row.add_child(again)
	var menu := Button.new()
	menu.text = "MENU"
	Look.style_button(menu, Look.HUD_DARK)
	menu.pressed.connect(menu_pressed.emit)
	row.add_child(menu)
	Juice.squash(card)
	if stars > 0:
		Sfx.music("result_win")
		for i in stars:
			Juice.burst(self, size / 2.0 + Vector2((i - 1) * 140, -150), Look.YELLOW, 30)
	else:
		Sfx.music("result_lose")


func _sync_tickets(orders: Array, rush_mult: int) -> void:
	var live := {}
	for o in orders:
		live[o.id] = true
	for id in _tickets_by_id.keys():
		if not live.has(id):
			_retire_ticket(_tickets_by_id[id])
			_tickets_by_id.erase(id)
	for i in orders.size():
		var o: Dictionary = orders[i]
		var t: PanelContainer = _tickets_by_id.get(o.id)
		if t == null:
			t = _ticket(o.m, o.final)
			_tickets_by_id[o.id] = t
			_tickets.add_child(t)
			t.scale = Vector2.ONE * 0.3
			t.create_tween().tween_property(t, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			Sfx.play("ui_pluck")
		_tickets.move_child(t, i)
		var frac := clampf(o.left / o.total, 0.0, 1.0)
		t.get_node("V/Top/Pay").text = "+%d" % (Rules.order_coins(o.need, o.left, o.total) * rush_mult * (Rules.FINAL_MULTIPLIER if o.final else 1))
		t.get_node("V/Name").text = "%d/%d" % [o.got, o.need]
		var bar: ColorRect = t.get_node("V/Bar")
		bar.custom_minimum_size.x = 100.0 * frac
		bar.color = bar.color.lerp(Look.MINT if frac > 0.5 else (Look.YELLOW if frac > 0.25 else Look.PINK), 0.2)
		# Leaving soon: the card shakes and flashes so nobody misses it.
		var urgent: bool = frac < 0.25
		t.rotation = sin(Time.get_ticks_msec() / 45.0) * 0.06 if urgent else 0.0
		t.pivot_offset = t.size / 2.0
		t.modulate = Color(1, 0.6, 0.6) if urgent and int(Time.get_ticks_msec() / 250) % 2 == 0 else Color.WHITE


## Coins fly from where they were earned (screen position) into the counter.
func fly_coins(from: Vector2, count: int) -> void:
	for i in mini(count, 8):
		var c := TextureRect.new()
		c.texture = Look.emoji("coin")
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.size = Vector2(44, 44)
		c.position = from + Vector2(randf_range(-30, 30), randf_range(-30, 30))
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		var t := c.create_tween()
		t.tween_interval(i * 0.05)
		t.tween_property(c, "position", Vector2(40, 20), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(func() -> void:
			Juice.squash(_coins)
			Sfx.play("coin", randf_range(1.0, 1.3), -8.0))
		t.tween_callback(c.queue_free)


func _build_star_bar() -> void:
	const BAR := Vector2(296, 22)  ## as wide as the quest cards under it
	_stars = ProgressBar.new()
	_stars.max_value = Rules.STARS[-1]
	_stars.show_percentage = false
	_stars.position = Vector2(14, 104)
	_stars.size = BAR
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := Look.pill(Color(0, 0, 0, 0.55), 11)
	bg.content_margin_top = 0
	bg.content_margin_bottom = 0
	bg.shadow_size = 0
	bg.set_border_width_all(3)
	bg.border_color = Color(1, 1, 1, 0.9)
	var fill := Look.pill(Look.YELLOW, 11)
	fill.shadow_size = 0
	_stars.add_theme_stylebox_override("background", bg)
	_stars.add_theme_stylebox_override("fill", fill)
	add_child(_stars)
	for threshold in Rules.STARS:
		var x: float = 14.0 + BAR.x * threshold / Rules.STARS[-1]
		var star := TextureRect.new()
		star.texture = Look.emoji("star")
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.size = Vector2(42, 42)
		star.pivot_offset = star.size / 2.0
		star.position = Vector2(x - 21, 115 - 21)
		star.modulate = Color(0.25, 0.25, 0.32, 0.9)  # unearned
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(star)
		_star_icons.append(star)
		var goal := Look.label(str(threshold), 16, Look.WHITE)
		goal.position = Vector2(x - 24, 136)
		goal.size = Vector2(48, 22)
		add_child(goal)


func _light_star(i: int) -> void:
	_star_got[i] = true
	var star := _star_icons[i]
	star.modulate = Color.WHITE
	star.scale = Vector2.ZERO
	star.rotation = -0.35
	var tw := star.create_tween().set_parallel()
	tw.tween_property(star, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(star, "rotation", 0.0, 0.5)
	Juice.burst(self, star.global_position + star.size / 2.0, Look.YELLOW, 20)
	Sfx.play("gem_gather", 1.0 + i * 0.15)
	_queue_slam("%d STAR%s!" % [i + 1, "S" if i > 0 else ""], Look.YELLOW, 0.5, 110)
	Juice.haptic(40)


## Who did what, for the blame callouts and the results awards.
func _track(e: Dictionary) -> void:
	if e.e in ["ship", "late"]:
		_last_result = e.e
	_board.track(e)
	var who: int = e.get("who", -1)
	if who >= 0 and e.e in MISTAKES:
		_blame_callout(who, str(MISTAKES[e.e]))


## Light and playful, one every 2 s at most: the partner is named, you get an OOPS.
func _blame_callout(who: int, what: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _blame_at < 2.0:
		return
	_blame_at = now
	var name_text := "OOPS!" if who == Match.my_id else "%s oopsie!" % str(Match.players.get(who, {}).get("name", "Partner")).to_upper()
	_blame.text = "%s  %s" % [name_text, what]
	_blame.add_theme_color_override("font_color", Look.ORANGE if who == Match.host_id else Look.SKY)
	_blame.modulate.a = 1.0
	_blame.position.y = 126.0
	var tw := _blame.create_tween().set_parallel()
	tw.tween_property(_blame, "position:y", 96.0, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_blame, "modulate:a", 0.0, 0.5).set_delay(1.0)


## POLLUTION: a factory gauge of 8 segments, green to red, under its icon (the refs' top-left bars).
func _build_meter() -> void:
	var gauge := _panel(Look.HUD_DARK, Vector2(222, 12), Vector2(214, 80))
	_icon(gauge, "factory", Vector2(10, 12), 46, Look.WHITE)
	var tag := Look.label("POLLUTION", 16, Look.WHITE)
	tag.position = Vector2(62, 4)
	tag.size = Vector2(140, 24)
	gauge.add_child(tag)
	for i in 8:
		var seg := Panel.new()
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(5)
		style.set_border_width_all(2)
		style.border_color = Color(0, 0, 0, 0.45)
		seg.add_theme_stylebox_override("panel", style)
		seg.position = Vector2(64 + i * 17.5, 32)
		seg.size = Vector2(15, 34)
		seg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gauge.add_child(seg)
		var shine := ColorRect.new()  # a glossy strip on each segment
		shine.color = Color(1, 1, 1, 0.3)
		shine.position = Vector2(3, 3)
		shine.size = Vector2(9, 8)
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		seg.add_child(shine)
		_meter.append(style)
	_chaos_label = _banner("", Color("8A2BE2"), 196)


func _build_menu() -> void:
	_blame = Look.label("", 34, Look.ORANGE, true)
	_blame.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_blame.offset_left = -300
	_blame.offset_right = 300
	_blame.modulate.a = 0.0
	_blame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blame)
	var open := Button.new()
	open.text = "II"
	open.add_theme_font_size_override("font_size", 26)
	open.set_anchors_preset(Control.PRESET_CENTER_TOP)
	open.offset_left = -190
	open.offset_right = -114
	open.offset_top = 18
	open.offset_bottom = 82
	open.pressed.connect(func() -> void: _toggle_menu(true))
	add_child(open)
	_menu = ColorRect.new()
	_menu.color = Color(0, 0, 0, 0.6)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	add_child(_menu)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Look.chunky(Look.HUD_DARK, 24))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_menu.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(Look.label("MENU", 52, Look.YELLOW, true))
	box.add_child(_menu_button("RESUME", Look.PRIMARY, func(_b: Button) -> void: _toggle_menu(false)))
	for opt in [["music", "MUSIC"], ["sound", "SOUND"], ["haptics", "VIBRATION"]]:
		box.add_child(_menu_button("%s: %s" % [opt[1], "ON" if Profile.option(opt[0]) else "OFF"], Look.HUD_DARK.lightened(0.1), func(b: Button) -> void:
			var on := not Profile.option(opt[0])
			Profile.set_option(opt[0], on)
			b.text = "%s: %s" % [opt[1], "ON" if on else "OFF"]))
	box.add_child(_menu_button("LEAVE MATCH", Look.DANGER, func(_b: Button) -> void: menu_pressed.emit()))


func _menu_button(text: String, color: Color, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 32)
	b.custom_minimum_size = Vector2(380, 70)
	Look.style_button(b, color)
	b.pressed.connect(func() -> void:
		Sfx.play("ui_click")
		on_press.call(b))
	return b


func _toggle_menu(open: bool) -> void:
	_menu.visible = open
	if open:
		var panel: Control = _menu.get_child(0)
		panel.pivot_offset = panel.size / 2.0
		panel.scale = Vector2.ONE * 0.85
		panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## An order card: a dark bin with the material's colour on top, its glyph, the count and a timer bar.
func _ticket(material: String, final: bool) -> PanelContainer:
	var t := PanelContainer.new()
	var style := Look.chunky(Color("8A6A1E") if final else Look.HUD_DARK, 14)  # the final contract is gold
	style.border_width_top = 14
	style.border_color = MATERIAL_COLORS.get(material, Color.WHITE)
	t.add_theme_stylebox_override("panel", style)
	t.custom_minimum_size = Vector2(124, 116)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.name = "V"
	v.add_theme_constant_override("separation", 0)
	t.add_child(v)
	var top := HBoxContainer.new()
	top.name = "Top"
	v.add_child(top)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(40, 40)
	icon.modulate = MATERIAL_COLORS.get(material, Color.WHITE)
	icon.texture = Look.glyph(StationArt.MATERIAL_GLYPHS.get(material, "recycle"))
	top.add_child(icon)
	var pay := Look.label("", 20, Look.YELLOW, true)
	pay.name = "Pay"
	pay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(pay)
	var name_label := Look.label("", 30, Look.WHITE, true)
	name_label.name = "Name"
	v.add_child(name_label)
	var bar := ColorRect.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(100, 8)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.color = Look.MINT
	v.add_child(bar)
	return t


## A finished ticket leaves its row and flies to the score (shipped) or drops away red (expired).
func _retire_ticket(t: PanelContainer) -> void:
	var from := t.global_position
	_tickets.remove_child(t)
	add_child(t)
	t.global_position = from
	t.rotation = 0.0
	await get_tree().process_frame  # let this frame's ship/late cue say how it ended
	await get_tree().process_frame
	t.pivot_offset = t.size / 2.0
	var tw := t.create_tween().set_parallel()
	if _last_result == "ship":
		t.modulate = Color(0.7, 1.0, 0.75)
		tw.tween_property(t, "scale", Vector2.ONE * 1.2, 0.12)
		tw.chain().tween_property(t, "global_position", Vector2(60, 40), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(t, "scale", Vector2.ONE * 0.2, 0.4)
	else:
		t.modulate = Color(1.0, 0.45, 0.5)
		tw.tween_property(t, "global_position:y", from.y + 120.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(t, "rotation", 0.4, 0.4)
		tw.tween_property(t, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(t.queue_free)


func _build_bubble() -> void:
	_bubble = PanelContainer.new()
	var style := Look.chunky(Color(Look.HUD_DARK, 0.82), 18)
	style.set_content_margin_all(8)
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_bubble.offset_left = -330
	_bubble.offset_right = 290
	_bubble.offset_top = -100
	_bubble.offset_bottom = -12
	_bubble.visible = false
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bubble)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_bubble.add_child(row)
	var face := TextureRect.new()
	face.texture = Look.glyph("factory")
	face.modulate = Look.YELLOW
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.custom_minimum_size = Vector2(56, 56)
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(face)
	_bubble_text = Look.label("", 21, Look.WHITE)
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_bubble_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_bubble_text)


func _label_at(text: String, size: int, color: Color, pos: Vector2, box: Vector2, align: HorizontalAlignment) -> Label:
	var l := Look.label(text, size, color, true)
	l.position = pos
	l.size = box
	l.horizontal_alignment = align
	add_child(l)
	return l
