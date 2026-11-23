class_name Tones
extends RefCounted
## Short sounds made in code. The game has no recorded sound in plan 0001.

const MIX_RATE := 22050


## Makes a sound from tones. Each tone is [frequency, seconds, wave, volume, delay].
## "wave" is "sine", "triangle", or "square".
static func make(tones: Array) -> AudioStreamWAV:
	var length := 0.0
	for tone: Array in tones:
		length = maxf(length, tone[4] + tone[1])
	var count := int(ceil((length + 0.02) * MIX_RATE))
	var samples := PackedFloat32Array()
	samples.resize(count)
	for tone: Array in tones:
		var freq: float = tone[0]
		var duration: float = tone[1]
		var wave: String = tone[2]
		var volume: float = tone[3]
		var start := int(tone[4] * MIX_RATE)
		var n := int(duration * MIX_RATE)
		for i in n:
			var t := float(i) / MIX_RATE
			var phase := fmod(t * freq, 1.0)
			var value := 0.0
			match wave:
				"triangle":
					value = 4.0 * absf(phase - 0.5) - 1.0
				"square":
					value = 1.0 if phase < 0.5 else -1.0
				_:
					value = sin(TAU * phase)
			# A fast decay, like a bell or a wood stick.
			var envelope := exp(-6.0 * t / duration)
			if start + i < count:
				samples[start + i] += value * volume * envelope
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


## The sound for a new notebook card.
static func ting() -> AudioStreamWAV:
	return make([[1046.0, 0.35, "sine", 0.35, 0.0], [1568.0, 0.5, "sine", 0.25, 0.09]])


## The clack of the bamboo sticks of the hủ tiếu gõ helper ("lóc cóc").
static func clack() -> AudioStreamWAV:
	return make([[980.0, 0.07, "triangle", 0.6, 0.0], [1960.0, 0.04, "square", 0.1, 0.0],
			[980.0, 0.07, "triangle", 0.6, 0.22], [1960.0, 0.04, "square", 0.1, 0.22]])


## The murmur of a TV upstairs (plan 0003, R2): voices and music through a
## wall. It loops. "seconds" is the length of one loop.
static func tv(seconds := 4.0) -> AudioStreamWAV:
	var count := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var low := 0.0
	var band := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		# Noise through two low-pass filters: a voice behind a wall.
		low += (rng.randf_range(-1.0, 1.0) - low) * 0.08
		band += (low - band) * 0.25
		# Syllables: the level goes up and down about 4 times each second.
		var syllables := 0.5 + 0.5 * sin(TAU * 4.1 * t + 2.0 * sin(TAU * 0.7 * t))
		var music := 0.25 * sin(TAU * 196.0 * t) * (0.5 + 0.5 * sin(TAU * 0.5 * t))
		samples[i] = band * 3.0 * syllables + music * 0.15
	# Fade the ends of the loop, so that it has no click.
	var fade := int(0.05 * MIX_RATE)
	for i in fade:
		samples[i] *= float(i) / fade
		samples[count - 1 - i] *= float(i) / fade
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] * 0.5, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream


## The sound of the machines at the roadworks (plan 0005, R11a): a diesel
## engine that goes up and down, with the clank of the excavator bucket.
static func machine(seconds := 6.0) -> AudioStreamWAV:
	var count := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var rumble := 0.0
	var phase := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		# The engine: about 30 firings each second, faster when the arm moves.
		var load := 0.5 + 0.5 * sin(TAU * t / seconds * 2.0)
		phase = fmod(phase + (28.0 + 10.0 * load) / MIX_RATE, 1.0)
		var firing := exp(-8.0 * phase) - 0.2
		rumble += (rng.randf_range(-1.0, 1.0) - rumble) * 0.05
		samples[i] = firing * 0.5 + rumble * 1.2 * (0.6 + 0.4 * load)
	# The bucket hits stones two times in the loop.
	for hit: float in [1.3, 4.1]:
		var start := int(hit * MIX_RATE)
		for i in int(0.25 * MIX_RATE):
			if start + i < count:
				var t := float(i) / MIX_RATE
				samples[start + i] += 0.5 * sin(TAU * 410.0 * t) * exp(-18.0 * t) + 0.3 * rng.randf_range(-1.0, 1.0) * exp(-30.0 * t)
	var fade := int(0.05 * MIX_RATE)
	for i in fade:
		samples[i] *= float(i) / fade
		samples[count - 1 - i] *= float(i) / fade
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		data.encode_s16(i * 2, int(clampf(samples[i] * 0.5, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	return stream


## Plan 0018, R7: the engine of a small scooter at idle, a loop of one second.
## A single cylinder of four strokes fires 25 times each second at idle; the
## exhaust is a pulse at each firing, with the rattle of the belt (noise).
## The game changes the pitch of the loop with the speed. Made in code: no
## recording with a CC0 or CC BY licence was reachable in the workspace.
static func scooter_engine() -> AudioStreamWAV:
	var count := MIX_RATE
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	var rattle := 0.0
	var body := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		# 25 firings in the loop: a whole number, so that the loop has no click.
		var phase := fmod(t * 25.0, 1.0)
		var pulse := exp(-9.0 * phase) * (1.0 + 0.15 * sin(TAU * 3.0 * t))
		rattle += (rng.randf_range(-1.0, 1.0) - rattle) * 0.3
		body += (pulse - body) * 0.2
		samples[i] = body * 1.4 + 0.35 * sin(TAU * 50.0 * t) * pulse + rattle * 0.12 - 0.3
	return _loop(samples)


## Plan 0018, R7: the start of the engine: the starter, then the first firings.
static func scooter_start() -> AudioStreamWAV:
	var seconds := 1.1
	var count := int(seconds * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 19
	var phase := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		var value := 0.0
		if t < 0.45:
			# The starter motor: a whine that goes up.
			value = 0.25 * sin(TAU * (160.0 + 120.0 * t) * t) + 0.08 * rng.randf_range(-1.0, 1.0)
		else:
			# The engine catches: the firings get faster to the idle.
			phase = fmod(phase + lerpf(12.0, 25.0, clampf((t - 0.45) / 0.4, 0.0, 1.0)) / MIX_RATE, 1.0)
			value = 0.9 * exp(-9.0 * phase) - 0.25 + 0.1 * rng.randf_range(-1.0, 1.0)
		samples[i] = value * minf(1.0, (seconds - t) / 0.1)
	return _sound(samples)


## Plan 0018, R7: the bump of a scooter into a wall: a low thud and a click.
static func scooter_bump() -> AudioStreamWAV:
	var count := int(0.35 * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	for i in count:
		var t := float(i) / MIX_RATE
		samples[i] = 0.9 * sin(TAU * 75.0 * t) * exp(-14.0 * t) + 0.4 * rng.randf_range(-1.0, 1.0) * exp(-60.0 * t)
	return _sound(samples)


static func _sound(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i] * 0.6, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	return stream


static func _loop(samples: PackedFloat32Array) -> AudioStreamWAV:
	var stream := _sound(samples)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = samples.size()
	return stream
