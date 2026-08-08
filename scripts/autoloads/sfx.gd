extends Node
## SFX casual farm (palette douce type Stardew / Animal Crossing).
## Musique : plus tard.

const SFX_DIR := "res://assets/audio/sfx/"
const POOL_SIZE := 14

const _CATALOG := {
	"ui_click": "ui_click",
	"ui_tab": "ui_tab",
	"ui_open": "ui_open",
	"ui_close": "ui_close",
	"ui_confirm": "ui_confirm",
	"ui_deny": "ui_deny",
	"plant": "plant",
	"soil_click": "soil_click",
	"crop_click": "crop_click",
	"grow_stage": "grow_stage",
	"crop_ready": "crop_ready",
	"harvest": "harvest",
	"coin": "coin",
	"sell": "sell",
	"buy": "buy",
	"skill_buy": "skill_buy",
	"level_up": "level_up",
	"combo_tick": "combo_tick",
	"combo_frenzy": "combo_frenzy",
	"deliver": "deliver",
	"mission_claim": "mission_claim",
	"prestige_ready": "prestige_ready",
	"machine": "machine",
	"fertilizer": "fertilizer",
}

var enabled: bool = true
## 0..1
var volume_linear: float = 1.0

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _cooldown_until: Dictionary = {}
var _prev_combo_boost: float = 0.0
var _prev_combo_count: int = 0
var _boot_done: bool = false


func _ready() -> void:
	_ensure_bus()
	_load_streams()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer_%d" % i
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	set_volume_linear(volume_linear)
	GameState.harvested.connect(_on_harvested)
	GameState.combo_boost_changed.connect(_on_combo_changed)
	GameState.prestige_ready_changed.connect(_on_prestige_ready)
	GameState.order_delivered.connect(_on_order_delivered)
	## Ignore le 1er tick (état chargé).
	call_deferred("_mark_boot_done")


func _mark_boot_done() -> void:
	_prev_combo_boost = GameState.combo_boost_left
	_prev_combo_count = GameState.combo_count
	_boot_done = true


func _ensure_bus() -> void:
	if AudioServer.get_bus_index("SFX") >= 0:
		return
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "SFX")
	AudioServer.set_bus_send(idx, "Master")


func _load_streams() -> void:
	for id in _CATALOG:
		var path := "%s%s.wav" % [SFX_DIR, str(_CATALOG[id])]
		## Toujours lire le WAV source (évite un cache d'import Godot obsolète).
		var stream: AudioStream = _load_wav_pcm(path)
		if stream == null and ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				stream = res
		if stream != null:
			_streams[id] = stream
		else:
			push_warning("Sfx: impossible de charger %s" % path)


func _load_wav_pcm(path: String) -> AudioStreamWAV:
	## Fallback si Godot n'a pas encore importé le .wav.
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var data := f.get_buffer(f.get_length())
	f.close()
	if data.size() < 44:
		return null
	## RIFF/WAVE PCM little-endian.
	if data[0] != 0x52 or data[8] != 0x57: ## 'R'...'W'
		return null
	var channels := data[22] | (data[23] << 8)
	var rate := data[24] | (data[25] << 8) | (data[26] << 16) | (data[27] << 24)
	var bits := data[34] | (data[35] << 8)
	var pos := 12
	var pcm := PackedByteArray()
	while pos + 8 <= data.size():
		var is_data := data[pos] == 0x64 and data[pos + 1] == 0x61 and data[pos + 2] == 0x74 and data[pos + 3] == 0x61
		var chunk_size := data[pos + 4] | (data[pos + 5] << 8) | (data[pos + 6] << 16) | (data[pos + 7] << 24)
		pos += 8
		if is_data:
			pcm = data.slice(pos, mini(pos + chunk_size, data.size()))
			break
		pos += maxi(chunk_size, 0)
	if pcm.is_empty():
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS if bits == 16 else AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = rate
	stream.stereo = channels > 1
	stream.data = pcm
	return stream


func set_volume_linear(v: float) -> void:
	volume_linear = clampf(v, 0.0, 1.0)
	var bus := AudioServer.get_bus_index("SFX")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume_linear, 0.0001)) if volume_linear > 0.001 else -80.0)


func set_enabled(on: bool) -> void:
	enabled = on


func play(
	id: String,
	pitch_vary: float = 0.04,
	vol_scale: float = 1.0,
	cooldown_ms: int = 0
) -> void:
	if not enabled or volume_linear <= 0.001:
		return
	if not _streams.has(id):
		return
	if cooldown_ms > 0:
		var now := Time.get_ticks_msec()
		if now < int(_cooldown_until.get(id, 0)):
			return
		_cooldown_until[id] = now + cooldown_ms
	if _players.is_empty():
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[id] as AudioStream
	var pitch := 1.0
	if pitch_vary > 0.0:
		pitch = 1.0 + randf_range(-pitch_vary, pitch_vary)
	p.pitch_scale = clampf(pitch, 0.7, 1.35)
	p.volume_db = linear_to_db(clampf(vol_scale, 0.0001, 1.5))
	p.play()


func ui_click() -> void:
	play("ui_click", 0.05, 0.85, 25)


func ui_tab() -> void:
	play("ui_tab", 0.03, 0.9, 40)


func ui_open() -> void:
	play("ui_open", 0.02, 0.95, 80)


func ui_close() -> void:
	play("ui_close", 0.02, 0.9, 80)


func ui_confirm() -> void:
	play("ui_confirm", 0.02, 1.0, 60)


func ui_deny() -> void:
	play("ui_deny", 0.02, 0.85, 80)


func _on_harvested(_plot_index: int, _crop_id: StringName, _amount: int, via_gardener: bool = false) -> void:
	if not _boot_done:
		return
	if via_gardener:
		play("harvest", 0.06, 0.55, 90)
	else:
		play("harvest", 0.05, 0.95, 40)


func _on_combo_changed() -> void:
	if not _boot_done:
		_prev_combo_boost = GameState.combo_boost_left
		_prev_combo_count = GameState.combo_count
		return
	var boost := GameState.combo_boost_left
	var count := GameState.combo_count
	if boost > 0.0 and _prev_combo_boost <= 0.0:
		play("combo_frenzy", 0.02, 1.0, 200)
	elif count > _prev_combo_count and boost <= 0.0:
		play("combo_tick", 0.04, 0.85, 50)
	_prev_combo_boost = boost
	_prev_combo_count = count


func _on_prestige_ready(ready: bool) -> void:
	if not _boot_done:
		return
	if ready:
		play("prestige_ready", 0.02, 0.95, 400)


func _on_order_delivered(from_auto: bool) -> void:
	if not _boot_done:
		return
	play("deliver", 0.03, 0.55 if from_auto else 1.0, 150 if from_auto else 40)
