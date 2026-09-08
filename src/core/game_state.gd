class_name GameState
extends RefCounted
## Estado completo de uma partida. Tudo que precisa ser salvo mora aqui.

const START_YEAR := 2010
const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const MONTH_NAMES := ["Jan", "Fev", "Mar", "Abr", "Mai", "Jun", "Jul", "Ago", "Set", "Out", "Nov", "Dez"]

var seed: int = 0
var rng := RandomNumberGenerator.new()
var agency_name: String = "Minha Agência"
var day: int = 0
var money: float = 5000.0
var reputation: float = 5.0
var office_level: int = 1
var rent_modifier: float = 1.0
var employees: Array = []       # Employee
var candidates: Array = []      # Employee
var clients: Array = []         # Client
var projects: Array = []        # Project
var unlocked_services: Array = ["social_media", "design", "paid_traffic"]
var flags: Dictionary = {}
var next_id: int = 1
var log: Array = []             # [{day, text, kind}]
var finance_history: Array = [] # [{month_index, revenue, expenses, cash}]
var month_revenue: float = 0.0
var month_expenses: float = 0.0
var last_event_day: int = -999
var events_seen: Dictionary = {}
var events_last_day: Dictionary = {}   # id -> último dia em que disparou
var objective_index: int = 0           # objetivo atual (data/objectives.json)
var furniture: Array = []               # ids de mobília comprada
var buffs: Array = []                   # [{id, until_day, productivity, stress_rate}] efeitos temporários do RH
var hr_last_used: Dictionary = {}       # id da ação -> último dia
var agency_events: Array = []           # [{id, ends_day, people:[ids]}] eventos em andamento
var agency_events_last: Dictionary = {} # id -> último dia
var pending_event: Dictionary = {}
var cases: int = 0
var speed: int = 1
var paused: bool = false
var game_over: bool = false
var stats: Dictionary = {"projects_done": 0, "five_stars": 0, "hires": 0, "total_revenue": 0.0, "clients_signed": 0, "trainings": 0, "retainers": 0, "diagnoses": 0, "hr_actions": 0, "furniture": 0, "agency_events": 0}


func new_id() -> int:
	next_id += 1
	return next_id - 1


# --- Calendário ---------------------------------------------------------------

func month_index() -> int:
	return day / DAYS_PER_MONTH


func month() -> int:
	return month_index() % MONTHS_PER_YEAR


func year() -> int:
	return START_YEAR + month_index() / MONTHS_PER_YEAR


func day_of_month() -> int:
	return day % DAYS_PER_MONTH + 1


func date_text() -> String:
	return date_text_for(day)


static func date_text_for(d: int) -> String:
	var mi := d / DAYS_PER_MONTH
	return "%02d %s %d" % [d % DAYS_PER_MONTH + 1, MONTH_NAMES[mi % MONTHS_PER_YEAR], START_YEAR + mi / MONTHS_PER_YEAR]


func game_year() -> int:
	return day / (DAYS_PER_MONTH * MONTHS_PER_YEAR) + 1


# --- Consultas ----------------------------------------------------------------

func employee_by_id(id: int) -> Employee:
	for e in employees:
		if e.id == id:
			return e
	return null


func client_by_id(id: int) -> Client:
	for c in clients:
		if c.id == id:
			return c
	return null


func project_by_id(id: int) -> Project:
	for p in projects:
		if p.id == id:
			return p
	return null


func running_projects() -> Array:
	return projects.filter(func(p): return p.is_running())


func active_clients() -> Array:
	return clients.filter(func(c): return c.status == Client.Status.ACTIVE)


func prospects() -> Array:
	return clients.filter(func(c): return c.status == Client.Status.PROSPECT)


func project_for_client(client_id: int) -> Project:
	for p in projects:
		if p.is_running() and p.client_id == client_id:
			return p
	return null


func available_employees() -> Array:
	return employees.filter(func(e): return e.is_available(day))


