extends RefCounted
# PT-15 fp_gyro. Send a yaw rate of 0.5 rad/s for 2 s. The view turns 1 rad,
# ±5%. Use "Center the view" in the Settings app (plan 0003). Turn the
# gyroscope off in the settings. Send the same rate. The view does not turn.
# phase: --start-time=06:00


func run(d: PlaytestDriver) -> void:
	await d.skip_intro()
	var yaw0: float = d.state().yaw
	await d.gyro(Vector3(0, 0.5, 0), 2.0)
	var turned := deg_to_rad(wrapf(float(d.state().yaw) - yaw0, -180.0, 180.0))
	d.expect(absf(turned - 1.0) <= 0.05, "the gyroscope turns the view 1 rad ±5%%: %.3f rad" % turned)
	await d.screenshot("gyro_turned")
	# "Center the view" puts the gyroscope reference back.
	await d.open_app("settings")
	await d.tap_phone_id("settings.center")
	await d.wait_idle()
	d.expect(absf(wrapf(float(d.state().yaw) - yaw0, -180.0, 180.0)) < 0.5, "the center button centers the view")
	# A pitch rate also turns the view up.
	await d.gyro(Vector3(0.3, 0, 0), 1.0)
	d.expect(float(d.state().pitch) > 12.0, "a pitch rate turns the view up: %.1f" % d.state().pitch)
	await d.tap_phone_id("settings.center")
	await d.wait_idle()
	# Turn the gyroscope off in the settings.
	await d.tap_phone_id("settings.gyro")
	d.expect(d.state().settings.gyro == false, "the gyroscope setting is off")
	await d.lower_phone()
	yaw0 = d.state().yaw
	await d.gyro(Vector3(0, 0.5, 0), 2.0)
	d.expect(absf(wrapf(float(d.state().yaw) - yaw0, -180.0, 180.0)) < 0.5, "with the setting off, the gyroscope does not turn the view")
	await d.screenshot("gyro_off")
