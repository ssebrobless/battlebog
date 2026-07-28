extends RefCounted

var seed: int = 0
var fixed_step_hz: int = 60
var frame_index: int = 0


func configure(next_seed: int, next_fixed_step_hz: int) -> void:
	seed = next_seed
	fixed_step_hz = maxi(1, next_fixed_step_hz)
	frame_index = 0


func seek(next_frame_index: int) -> void:
	frame_index = maxi(0, next_frame_index)


func advance(frame_count: int = 1) -> void:
	frame_index = maxi(0, frame_index + frame_count)


func elapsed_seconds() -> float:
	return float(frame_index) / float(fixed_step_hz)


func delta_seconds() -> float:
	return 1.0 / float(fixed_step_hz)


func stream_seed(stream_name: String) -> int:
	var mixed := seed % 2147483647
	for byte_value in stream_name.to_utf8_buffer():
		mixed = int((mixed * 1664525 + int(byte_value) + 1013904223) % 2147483647)
	return maxi(1, mixed)


func make_rng(stream_name: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = stream_seed(stream_name)
	return rng


func snapshot() -> Dictionary:
	return {
		"frame_index": frame_index,
		"fixed_step_hz": fixed_step_hz,
		"delta_seconds": delta_seconds(),
		"elapsed_seconds": elapsed_seconds(),
		"seed": seed,
	}
