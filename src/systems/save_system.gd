class_name SaveSystem
extends RefCounted
## Save/load em JSON no diretório do usuário.

const SAVE_PATH := "user://savegame.json"


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save(state: GameState) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Não foi possível salvar: %s" % FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(state.to_dict(), "\t"))
	file.close()
	return true


func load_state() -> GameState:
	if not has_save():
		return null
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return null
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("Save corrompido.")
		return null
	return GameState.from_dict(parsed)


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
