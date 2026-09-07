class_name Employee
extends RefCounted
## Funcionário (ou candidato). Atributos principais de 1 a 100.

const ATTRS := ["creativity", "strategy", "performance", "communication", "management", "technology"]
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
var color: String = "#e4572e"
var hired_on: int = -1                 # dia da contratação (-1 = candidato)
var candidate_expires: int = 0         # dia em que o candidato some da lista
var project_id: int = -1               # projeto atual (-1 = livre)
var training_id: String = ""
var busy_until: int = -1               # dia até o qual está ocupado (treino/burnout)
var busy_reason: String = ""
var months_since_raise: int = 0


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
		"age": age, "color": color, "hired_on": hired_on, "candidate_expires": candidate_expires,
		"project_id": project_id, "training_id": training_id, "busy_until": busy_until,
		"busy_reason": busy_reason, "months_since_raise": months_since_raise,
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
	e.hired_on = int(d.get("hired_on", -1))
	e.candidate_expires = int(d.get("candidate_expires", 0))
	e.project_id = int(d.get("project_id", -1))
	e.training_id = d.get("training_id", "")
	e.busy_until = int(d.get("busy_until", -1))
	e.busy_reason = d.get("busy_reason", "")
	e.months_since_raise = int(d.get("months_since_raise", 0))
	return e
