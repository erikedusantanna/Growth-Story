class_name ChemistrySystem
extends RefCounted
## Sinergia e atrito (data/chemistry.json): pares de personalidades na mesma equipe de projeto
## ajudam ou atrapalham. A soma dos pares dá a "química" da equipe, usada na nota, no ritmo
## e no dia a dia (moral sobe com sinergia, estresse sobe com atrito).

const MAX_SCORE := 3
const SCORE_BONUS := 3.0        # pontos na nota por ponto de química
const OUTPUT_PER_POINT := 0.05  # ritmo de produção por ponto
const MORALE_PER_DAY := 0.06    # por ponto positivo, por dia
const STRESS_PER_DAY := 0.3     # por ponto negativo, por dia

var game


func setup(g) -> void:
	game = g


func pairs() -> Array:
	return game.content.chemistry


## Par (a, b) em qualquer ordem, ou {} se as personalidades não interagem.
func pair(a: String, b: String) -> Dictionary:
	for p in pairs():
		if (p.a == a and p.b == b) or (p.a == b and p.b == a):
			return p
	return {}


## {score: -3..3, items: [{kind, text, names}]} para uma lista de Employee.
func team_chemistry(members: Array) -> Dictionary:
	var score := 0
	var items: Array = []
	for i in members.size():
		for j in range(i + 1, members.size()):
			var a: Employee = members[i]
			var b: Employee = members[j]
			var p := pair(a.personality, b.personality)
			if p.is_empty():
				continue
			var kind := String(p.get("kind", "synergy"))
			score += 1 if kind == "synergy" else -1
			items.append({"kind": kind, "text": String(p.get("text", "")),
				"names": "%s + %s" % [a.name.split(" ")[0], b.name.split(" ")[0]]})
	return {"score": clampi(score, -MAX_SCORE, MAX_SCORE), "items": items}


## Personalidades que combinam / atritam com uma dada personalidade (para a ficha da pessoa).
func partners_for(personality: String) -> Dictionary:
	var good: Array = []
	var bad: Array = []
	for p in pairs():
		var other := ""
		if p.a == personality:
			other = String(p.b)
		elif p.b == personality:
			other = String(p.a)
		else:
			continue
		var name: String = game.content.personalities.get(other, {}).get("name", other)
		if String(p.get("kind", "")) == "synergy":
			good.append(name)
		else:
			bad.append(name)
	return {"synergy": good, "friction": bad}


## Efeito diário nas pessoas de um projeto em andamento.
func apply_daily(members: Array) -> void:
	var chem := team_chemistry(members)
	var score: int = chem["score"]
	if score == 0:
		return
	var cap: float = game.office.morale_max()
	for e in members:
		if score > 0:
			e.motivation = clampf(e.motivation + MORALE_PER_DAY * score, 0.0, cap)
		else:
			e.stress = clampf(e.stress + STRESS_PER_DAY * -score, 0.0, 100.0)