func mrr() -> float:
	var total := 0.0
	for p in projects:
		if p.is_running() and p.kind == Project.Kind.RETAINER:
			total += p.budget
	return total


func add_log(text: String, kind: String = "info") -> void:
	log.append({"day": day, "text": text, "kind": kind})
	if log.size() > 60:
		log.pop_front()


# --- Serialização ---------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"seed": seed, "rng_state": str(rng.state), "agency_name": agency_name, "day": day,
		"money": money, "reputation": reputation, "office_level": office_level,
		"rent_modifier": rent_modifier,
		"employees": employees.map(func(e): return e.to_dict()),
		"candidates": candidates.map(func(e): return e.to_dict()),
		"clients": clients.map(func(c): return c.to_dict()),
		"projects": projects.map(func(p): return p.to_dict()),
		"unlocked_services": unlocked_services.duplicate(),
		"flags": flags.duplicate(), "next_id": next_id, "log": log.duplicate(true),
		"finance_history": finance_history.duplicate(true),
		"month_revenue": month_revenue, "month_expenses": month_expenses,
		"last_event_day": last_event_day, "events_seen": events_seen.duplicate(),
		"events_last_day": events_last_day.duplicate(), "objective_index": objective_index,
		"furniture": furniture.duplicate(), "buffs": buffs.duplicate(true), "hr_last_used": hr_last_used.duplicate(),
		"agency_events": agency_events.duplicate(true), "agency_events_last": agency_events_last.duplicate(),
		"pending_event": pending_event.duplicate(true), "cases": cases,
		"speed": speed, "game_over": game_over, "stats": stats.duplicate(),
	}


static func from_dict(d: Dictionary) -> GameState:
	var s := GameState.new()
	s.seed = int(d.get("seed", 0))
	s.rng.seed = s.seed
	if d.has("rng_state"):
		s.rng.state = String(str(d["rng_state"])).to_int()
	s.agency_name = d.get("agency_name", "Minha Agência")
	s.day = int(d.get("day", 0))
	s.money = float(d.get("money", 0))
	s.reputation = float(d.get("reputation", 0))
	s.office_level = int(d.get("office_level", 1))
	s.rent_modifier = float(d.get("rent_modifier", 1.0))
	s.employees = []
	for e in d.get("employees", []):
		s.employees.append(Employee.from_dict(e))
	s.candidates = []
	for e in d.get("candidates", []):
		s.candidates.append(Employee.from_dict(e))
	s.clients = []
	for c in d.get("clients", []):
		s.clients.append(Client.from_dict(c))
	s.projects = []
	for p in d.get("projects", []):
		s.projects.append(Project.from_dict(p))
	s.unlocked_services = Array(d.get("unlocked_services", []))
	s.flags = d.get("flags", {})
	s.next_id = int(d.get("next_id", 1))
	s.log = Array(d.get("log", []))
	s.finance_history = Array(d.get("finance_history", []))
	s.month_revenue = float(d.get("month_revenue", 0))
	s.month_expenses = float(d.get("month_expenses", 0))
	s.last_event_day = int(d.get("last_event_day", -999))
	s.events_seen = d.get("events_seen", {})
	s.events_last_day = d.get("events_last_day", {})
	s.objective_index = int(d.get("objective_index", 0))
	s.furniture = Array(d.get("furniture", []))
	s.buffs = Array(d.get("buffs", []))
	s.hr_last_used = d.get("hr_last_used", {})
	s.agency_events = Array(d.get("agency_events", []))
	s.agency_events_last = d.get("agency_events_last", {})
	s.pending_event = d.get("pending_event", {})
	s.cases = int(d.get("cases", 0))
	s.speed = int(d.get("speed", 1))
	s.game_over = bool(d.get("game_over", false))
	var stats = d.get("stats", {})
	for key in s.stats:
		if stats.has(key):
			s.stats[key] = stats[key]
	return s
