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
