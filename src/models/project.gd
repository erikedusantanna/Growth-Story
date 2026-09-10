class_name Project
extends RefCounted
## Projeto (entrega única) ou retainer (ciclos mensais) executado por uma equipe.

enum Kind { PROJECT, RETAINER }
enum Status { RUNNING, DONE, CANCELLED }

const INDICATORS := ["strategy", "creativity", "execution", "performance"]
const INDICATOR_NAMES := {
	"strategy": "Estratégia", "creativity": "Criatividade",
	"execution": "Execução", "performance": "Performance",
}

var id: int = 0
var client_id: int = 0
var title: String = ""
var kind: int = Kind.PROJECT
var status: int = Status.RUNNING
var budget: float = 0.0               # valor do projeto ou mensalidade do retainer
var deadline_days: int = 30
var days_elapsed: int = 0
var started_on: int = 0
var finished_on: int = -1
var objective: String = ""
var services: Array = []              # ids de serviço (1..3)
var team: Array = []                  # ids de funcionário
var effort_total: float = 30.0        # pontos de trabalho necessários
var effort_done: float = 0.0
var indicators: Dictionary = {"strategy": 0.0, "creativity": 0.0, "execution": 0.0, "performance": 0.0}
var targets: Dictionary = {"strategy": 50.0, "creativity": 50.0, "execution": 50.0, "performance": 50.0}
var boosts: Dictionary = {"strategy": 0.0, "creativity": 0.0, "execution": 0.0, "performance": 0.0}
var match_quality: String = "neutral" # perfect / good / neutral / poor
var addresses_problem: bool = false
var briefing: String = ""             # tema do projeto (data/briefings.json)
var months_left: int = 0              # retainer
var cycle: int = 0                    # ciclos concluídos (retainer)
var result: Dictionary = {}           # último resultado {stars, score, payment, ...}
var history: Array = []               # resultados dos ciclos (retainer)


func progress() -> float:
	return clampf(effort_done / maxf(effort_total, 1.0), 0.0, 1.0)


func is_running() -> bool:
	return status == Status.RUNNING


func is_late() -> bool:
	return days_elapsed > deadline_days


func to_dict() -> Dictionary:
	return {
		"id": id, "client_id": client_id, "title": title, "kind": kind, "status": status,
		"budget": budget, "deadline_days": deadline_days, "days_elapsed": days_elapsed,
		"started_on": started_on, "finished_on": finished_on, "objective": objective,
		"services": services.duplicate(), "team": team.duplicate(),
		"effort_total": effort_total, "effort_done": effort_done,
		"indicators": indicators.duplicate(), "targets": targets.duplicate(), "boosts": boosts.duplicate(),
		"match_quality": match_quality, "addresses_problem": addresses_problem, "briefing": briefing,
		"months_left": months_left, "cycle": cycle, "result": result.duplicate(true),
		"history": history.duplicate(true),
	}


static func from_dict(d: Dictionary) -> Project:
	var p := Project.new()
	p.id = int(d.get("id", 0))
	p.client_id = int(d.get("client_id", 0))
	p.title = d.get("title", "")
	p.kind = int(d.get("kind", Kind.PROJECT))
	p.status = int(d.get("status", Status.RUNNING))
	p.budget = float(d.get("budget", 0))
	p.deadline_days = int(d.get("deadline_days", 30))
	p.days_elapsed = int(d.get("days_elapsed", 0))
	p.started_on = int(d.get("started_on", 0))
	p.finished_on = int(d.get("finished_on", -1))
	p.objective = d.get("objective", "")
	p.briefing = String(d.get("briefing", ""))
	p.services = Array(d.get("services", []))
	p.team = []
	for t in d.get("team", []):
		p.team.append(int(t))
	p.effort_total = float(d.get("effort_total", 30))
	p.effort_done = float(d.get("effort_done", 0))
	for key in INDICATORS:
		p.indicators[key] = float(d.get("indicators", {}).get(key, 0))
		p.targets[key] = float(d.get("targets", {}).get(key, 50))
		p.boosts[key] = float(d.get("boosts", {}).get(key, 0))
	p.match_quality = d.get("match_quality", "neutral")
	p.addresses_problem = bool(d.get("addresses_problem", false))
	p.months_left = int(d.get("months_left", 0))
	p.cycle = int(d.get("cycle", 0))
	p.result = d.get("result", {})
	p.history = Array(d.get("history", []))
	return p
