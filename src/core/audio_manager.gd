extends Node
## Música e efeitos sonoros (GDD §41). Toda a trilha e os efeitos são sintetizados por
## código em tools/gen_audio.py — sem samples externos. Reage aos sinais do EventBus,
## então nenhum outro sistema precisa saber que o áudio existe.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_PATH := "res://assets/audio/music/theme_loop.wav"
const AMBIENCE_PATH := "res://assets/audio/ambience/office_loop.wav"
const SETTINGS_PATH := "user://audio_settings.cfg"
const POOL_SIZE := 6

var music_enabled := true
var sfx_enabled := true
var ambience_enabled := true          # sons do escritório (teclado, ar-condicionado, notificações)
var music_volume_db := -7.0
var sfx_volume_db := -4.0
var ambience_volume_db := -18.0       # base; sobe um pouco com o tamanho da equipe

var _pool: Array = []
var _pool_index := 0
var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _last_rep_tier := -1
var _streams: Dictionary = {}
## Sem placa de som real (testes headless, CI): guardamos o estado normalmente, mas não
## chamamos play() — o driver "Dummy" não libera AudioStreamPlayback entre chamadas
## rápidas e os recursos ficam presos até o fim do processo.
var _silent := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_silent = DisplayServer.get_name() == "headless"
	_load_settings()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)
	_music_player.stream = _load_loop(MUSIC_PATH)
	_music_player.volume_db = music_volume_db
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = "Master"
	add_child(_ambience_player)
	_ambience_player.stream = _load_loop(AMBIENCE_PATH)
	_ambience_player.volume_db = ambience_volume_db
	EventBus.employee_hired.connect(func(_e): play_sfx("hire"))
	EventBus.employee_promoted.connect(func(_e): play_sfx("promotion"))
	EventBus.client_lost.connect(func(_c, _r = ""): play_sfx("crisis"))
	EventBus.event_triggered.connect(func(_ev): play_sfx("event"))
	EventBus.prospect_arrived.connect(func(_c): play_sfx("prospect"))
	EventBus.quest_started.connect(func(_q): play_sfx("quest"))
	EventBus.news_published.connect(func(_n): play_sfx("news"))
	EventBus.money_changed.connect(_on_money_changed)
	EventBus.reputation_changed.connect(_on_reputation_changed)
	EventBus.project_completed.connect(_on_project_completed)
	EventBus.game_started.connect(func(): _last_rep_tier = -1; play_music(); play_ambience())
	call_deferred("play_music")   # toca desde a tela inicial


## Carrega um WAV em loop. loop_end 0 faria o stream voltar ao início a cada quadro (silêncio);
## o import já marca o fim, mas garantimos aqui: 16 bits mono = 2 bytes por amostra.
func _load_loop(path: String) -> AudioStream:
	var stream: AudioStream = load(path)
	if stream != null and stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		if stream.loop_end <= 0:
			stream.loop_end = stream.data.size() / 2
	return stream


func toggle_music() -> void:
	set_music_enabled(not music_enabled)


# --- Som ambiente do escritório ------------------------------------------------------

func play_ambience() -> void:
	if _silent:
		return
	if ambience_enabled and _ambience_player.stream != null and not _ambience_player.playing:
		_ambience_player.play()


func stop_ambience() -> void:
	_ambience_player.stop()


func set_ambience_enabled(on: bool) -> void:
	ambience_enabled = on
	if on and Game.has_game():
		play_ambience()
	elif not on:
		stop_ambience()
	_save_settings()


## Mais gente na equipe, mais teclado e conversa: até +6 dB com 10 pessoas.
func set_ambience_people(count: int) -> void:
	_ambience_player.volume_db = ambience_volume_db + clampf(float(count) - 1.0, 0.0, 9.0) * 0.66


## Libera as streams em uso antes do motor encerrar (evita aviso de recurso vazado ao sair).
func _exit_tree() -> void:
	for p in _pool:
		p.stop()
		p.stream = null
	_music_player.stop()
	_music_player.stream = null
	_ambience_player.stop()
	_ambience_player.stream = null
	_streams.clear()


func _on_money_changed(_value: float, delta: float) -> void:
	if delta > 0.0:
		play_sfx("payment")


func _on_project_completed(_project, result: Dictionary) -> void:
	var stars := int(result.get("stars", 0))
	if stars >= 4:
		play_sfx("client_happy")
	else:
		play_sfx("project_complete")


func _on_reputation_changed(value: float, _delta: float) -> void:
	var tier := _tier_of(value)
	if _last_rep_tier == -1:
		_last_rep_tier = tier
		return
	if tier > _last_rep_tier:
		play_sfx("level_up")
	_last_rep_tier = tier


func _tier_of(rep: float) -> int:
	if rep >= 80.0:
		return 4
	if rep >= 60.0:
		return 3
	if rep >= 40.0:
		return 2
	if rep >= 20.0:
		return 1
	return 0


## Toca um efeito sonoro pelo nome (arquivo em assets/audio/sfx/<nome>.wav).
func play_sfx(name: String) -> void:
	if not sfx_enabled or _silent:
		return
	var stream: AudioStream = _streams.get(name)
	if stream == null:
		stream = load(SFX_DIR + name + ".wav")
		if stream == null:
			return
		_streams[name] = stream
	var p: AudioStreamPlayer = _pool[_pool_index]
	_pool_index = (_pool_index + 1) % _pool.size()
	p.stream = stream
	p.volume_db = sfx_volume_db
	p.play()


func play_music() -> void:
	if _silent:
		return
	if music_enabled and _music_player.stream != null and not _music_player.playing:
		_music_player.play()


func stop_music() -> void:
	_music_player.stop()


func set_music_enabled(on: bool) -> void:
	music_enabled = on
	if on:
		play_music()
	else:
		stop_music()
	_save_settings()


func set_sfx_enabled(on: bool) -> void:
	sfx_enabled = on
	_save_settings()
	if on:
		play_sfx("click")


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		music_enabled = cfg.get_value("audio", "music_enabled", true)
		sfx_enabled = cfg.get_value("audio", "sfx_enabled", true)
		ambience_enabled = cfg.get_value("audio", "ambience_enabled", true)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_enabled", music_enabled)
	cfg.set_value("audio", "sfx_enabled", sfx_enabled)
	cfg.set_value("audio", "ambience_enabled", ambience_enabled)
	cfg.save(SETTINGS_PATH)
