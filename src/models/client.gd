class_name Client
extends RefCounted
## Cliente: funciona como personagem, com objetivo declarado e problema real oculto.

enum Status { PROSPECT, ACTIVE, LOST }

var id: int = 0
var template_id: String = ""
var name: String = ""
var segment: String = "servicos"
var tier: int = 1
var budget: float = 3000.0            # orçamento mensal de referência
var expectation: String = "media"     # baixa / media / alta
var patience: float = 50.0            # 0..100
var maturity: int = 1                 # maturidade de marketing 1..3
var personality: String = "loyal"
var difficulty: int = 1               # 1..5
var goal: String = ""
var problem: String = "leads"         # problema real (oculto até o diagnóstico)
var diagnosed: bool = false
var diagnosis_days_left: int = 0
var relationship: float = 50.0        # 0..100
var satisfaction: int = 3             # corações 1..5
var status: int = Status.PROSPECT
var known_on: int = 0                 # dia em que virou prospect
var last_project_day: int = -1
var projects_done: int = 0
var proposal_attempts: int = 0
var retainer_months_left: int = 0     # >0 quando há contrato recorrente


func is_active() -> bool:
	return status == Status.ACTIVE


func to_dict() -> Dictionary:
	return {
		"id": id, "template_id": template_id, "name": name, "segment": segment, "tier": tier,
		"budget": budget, "expectation": expectation, "patience": patience, "maturity": maturity,
		"personality": personality, "difficulty": difficulty, "goal": goal, "problem": problem,
		"diagnosed": diagnosed, "diagnosis_days_left": diagnosis_days_left,
		"relationship": relationship, "satisfaction": satisfaction, "status": status,
		"known_on": known_on, "last_project_day": last_project_day, "projects_done": projects_done,
		"proposal_attempts": proposal_attempts, "retainer_months_left": retainer_months_left,
	}


static func from_dict(d: Dictionary) -> Client:
	var c := Client.new()
	c.id = int(d.get("id", 0))
	c.template_id = d.get("template_id", "")
	c.name = d.get("name", "")
	c.segment = d.get("segment", "servicos")
	c.tier = int(d.get("tier", 1))
	c.budget = float(d.get("budget", 3000))
	c.expectation = d.get("expectation", "media")
	c.patience = float(d.get("patience", 50))
	c.maturity = int(d.get("maturity", 1))
	c.personality = d.get("personality", "loyal")
	c.difficulty = int(d.get("difficulty", 1))
	c.goal = d.get("goal", "")
	c.problem = d.get("problem", "leads")
	c.diagnosed = bool(d.get("diagnosed", false))
	c.diagnosis_days_left = int(d.get("diagnosis_days_left", 0))
	c.relationship = float(d.get("relationship", 50))
	c.satisfaction = int(d.get("satisfaction", 3))
	c.status = int(d.get("status", Status.PROSPECT))
	c.known_on = int(d.get("known_on", 0))
	c.last_project_day = int(d.get("last_project_day", -1))
	c.projects_done = int(d.get("projects_done", 0))
	c.proposal_attempts = int(d.get("proposal_attempts", 0))
	c.retainer_months_left = int(d.get("retainer_months_left", 0))
	return c
