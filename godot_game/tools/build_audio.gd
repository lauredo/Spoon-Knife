extends SceneTree
## Headless SFX synthesizer — bakes simple procedural sounds (chiptune/Bfxr-style) to .wav files
## under res://assets/audio/. Matches the project's "generate assets procedurally" philosophy
## (see build_assets.gd for the SVG->PNG sibling) so there are no external sound files to manage.
##
## Run after editing any sound:
##   & "<godot 4.7>" --headless --path godot_game -s res://tools/build_audio.gd
##
## Loaded at runtime by the Audio autoload (res://assets/audio/<name>.wav).

const OUT := "res://assets/audio/"
const R := 22050  # mix rate

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	_write("click", _gen_click(), false)
	_write("attack", _gen_attack(rng), false)
	_write("hit", _gen_hit(rng), false)
	_write("hurt", _gen_hurt(rng), false)
	_write("pickup", _gen_pickup(), false)
	_write("craft", _gen_craft(), false)
	_write("boss_roar", _gen_boss(rng), false)
	_write("ambience_night", _gen_ambience(), true)
	_write("dig", _gen_dig(rng), false)  # last so it doesn't shift the RNG of the sounds above

	print("AUDIO BUILD DONE")
	quit()

func _write(name: String, samples: PackedFloat32Array, loop: bool) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	var peak := 0.0
	for i in samples.size():
		var v: float = clampf(samples[i], -1.0, 1.0)
		peak = maxf(peak, absf(v))
		data.encode_s16(i * 2, int(v * 32767.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = R
	st.stereo = false
	st.data = data
	if loop:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = samples.size()
	var err := st.save_to_wav(OUT + name + ".wav")
	print("  %s.wav  samples=%d peak=%.2f err=%d" % [name, samples.size(), peak, err])

# ── Synthesis ────────────────────────────────────────────────────────────────

func _buf(dur: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(R * dur))
	return a

## UI blip: a very short decaying square.
func _gen_click() -> PackedFloat32Array:
	var dur := 0.05
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / R
		var sq := 1.0 if sin(TAU * 900.0 * t) >= 0.0 else -1.0
		a[i] = sq * 0.22 * (1.0 - t / dur)
	return a

## Swing whoosh: low-passed noise under a bell envelope.
func _gen_attack(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 0.18
	var a := _buf(dur)
	var prev := 0.0
	for i in a.size():
		var t := float(i) / R
		var nz := rng.randf() * 2.0 - 1.0
		var lp := (nz + prev) * 0.5
		prev = lp
		a[i] = lp * sin(PI * t / dur) * 0.45
	return a

## Impact: fast-decaying noise burst plus a low thump.
func _gen_hit(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 0.13
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / R
		var env := exp(-t * 30.0)
		var thump := sin(TAU * 95.0 * t) * exp(-t * 22.0)
		var nz := (rng.randf() * 2.0 - 1.0) * env
		a[i] = clampf(nz * 0.5 + thump * 0.7, -1.0, 1.0) * 0.9
	return a

## Player hurt: a descending saw with a noise edge.
func _gen_hurt(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 0.26
	var a := _buf(dur)
	var phase := 0.0
	for i in a.size():
		var t := float(i) / R
		var f := lerpf(430.0, 150.0, t / dur)
		phase += f / R
		var saw := fmod(phase, 1.0) * 2.0 - 1.0
		var nz := (rng.randf() * 2.0 - 1.0) * 0.2
		a[i] = (saw * 0.4 + nz) * (1.0 - t / dur) * 0.7
	return a

## Loot pickup: two quick rising tones.
func _gen_pickup() -> PackedFloat32Array:
	var dur := 0.13
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / R
		var seg := 0 if t < dur * 0.5 else 1
		var f := 720.0 if seg == 0 else 1080.0
		var local := t - seg * dur * 0.5
		a[i] = sin(TAU * f * t) * exp(-local * 16.0) * 0.4
	return a

## Craft success: a 3-note ascending arpeggio (C–E–G).
func _gen_craft() -> PackedFloat32Array:
	var notes := [523.25, 659.25, 783.99]
	var note_dur := 0.12
	var a := _buf(note_dur * 3.0)
	for i in a.size():
		var t := float(i) / R
		var idx := mini(int(t / note_dur), 2)
		var f: float = notes[idx]
		var local := t - idx * note_dur
		a[i] = sin(TAU * f * t) * exp(-local * 10.0) * 0.38
	return a

## Boss roar: low dual-oscillator growl with rasp, tremolo and a long decay.
func _gen_boss(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 1.6
	var a := _buf(dur)
	var phase_saw := 0.0
	for i in a.size():
		var t := float(i) / R
		var wob := 1.0 + 0.08 * sin(TAU * 5.0 * t)
		var s := sin(TAU * 65.0 * wob * t) * 0.5 + sin(TAU * 43.0 * wob * t) * 0.5
		phase_saw += (72.0 * wob) / R
		var saw := fmod(phase_saw, 1.0) * 2.0 - 1.0
		var nz := (rng.randf() * 2.0 - 1.0) * 0.25
		var trem := 0.7 + 0.3 * sin(TAU * 8.0 * t)
		var env := minf(t / 0.08, 1.0) * exp(-t * 0.9)
		a[i] = (s * 0.55 + saw * 0.25 + nz * 0.5) * trem * env * 0.85
	return a

## Shovel dig: a dull, earthy thud — heavier low-pass + lower thump than the combat "hit".
func _gen_dig(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var dur := 0.16
	var a := _buf(dur)
	var prev := 0.0
	for i in a.size():
		var t := float(i) / R
		var env := exp(-t * 18.0)
		var nz := rng.randf() * 2.0 - 1.0
		var lp := (nz + prev * 2.0) / 3.0  # heavy low-pass → muffled, "soil" texture
		prev = lp
		var thump := sin(TAU * 70.0 * t) * exp(-t * 14.0)
		a[i] = clampf(lp * 0.55 * env + thump * 0.5, -1.0, 1.0) * 0.8
	return a

## Night ambience: an eerie low drone. All component frequencies and LFOs complete a whole number
## of cycles over the 4s buffer, so LOOP_FORWARD is seamless (no click at the wrap point).
func _gen_ambience() -> PackedFloat32Array:
	var dur := 4.0
	var a := _buf(dur)
	for i in a.size():
		var t := float(i) / R
		var lfo := 0.5 + 0.5 * sin(TAU * 0.25 * t)
		var lfo2 := 0.5 + 0.5 * sin(TAU * 0.5 * t + 1.0)
		var pad := sin(TAU * 55.0 * t) * 0.5 * lfo + sin(TAU * 110.0 * t) * 0.2 * lfo2 + sin(TAU * 146.0 * t) * 0.12
		var shimmer := sin(TAU * 1100.0 * t) * 0.03 * (0.5 + 0.5 * sin(TAU * 0.5 * t))
		a[i] = (pad + shimmer) * 0.5
	return a
