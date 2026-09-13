class_name SaveSystem
extends RefCounted
## Save/load em JSON no diretório do usuário, em espaços numerados (user://saves/slot_N.json).
## O jogo salva sozinho no fechamento do mês, sempre no espaço da partida em andamento; a tela
## inicial lista os espaços com agência, data e caixa para o jogador escolher qual continuar.
## O save antigo de arquivo único (user://savegame.json) é migrado para o espaço 1 na primeira vez.

const MAX_SLOTS := 5
const SAVE_DIR := "user://saves"
const LEGACY_PATH := "user://savegame.json"

## Espaço em uso pela partida atual (1..MAX_SLOTS).
var current_slot := 1


func setup(_g) -> void:
	_migrate_legacy()


static func path_for(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, clampi(slot, 1, MAX_SLOTS)]


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


## Move o save de arquivo único das versões antigas para o espaço 1.
func _migrate_legacy() -> void:
	if not FileAccess.file_exists(LEGACY_PATH) or has_slot(1):
		return
	var file := FileAccess.open(LEGACY_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	_ensure_dir()
	var out := FileAccess.open(path_for(1), FileAccess.WRITE)
	if out == null:
		return
	out.store_string(text)
	out.close()
	DirAccess.remove_absolute(LEGACY_PATH)


# --- Consultas ------------------------------------------------------------------------

func has_slot(slot: int) -> bool:
	return FileAccess.file_exists(path_for(slot))


func has_save() -> bool:
	for i in range(1, MAX_SLOTS + 1):
		if has_slot(i):
			return true
	return false


## Primeiro espaço livre (0 se estiverem todos ocupados).
func first_free_slot() -> int:
	for i in range(1, MAX_SLOTS + 1):
		if not has_slot(i):
			return i
	return 0


func _read(slot: int) -> Dictionary:
	if not has_slot(slot):
		return {}
	var file := FileAccess.open(path_for(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or not (parsed is Dictionary):
		return {}
	return parsed


## Resumo de um espaço para a tela inicial: {slot, exists, agency_name, day, date, money,
## reputation, employees, clients, office_level, game_over, saved_at}.
func slot_info(slot: int) -> Dictionary:
	var info := {"slot": slot, "exists": false, "agency_name": "", "day": 0, "date": "",
		"money": 0.0, "reputation": 0.0, "employees": 0, "clients": 0, "office_level": 1,
		"game_over": false, "saved_at": 0}
	var d := _read(slot)
	if d.is_empty():
		return info
	info["exists"] = true
	info["agency_name"] = String(d.get("agency_name", "Agência"))
	info["day"] = int(d.get("day", 0))
	info["date"] = GameState.date_text_for(int(d.get("day", 0)))
	info["money"] = float(d.get("money", 0))
	info["reputation"] = float(d.get("reputation", 0))
	info["employees"] = (d.get("employees", []) as Array).size()
	var clients: Array = d.get("clients", [])
	info["clients"] = clients.filter(func(c): return int(c.get("status", 0)) == Client.Status.ACTIVE).size()
	info["office_level"] = int(d.get("office_level", 1))
	info["game_over"] = bool(d.get("game_over", false))
	info["saved_at"] = int(d.get("saved_at", 0))
	return info


func slots() -> Array:
	var out: Array = []
	for i in range(1, MAX_SLOTS + 1):
		out.append(slot_info(i))
	return out


# --- Gravar e carregar ----------------------------------------------------------------

func save(state: GameState, slot: int = -1) -> bool:
	var target: int = current_slot if slot < 1 else clampi(slot, 1, MAX_SLOTS)
	_ensure_dir()
	var file := FileAccess.open(path_for(target), FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível salvar: %s" % FileAccess.get_open_error())
		return false
	var data := state.to_dict()
	data["saved_at"] = int(Time.get_unix_time_from_system())
	data["slot"] = target
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	current_slot = target
	return true


func load_state(slot: int = -1) -> GameState:
	var target: int = current_slot if slot < 1 else clampi(slot, 1, MAX_SLOTS)
	var d := _read(target)
	if d.is_empty():
		return null
	current_slot = target
	return GameState.from_dict(d)


func delete_slot(slot: int) -> void:
	if has_slot(slot):
		DirAccess.remove_absolute(path_for(slot))


func delete_save() -> void:
	for i in range(1, MAX_SLOTS + 1):
		delete_slot(i)
