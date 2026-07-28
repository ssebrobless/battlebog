extends SceneTree

const MAE_THRESHOLD := 0.010
const ROI_SSIM_THRESHOLD := 0.985
const CHANGED_PIXEL_DELTA := 0.08
const CHANGED_PIXEL_RATIO_THRESHOLD := 0.01
const SSIM_WINDOW_RADIUS := 5
const SSIM_SIGMA := 1.5
const SSIM_C1 := 0.0001
const SSIM_C2 := 0.0009


func _init() -> void:
	var arguments := _arguments()
	if arguments.has("self-test"):
		_run_self_test()
		return
	var baseline_path := String(arguments.get("baseline", ""))
	var current_path := String(arguments.get("current", ""))
	var output_path := String(arguments.get("output", ""))
	if baseline_path.is_empty() or current_path.is_empty() or output_path.is_empty():
		_fail("--baseline, --current and --output are required.")
		return
	var baseline := _load_png(baseline_path)
	var current := _load_png(current_path)
	if baseline == null or current == null:
		return
	if baseline.get_size() != current.get_size():
		_fail("Images must have identical dimensions.")
		return
	var roi_result := _parse_roi(
		String(arguments.get("roi", "")),
		Rect2i(Vector2i.ZERO, baseline.get_size())
	)
	if not bool(roi_result.get("ok", false)):
		_fail(String(roi_result.get("error", "Invalid ROI.")))
		return
	var metrics := compare_images(baseline, current, roi_result["roi"])
	metrics["schema_version"] = 1
	metrics["baseline_path"] = baseline_path
	metrics["current_path"] = current_path
	if not _write_json(output_path, metrics):
		return
	print("BB_IMAGE_METRICS_OK output=%s" % output_path)
	quit(0)


static func compare_images(
	baseline: Image,
	current: Image,
	roi: Rect2i
) -> Dictionary:
	var width := baseline.get_width()
	var height := baseline.get_height()
	var absolute_sum := 0.0
	var changed_pixels := 0
	for y in height:
		for x in width:
			var first := baseline.get_pixel(x, y)
			var second := current.get_pixel(x, y)
			var red_delta := absf(first.r - second.r)
			var green_delta := absf(first.g - second.g)
			var blue_delta := absf(first.b - second.b)
			absolute_sum += red_delta + green_delta + blue_delta
			if maxf(red_delta, maxf(green_delta, blue_delta)) > CHANGED_PIXEL_DELTA:
				changed_pixels += 1
	var pixel_count := width * height
	var mae := absolute_sum / float(maxi(pixel_count * 3, 1))
	var changed_ratio := float(changed_pixels) / float(maxi(pixel_count, 1))
	var roi_ssim := _roi_ssim(baseline, current, roi)
	return {
		"width": width,
		"height": height,
		"roi": {
			"x": roi.position.x,
			"y": roi.position.y,
			"width": roi.size.x,
			"height": roi.size.y,
		},
		"mae": mae,
		"roi_ssim": roi_ssim,
		"changed_pixel_delta": CHANGED_PIXEL_DELTA,
		"changed_pixel_count": changed_pixels,
		"changed_pixel_ratio": changed_ratio,
		"thresholds": {
			"mae_max": MAE_THRESHOLD,
			"roi_ssim_min": ROI_SSIM_THRESHOLD,
			"changed_pixel_ratio_max": CHANGED_PIXEL_RATIO_THRESHOLD,
		},
		"passes": {
			"mae": mae <= MAE_THRESHOLD,
			"roi_ssim": roi_ssim >= ROI_SSIM_THRESHOLD,
			"changed_pixels": changed_ratio <= CHANGED_PIXEL_RATIO_THRESHOLD,
		},
		"passed": mae <= MAE_THRESHOLD \
			and roi_ssim >= ROI_SSIM_THRESHOLD \
			and changed_ratio <= CHANGED_PIXEL_RATIO_THRESHOLD,
	}


static func _roi_ssim(baseline: Image, current: Image, roi: Rect2i) -> float:
	var weights: Array[float] = []
	var weight_sum := 0.0
	for offset in range(-SSIM_WINDOW_RADIUS, SSIM_WINDOW_RADIUS + 1):
		var weight := exp(
			-float(offset * offset) / (2.0 * SSIM_SIGMA * SSIM_SIGMA)
		)
		weights.append(weight)
		weight_sum += weight
	for index in weights.size():
		weights[index] /= weight_sum

	var ssim_sum := 0.0
	var sample_count := 0
	for y in range(roi.position.y, roi.end.y):
		for x in range(roi.position.x, roi.end.x):
			var mean_first := 0.0
			var mean_second := 0.0
			var square_first := 0.0
			var square_second := 0.0
			var cross := 0.0
			for offset_y in range(-SSIM_WINDOW_RADIUS, SSIM_WINDOW_RADIUS + 1):
				var sample_y := _reflected_index(y + offset_y, baseline.get_height())
				var weight_y := weights[offset_y + SSIM_WINDOW_RADIUS]
				for offset_x in range(-SSIM_WINDOW_RADIUS, SSIM_WINDOW_RADIUS + 1):
					var sample_x := _reflected_index(x + offset_x, baseline.get_width())
					var weight := weight_y * weights[offset_x + SSIM_WINDOW_RADIUS]
					var first_luma := _luminance(baseline.get_pixel(sample_x, sample_y))
					var second_luma := _luminance(current.get_pixel(sample_x, sample_y))
					mean_first += weight * first_luma
					mean_second += weight * second_luma
					square_first += weight * first_luma * first_luma
					square_second += weight * second_luma * second_luma
					cross += weight * first_luma * second_luma
			var variance_first := maxf(square_first - mean_first * mean_first, 0.0)
			var variance_second := maxf(square_second - mean_second * mean_second, 0.0)
			var covariance := cross - mean_first * mean_second
			var numerator := (2.0 * mean_first * mean_second + SSIM_C1) \
				* (2.0 * covariance + SSIM_C2)
			var denominator := (
				mean_first * mean_first + mean_second * mean_second + SSIM_C1
			) * (variance_first + variance_second + SSIM_C2)
			ssim_sum += numerator / denominator if denominator > 0.0 else 1.0
			sample_count += 1
	return ssim_sum / float(maxi(sample_count, 1))


