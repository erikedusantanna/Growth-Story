class_name Employee
extends RefCounted
## Funcionário (ou candidato). Atributos principais de 1 a 100.

const ATTRS := ["creativity", "strategy", "performance", "communication", "management", "technology"]
const SKIN_TONES := ["#f1d3b3", "#e0b48c", "#c68f63", "#9c6b45", "#6f4a30"]
const HAIR_COLORS := ["#2a2432", "#4a2e1c", "#8a5a2b", "#c98a3a", "#e6c15a", "#b8b8c0", "#a34a4a", "#3b3b6e"]
const HAIR_STYLES := 7            # curto, longo, coque, rabo, cacheado, raspado, franja de lado
const ATTR_NAMES := {
	"creativity": "Criatividade", "strategy": "Estratégia", "performance": "Performance",
	"communication": "Comunicação", "management": "Gestão", "technology": "Tecnologia",
}

var id: int = 0
var name: String = ""
var role: String = "generalist"        # especialização (id de serviço, "generalist" ou "account")
var personality: String = "leal"
var is_founder: bool = false
var attrs: Dictionary = {}             # attr -> float (1..100)
var motivation: float = 70.0
var stress: float = 0.0
var loyalty: float = 60.0
var experience: float = 0.0            # XP acumulado
var potential: int = 3                 # 1..5
var salary: float = 0.0               # mensal
var career_level: int = 0
var age: int = 24
var color: String = "#e4572e"         # cor da camisa
var skin: String = "#f1d3b3"
var hair_style: int = 0
var hair_color: String = "#4a2e1c"
var glasses: bool = false
var hired_on: int = -1                 # dia da contratação (-1 = candidato)
var candidate_expires: int = 0         # dia em que o candidato some da lista
var project_id: int = -1               # projeto atual (-1 = livre)
var training_id: String = ""
var legendary: bool = false            # talento raro (aparece por poucos dias, disputado com as rivais)
var specializing: String = ""          # serviço em que está virando especialista (trilha de carreira)
var busy_until: int = -1               # dia até o qual está ocupado (treino/burnout)
var busy_reason: String = ""
var months_since_raise: int = 0
var journey: Array = []                # [{day, text}] história do colaborador na agência
var department: String = ""            # id do departamento (data/departments.json), "" = nenhum
var idle_days: int = 0                 # dias seguidos sem projeto (pressão "sem desafio")
var last_good_news_day: int = -99      # promoção, prêmio ou 5 estrelas (estado "celebrando" por 3 dias)
var last_offer_day: int = -999         # última proposta de concorrente (estado "assediado" por 30 dias)


func attr(key: String) -> float:
	return float(attrs.get(key, 30.0))


func is_available(day: int) -> bool:
	return project_id == -1 and busy_until < day


func is_busy_reason(day: int) -> String:
	if project_id != -1:
		return "Em projeto"
	if busy_until >= day and busy_reason != "":
		return busy_reason
	return "Livre"


## Habilidade para um serviço, dado o dicionário de pesos do serviço.
func skill_for(weights: Dictionary) -> float:
	if weights.is_empty():
		return average_attr()
	var total := 0.0
	var weight_sum := 0.0
	for key in weights:
		total += attr(key) * float(weights[key])
		weight_sum += float(weights[key])
	return total / maxf(weight_sum, 0.001)


func average_attr() -> float:
	var total := 0.0
	for key in ATTRS:
		total += attr(key)
	return total / ATTRS.size()


func best_attr() -> String:
	var best := ATTRS[0]
	for key in ATTRS:
		if attr(key) > attr(best):
			best = key
	return best


func to_dict() -> Dictionary:
	return {
		"id": id, "name": name, "role": role, "personality": personality, "is_founder": is_founder,
		"attrs": attrs.duplicate(), "motivation": motivation, "stress": stress, "loyalty": loyalty,
		"experience": experience, "potential": potential, "salary": salary, "career_level": career_level,
		"age": age, "color": color, "skin": skin, "hair_style": hair_style, "hair_color": hair_color, "glasses": glasses,
		"hired_on": hired_on, "candidate_expires": candidate_expires,
		"project_id": project_id, "training_id": training_id, "specializing": specializing, "legendary": legendary, "busy_until": busy_until,
		"busy_reason": busy_reason, "months_since_raise": months_since_raise,
		"journey": journey.duplicate(true), "department": department,
		"idle_days": idle_days, "last_good_news_day": last_good_news_day, "last_offer_day": last_offer_day,
	}


static func from_dict(d: Dictionary) -> Employee:
	var e := Employee.new()
	e.id = int(d.get("id", 0))
	e.name = d.get("name", "")
	e.role = d.get("role", "generalist")
	e.personality = d.get("personality", "leal")
	e.is_founder = bool(d.get("is_founder", false))
	e.attrs = {}
	for key in d.get("attrs", {}):
		e.attrs[key] = float(d["attrs"][key])
	e.motivation = float(d.get("motivation", 70))
	e.stress = float(d.get("stress", 0))
	e.loyalty = float(d.get("loyalty", 60))
	e.experience = float(d.get("experience", 0))
	e.potential = int(d.get("potential", 3))
	e.salary = float(d.get("salary", 0))
	e.career_level = int(d.get("career_level", 0))
	e.age = int(d.get("age", 24))
	e.color = d.get("color", "#e4572e")
	e.skin = d.get("skin", SKIN_TONES[e.id % SKIN_TONES.size()])
	e.hair_style = int(d.get("hair_style", e.id % HAIR_STYLES))
	e.hair_color = d.get("hair_color", HAIR_COLORS[(e.id * 3) % HAIR_COLORS.size()])
	e.glasses = bool(d.get("glasses", (e.id * 7) % 4 == 0))
	e.hired_on = int(d.get("hired_on", -1))
	e.candidate_expires = int(d.get("candidate_expires", 0))
	e.project_id = int(d.get("project_id", -1))
	e.training_id = d.get("training_id", "")
	e.specializing = String(d.get("specializing", ""))
	e.legendary = bool(d.get("legendary", false))
	e.busy_until = int(d.get("busy_until", -1))
	e.busy_reason = d.get("busy_reason", "")
	e.months_since_raise = int(d.get("months_since_raise", 0))
	e.journey = Array(d.get("journey", []))
	e.department = String(d.get("department", ""))
	e.idle_days = int(d.get("idle_days", 0))
	e.last_good_news_day = int(d.get("last_good_news_day", -99))
	e.last_offer_day = int(d.get("last_offer_day", -999))
	return e
