class_name HRScreen
extends BaseScreen
## RH: contratação da analista, moral da equipe e ações (festas, folgas, sprints, pets).


func build() -> void:
	var st: GameState = Game.state
	content.add_child(header("❤️ RH", "moral média %d" % int(Game.employees.morale_average())))
	if not Game.hr.is_unlocked():
		_build_hire()
		return
	_build_morale()
	if not st.buffs.is_empty():
		var names: Array = st.buffs.map(func(b): return "%s (%d dias)" % [String(b.get("name", b.get("id", ""))), int(b.get("until_day", 0)) - st.day + 1])
		content.add_child(UIKit.label("Efeitos ativos: %s" % ", ".join(names), 14, UIKit.COLOR_BLUE, true))
	content.add_child(UIKit.label("🎉 Ações", 17, UIKit.COLOR_ACCENT))
	for a in Game.hr.actions():
		content.add_child(_hr_card(a))
	content.add_child(UIKit.spacer(4))


## Antes da contratação: o que o RH faz, o que custa e o que precisa.
func _build_hire() -> void:
	var h := Game.hr.hire_data()
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	v.add_child(UIKit.label(String(h.get("name", "Analista de RH")), 19, UIKit.COLOR_TEXT))
	v.add_child(UIKit.label(String(h.get("desc", "")), 15, UIKit.COLOR_TEXT, true))
	v.add_child(UIKit.muted("Cuida da moral da equipe: festas, folgas, programas de bem-estar, sprints com energético e política pet friendly.", 13))
	v.add_child(UIKit.label("Custo: %s para montar a sala + %s/mês de salário" % [UIKit.money(float(h.get("cost", 0))), UIKit.money(float(h.get("salary", 0)))], 14, UIKit.COLOR_NUMBER, true))
	var office_name: String = Game.office.level_data(int(h.get("requires_office", 3))).get("name", "")
	v.add_child(UIKit.muted("Exige: %s · reputação %d" % [office_name, int(h.get("requires_rep", 0))], 13))
	var check := Game.hr.can_hire()
	var b := UIKit.button("❤️ Contratar RH", func():
		var r := Game.hr.hire()
		if r.ok:
			popups().show_info("RH contratado", "A sala de RH foi montada ao lado do escritório. Arraste o escritório para ver a divisória e a nova analista. As ações de RH estão liberadas.")
		else:
			popups().show_info("RH", r.reason), true)
	b.disabled = not check.ok
	v.add_child(b)
	if not check.ok:
		v.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	content.add_child(card)
	_build_morale()


## Moral de cada pessoa, com o teto atual.
func _build_morale() -> void:
	var st: GameState = Game.state
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var cap := Game.office.morale_max()
	v.add_child(UIKit.label("💪 Moral da equipe (teto %d)" % int(cap), 17, UIKit.COLOR_ACCENT))
	for e in st.employees:
		var color := UIKit.COLOR_GREEN
		if e.motivation < 35.0:
			color = UIKit.COLOR_RED
		elif e.motivation < 60.0:
			color = UIKit.COLOR_GOLD
		var row := UIKit.stat_row(e.name.split(" ")[0], e.motivation, color, 90)
		var bar: ProgressBar = row.get_child(1)
		bar.max_value = cap
		v.add_child(row)
	if not st.pets.is_empty():
		var names: Array = st.pets.map(func(p): return "cachorro" if p == "dog" else "gato")
		v.add_child(UIKit.muted("Pets no escritório: %s (+%.1f de moral por dia)" % [", ".join(names), Game.hr.pets_morale_daily()], 13))
	content.add_child(card)


func _hr_card(a: Dictionary) -> PanelContainer:
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var top := UIKit.hbox()
	var name := UIKit.number(String(a["name"]), 18, UIKit.COLOR_TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(UIKit.label(UIKit.money(Game.hr.total_cost(a)), 15, UIKit.COLOR_NUMBER))
	v.add_child(top)
	v.add_child(UIKit.muted(String(a.get("desc", "")), 13))
	v.add_child(UIKit.label(_hr_effects_text(a), 13, UIKit.COLOR_BLUE, true))
	if Game.hr.is_done(a):
		v.add_child(UIKit.label("Já faz parte do escritório.", 13, UIKit.COLOR_GREEN))
		return card
	var check := Game.hr.can_use(a)
	var b := UIKit.button("Adotar" if a.has("pet") else "Fazer", func():
		var r := Game.hr.use(a)
		if not r.ok:
			popups().show_info("RH", r.reason), true)
	b.disabled = not check.ok
	v.add_child(b)
	if not check.ok:
		v.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	return card


func _hr_effects_text(a: Dictionary) -> String:
	var parts: Array = []
	if a.has("morale"):
		parts.append("%s%d moral" % ["+" if float(a["morale"]) > 0 else "", int(a["morale"])])
	if a.has("morale_daily"):
		parts.append("+%.1f moral por dia" % float(a["morale_daily"]))
	if a.has("stress"):
		parts.append("%d estresse" % int(a["stress"]))
	if a.has("loyalty"):
		parts.append("+%d lealdade" % int(a["loyalty"]))
	if int(a.get("delay_days", 0)) > 0:
		parts.append("projetos atrasam %d dias" % int(a["delay_days"]))
	if a.has("buff"):
		var b: Dictionary = a["buff"]
		if b.has("productivity"):
			parts.append("produtividade ×%.1f por %d dias" % [float(b["productivity"]), int(b.get("days", 0))])
		if b.has("stress_rate"):
			parts.append("estresse ×%.1f por %d dias" % [float(b["stress_rate"]), int(b.get("days", 0))])
	if a.has("pet"):
		parts.append("%s permanente no escritório" % ("cachorro" if a["pet"] == "dog" else "gato"))
	elif int(a.get("cooldown_days", 0)) > 0:
		parts.append("a cada %d dias" % int(a.get("cooldown_days", 0)))
	return " · ".join(parts)
