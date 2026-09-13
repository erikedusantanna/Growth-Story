class_name ContentDB
extends RefCounted
## Carrega o conteúdo estático (JSON em res://data) e oferece consultas rápidas.

var services: Dictionary = {}          # id -> dict
var service_order: Array = []          # ids na ordem do arquivo
var match_table: Dictionary = {}
var problem_solutions: Dictionary = {}
var problem_names: Dictionary = {}
var segment_names: Dictionary = {}
var client_templates: Array = []
var client_personalities: Dictionary = {}
var events: Array = []
var names: Dictionary = {}
var personalities: Dictionary = {}
var roles: Dictionary = {}
var career: Array = []
var colors: Array = []
var courses: Array = []
var offices: Array = []
var regions: Dictionary = {}          # World Map (data/regions.json)
var feed: Dictionary = {}
var objectives: Array = []
var hr: Dictionary = {}
var furniture: Dictionary = {}
var agency_events: Dictionary = {}
var eras: Array = []
var departments: Dictionary = {}
var competitors: Dictionary = {}
var scenes: Dictionary = {}          # cenários de evento (data/scenes.json)
var seasons: Array = []              # datas comemorativas (data/seasons.json)
var tutorial: Array = []             # passos do guia inicial (data/tutorial.json)
var briefings: Array = []            # temas de projeto (data/briefings.json)
var chemistry: Array = []            # pares de personalidade (data/chemistry.json)
var quests: Dictionary = {}          # missões (data/quests.json)
var news: Dictionary = {}            # notícias cômicas (data/news.json)
var decisions: Dictionary = {}       # decisões no meio do projeto (data/decisions.json)
var crises: Dictionary = {}          # crises da região (data/crises.json)


func load_all() -> void:
	var s := _load_json("res://data/services.json")
	for svc in s.get("services", []):
		services[svc["id"]] = svc
		service_order.append(svc["id"])
	match_table = s.get("match_table", {})
	problem_solutions = s.get("problem_solutions", {})
	problem_names = s.get("problem_names", {})
	segment_names = s.get("segment_names", {})

	var c := _load_json("res://data/clients.json")
	client_templates = c.get("clients", [])
	client_personalities = c.get("personalities", {})

	events = _load_json("res://data/events.json").get("events", [])

	var n := _load_json("res://data/names.json")
	names = {"first": n.get("first", []), "last": n.get("last", [])}
	personalities = n.get("personalities", {})
	roles = n.get("roles", {})
	career = n.get("career", [])
	colors = n.get("colors", [])

	courses = _load_json("res://data/training.json").get("courses", [])
	offices = _load_json("res://data/offices.json").get("offices", [])
	regions = _load_json("res://data/regions.json")
	feed = _load_json("res://data/feed.json")
	objectives = _load_json("res://data/objectives.json").get("objectives", [])
	hr = _load_json("res://data/hr_actions.json")
	furniture = _load_json("res://data/furniture.json")
	agency_events = _load_json("res://data/agency_events.json")
	eras = _load_json("res://data/eras.json").get("eras", [])
	scenes = _load_json("res://data/scenes.json").get("scenes", {})
	seasons = _load_json("res://data/seasons.json").get("seasons", [])
	tutorial = _load_json("res://data/tutorial.json").get("steps", [])
	briefings = _load_json("res://data/briefings.json").get("briefings", [])
	chemistry = _load_json("res://data/chemistry.json").get("pairs", [])
	departments = _load_json("res://data/departments.json")
	competitors = _load_json("res://data/competitors.json")
	quests = _load_json("res://data/quests.json")
	news = _load_json("res://data/news.json")
	decisions = _load_json("res://data/decisions.json")
	crises = _load_json("res://data/crises.json")


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Conteúdo não encontrado: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Dictionary):
		push_error("JSON inválido: %s" % path)
		return {}
	return parsed


func service_name(id: String) -> String:
	return services.get(id, {}).get("name", id)


func role_name(id: String) -> String:
	return roles.get(id, {}).get("name", id)


func career_name(level: int) -> String:
	if career.is_empty():
		return ""
	return career[clampi(level, 0, career.size() - 1)]["name"]