static func _luminance(color: Color) -> float:
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722


static func _reflected_index(index: int, size: int) -> int:
	if size <= 1:
		return 0
	var output := index
	while output < 0 or output >= size:
		if output < 0:
			output = -output - 1
		elif output >= size:
			output = size * 2 - output - 1
	return output


func _arguments() -> Dictionary:
	var parsed := {}
	for argument in OS.get_cmdline_user_args():
		if argument == "--self-test":
			parsed["self-test"] = true
		elif argument.begins_with("--") and "=" in argument:
			var separator := argument.find("=")
			parsed[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return parsed


func _load_png(path: String) -> Image:
	var image := Image.new()
	var error := image.load(path)
	if error != OK or image.is_empty():
		_fail("PNG could not be loaded: %s" % path)
		return null
	if image.get_format() != Image.FORMAT_RGB8 and image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _parse_roi(text: String, bounds: Rect2i) -> Dictionary:
	if text.is_empty():
		return {"ok": false, "error": "ROI is required; full-frame fallback is forbidden."}
	var parts := text.split(",")
	if parts.size() != 4:
		return {"ok": false, "error": "ROI must be x,y,width,height."}
	for part in parts:
		if not String(part).strip_edges().is_valid_int():
			return {"ok": false, "error": "ROI values must be integers."}
	var requested := Rect2i(
		int(parts[0]),
		int(parts[1]),
		int(parts[2]),
		int(parts[3])
	)
	if requested.size.x <= 0 or requested.size.y <= 0 or not requested.has_area():
		return {"ok": false, "error": "ROI must have positive area."}
	if requested.position.x < bounds.position.x \
		or requested.position.y < bounds.position.y \
		or requested.end.x > bounds.end.x \
		or requested.end.y > bounds.end.y:
		return {"ok": false, "error": "ROI must be fully inside the image."}
	return {"ok": true, "roi": requested}


func _write_json(path: String, value: Dictionary) -> bool:
	var parent := path.get_base_dir()
	if not parent.is_empty():
		var make_error := DirAccess.make_dir_recursive_absolute(parent)
		if make_error != OK:
			_fail("Could not create metric output directory: %s" % parent)
			return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Could not write metric output: %s" % path)
		return false
	file.store_string(JSON.stringify(value, "\t", true, true))
	file.close()
	return true


func _run_self_test() -> void:
	var baseline := Image.create(64, 64, false, Image.FORMAT_RGB8)
	baseline.fill(Color(0.4, 0.4, 0.4))
	var identical := baseline.duplicate()
	var mae_failure := baseline.duplicate()
	mae_failure.fill(Color(0.42, 0.42, 0.42))
	var changed_failure := baseline.duplicate()
	for index in 42:
		changed_failure.set_pixel(
			index % 64,
			index / 64,
			Color(0.5, 0.4, 0.4)
		)
	var ssim_failure := baseline.duplicate()
	for y in range(24, 40):
		for x in range(24, 40):
			var value := 0.33 if (x + y) % 2 == 0 else 0.47
			ssim_failure.set_pixel(x, y, Color(value, value, value))
	var full := Rect2i(0, 0, 64, 64)
	var ssim_roi := Rect2i(24, 24, 16, 16)
	var exact := compare_images(baseline, identical, full)
	var mae := compare_images(baseline, mae_failure, full)
	var changed := compare_images(baseline, changed_failure, full)
	var ssim := compare_images(baseline, ssim_failure, ssim_roi)
	if not bool(exact["passed"]) \
		or bool(mae["passes"]["mae"]) \
		or not bool(mae["passes"]["roi_ssim"]) \
		or not bool(mae["passes"]["changed_pixels"]) \
		or not bool(changed["passes"]["mae"]) \
		or not bool(changed["passes"]["roi_ssim"]) \
		or bool(changed["passes"]["changed_pixels"]) \
		or not bool(ssim["passes"]["mae"]) \
		or bool(ssim["passes"]["roi_ssim"]) \
		or not bool(ssim["passes"]["changed_pixels"]) \
		or _reflected_index(-1, 4) != 0 \
		or _reflected_index(-2, 4) != 1 \
		or _reflected_index(4, 4) != 3 \
		or _reflected_index(5, 4) != 2:
		_fail("Image metric self-test did not separate pass/failure cases.")
		return
	print("BB_IMAGE_METRICS_SELF_TEST_OK")
	quit(0)


func _fail(message: String) -> void:
	printerr("BB_IMAGE_METRICS_ERROR: %s" % message)
	quit(1)
