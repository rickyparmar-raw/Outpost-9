extends Node

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []
var _ambient: AudioStreamPlayer


func _ready() -> void:
	for n in ["hum", "alarm", "scan", "deny", "repair", "online", "screech", "door", "scream", "launch", "click", "step", "heartbeat", "vent"]:
		var path := "res://assets/audio/%s.wav" % n
		if ResourceLoader.exists(path):
			_streams[n] = load(path)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_start_ambient()


func _start_ambient() -> void:
	if not _streams.has("hum"):
		return
	var s: AudioStreamWAV = _streams["hum"].duplicate()
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = s.data.size() / 2
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = s
	_ambient.volume_db = -9.0
	add_child(_ambient)
	_ambient.play()


func play(snd: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _streams.has(snd):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[snd]
			p.volume_db = volume_db
			p.pitch_scale = pitch
			p.play()
			return


var _heart: AudioStreamPlayer


func set_heartbeat(active: bool, closeness: float = 0.0) -> void:
	if not _streams.has("heartbeat"):
		return
	if _heart == null:
		var s: AudioStreamWAV = _streams["heartbeat"].duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = s.data.size() / 2
		_heart = AudioStreamPlayer.new()
		_heart.stream = s
		add_child(_heart)
	if active and not _heart.playing:
		_heart.play()
	elif not active and _heart.playing:
		_heart.stop()
	if active:
		_heart.volume_db = lerpf(-20.0, -5.0, clampf(closeness, 0.0, 1.0))
		_heart.pitch_scale = lerpf(0.95, 1.35, clampf(closeness, 0.0, 1.0))
