extends Node
## SFX: lightweight synthesized sound effects. Play one-shot samples via
## play(name). Names map to assets/sfx/<name>.wav.

var _players := {}          # name -> Array of idle AudioStreamPlayer (pool)
const DIR := "res://assets/sfx"

func _ready() -> void:
	for s in DirAccess.get_files_at(DIR):
		if not s.ends_with(".wav"):
			continue
		var name := s.trim_suffix(".wav")
		var stream := load(DIR + "/" + s)
		_players[name] = []

func _get_player(name: String) -> AudioStreamPlayer:
	if not _players.has(name):
		return null
	var arr: Array = _players[name]
	for p in arr:
		if not p.playing:
			return p
	var np := AudioStreamPlayer.new()
	np.stream = load(DIR + "/%s.wav" % name)
	np.bus = &"Master"
	add_child(np)
	arr.append(np)
	return np

func play(name: String) -> void:
	var p := _get_player(name)
	if p != null:
		p.play()

func play_rand(names: Array) -> void:
	if names.is_empty():
		return
	play(names[randi() % names.size()])