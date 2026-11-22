class_name Clock
extends RefCounted
## Match time shared by every phone. Online, `offset_ms` maps local ticks to server time, so time-driven
## obstacles (cranes, pistons, saws) sit in the same place on every screen.

static var offset_ms := 0


static func now_ms() -> int:
	return Time.get_ticks_msec() + offset_ms


static func now() -> float:
	return now_ms() / 1000.0
