extends Node
## Autoload: AudioMan. Plays synthesized WAV SFX + music loop.
## All calls are guarded: safe before _ready, safe with audio disabled.

const SFX: Dictionary = {
	"hit": "res://assets/sfx/hit.wav",
	"bounce": "res://assets/sfx/bounce.wav",
	"wicket": "res://assets/sfx/wicket.wav",
	"crowd": "res://assets/sfx/crowd.wav",
	"click": "res://assets/sfx/click.wav",
	"win": "res://assets/sfx/win.wav",
	"loss": "res://assets/sfx/loss.wav",
	"coin": "res://assets/sfx/coin.wav",
	"unlock": "res://assets/sfx/unlock.wav",
	"six": "res://assets/sfx/six.wav",
	"four": "res://assets/sfx/four.wav",
	"ball": "res://assets/sfx/ball.wav",
}
const MUSIC_PATH: String = "res://assets/sfx/music_loop.wav"

var _players: Dictionary = {}
var _music: AudioStreamPlayer = null
var _music_enabled: bool = true
var _sfx_enabled: bool = true
var _ready_done: bool = false


func _ready() -> void:
	for key in SFX.keys():
		var p := AudioStreamPlayer.new()
		p.name = "SFX_" + str(key)
		var stream: AudioStream = load(SFX[key])
		p.stream = stream
		p.volume_db = -4.0
		p.bus = "Master"
		add_child(p)
		_players[key] = p
	_music = AudioStreamPlayer.new()
	_music.name = "MusicPlayer"
	var mstream: AudioStreamWAV = load(MUSIC_PATH)
	if mstream != null:
		var looped: AudioStreamWAV = mstream.duplicate()
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = 0
		looped.loop_end = mstream.get_length() * mstream.mix_rate
		_music.stream = looped
	_music.volume_db = -12.0
	add_child(_music)
	# Settings (autoload order guarantees SaveSystem is ready).
	if has_node("/root/SaveSystem"):
		var s: Dictionary = SaveSystem.data.get("settings", {})
		_music_enabled = bool(s.get("music", true))
		_sfx_enabled = bool(s.get("sfx", true))
	_ready_done = true
	if _music_enabled:
		start_music()


func play(sfx_name: String) -> void:
	if not _ready_done or not _sfx_enabled:
		return
	var p: AudioStreamPlayer = _players.get(sfx_name)
	if p == null:
		return
	p.play()


func set_music_enabled(on: bool) -> void:
	_music_enabled = on
	_persist_setting("music", on)
	if on:
		start_music()
	else:
		stop_music()


func set_sfx_enabled(on: bool) -> void:
	_sfx_enabled = on
	_persist_setting("sfx", on)


func _persist_setting(key: String, val: bool) -> void:
	if has_node("/root/SaveSystem"):
		SaveSystem.data["settings"][key] = val
		SaveSystem.save_game()


func start_music() -> void:
	if not _ready_done or _music == null:
		return
	if not _music_enabled:
		return
	if not _music.playing:
		_music.play()


func stop_music() -> void:
	if _music != null and _music.playing:
		_music.stop()


func set_volumes(music_db: float, sfx_db: float) -> void:
	if _music != null:
		_music.volume_db = music_db
	for p in _players.values():
		(p as AudioStreamPlayer).volume_db = sfx_db
