class_name DepartmentSystem
extends RefCounted
## Departamentos e gerentes (GDD §30-31): a partir de um escritório grande, o jogador
## pode agrupar a equipe em departamentos. Um departamento com gerente (carreira "Gerente"
## ou acima) e pelo menos min_members_for_bonus pessoas dá um bônus de produtividade a
## todo mundo nele — uma forma leve de "deixar de executar" sem virar um ERP.

const MANAGER_CAREER_LEVEL := 5   # índice de "Gerente" em data/names.json → career

var game


func setup(g) -> void:
	game = g


func is_unlocked() -> bool:
	return game.state.office_level >= int(game.content.departments.get("unlock_office", 4))


func all() -> Array:
	return game.content.departments.get("departments", [])


func by_id(id: String) -> Dictionary:
	for d in all():
		if d["id"] == id:
			return d
	return {}


func members(dept_id: String) -> Array:
	return game.state.employees.filter(func(e): return e.department == dept_id)


## Primeiro funcionário do departamento já promovido a Gerente (ou acima).
func manager(dept_id: String) -> Employee:
	for e in members(dept_id):
		if e.career_level >= MANAGER_CAREER_LEVEL:
			return e
	return null


func has_bonus(dept_id: String) -> bool:
	var min_members := int(game.content.departments.get("min_members_for_bonus", 2))
	return members(dept_id).size() >= min_members and manager(dept_id) != null


## Multiplicador de produtividade do departamento de um funcionário (1.0 se não se aplica).
func productivity_multiplier(e: Employee) -> float:
	if e.department == "" or not is_unlocked():
		return 1.0
	if has_bonus(e.department):
		return 1.0 + float(game.content.departments.get("productivity_bonus", 0.08))
	return 1.0


func can_assign(e: Employee, dept_id: String) -> Dictionary:
	if not is_unlocked():
		var office_name: String = game.office.level_data(int(game.content.departments.get("unlock_office", 4))).get("name", "")
		return {"ok": false, "reason": "Departamentos abrem com o %s." % office_name}
	if dept_id != "" and by_id(dept_id).is_empty():
		return {"ok": false, "reason": "Departamento desconhecido."}
	return {"ok": true, "reason": ""}


func assign(e: Employee, dept_id: String) -> Dictionary:
	var check := can_assign(e, dept_id)
	if not check.ok:
		return check
	e.department = dept_id
	if dept_id != "":
		game.employees.add_journey(e, "Passou a fazer parte do departamento de %s." % String(by_id(dept_id).get("name", dept_id)))
		game.add_log("%s entrou para o time de %s." % [e.name, String(by_id(dept_id).get("name", dept_id))], "promo")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}
