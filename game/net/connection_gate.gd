extends CanvasLayer
## Autoload "Gate": TRASH PANIC! only runs online. While the server can't be reached it pauses the
## game behind this screen, and resumes the moment the connection is back (Wi-Fi in debug builds,
## mobile data in release builds).

@onready var _title: Label = $Panel/Box/Title
@onready var _reason: Label = $Panel/Box/Reason
@onready var _badge: Label = $Panel/Box/Badge
@onready var _retry: Button = $Panel/Box/Retry

var _was_online_once := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # must keep running while the tree is paused
	_retry.pressed.connect(Net.retry_now)
	Net.online_changed.connect(_on_online_changed)
	Net.status_changed.connect(_refresh)
	_on_online_changed(Net.online)


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _on_online_changed(online: bool) -> void:
	_was_online_once = _was_online_once or online
	get_tree().paused = not online
	visible = not online
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	var b := Net.badge()
	_title.text = "SIGNAL LOST" if _was_online_once else "CONNECTING"
	_reason.text = Net.gate_message_for(Net.net_type, _was_online_once, Net.offline_s)
	_badge.text = b.text
	_badge.add_theme_color_override("font_color", b.color)
