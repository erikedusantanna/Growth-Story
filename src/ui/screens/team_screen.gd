class_name TeamScreen
extends BaseScreen
## Equipe: funcionários, treinamento, demissão e candidatos.


func build() -> void:
	var st: GameState = Game.state
	content.add_child(header("👥 Equipe", "%d/%d lugares · moral média %d" % [st.employees.size(), Game.office.capacity(), int(Game.employees.morale_average())]))
	content.add_child(_office_banner())
	if Game.departments.is_unlocked():
		content.add_child(_departments_overview())
	for e in st.employees:
		content.add_child(_employee_card(e))
	content.add_child(UIKit.spacer(4))
	content.add_child(header("📋 Candidatos", "%d disponíveis" % st.candidates.size()))
	if st.candidates.is_empty():
		content.add_child(UIKit.muted("Nenhum candidato no momento. Novos currículos chegam todo mês."))
	for c in st.candidates:
		content.add_child(_candidate_card(c))


## Faixa do escritório: mostra lotação e o caminho para ampliar sem precisar achar a aba Empresa.
func _office_banner() -> PanelContainer:
	var st: GameState = Game.state
	var office := Game.office.current()
	var full: bool = st.employees.size() >= Game.office.capacity()
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var top := UIKit.hbox()
	var name := UIKit.label("%s · %d/%d lugares" % [office.get("name", ""), st.employees.size(), Game.office.capacity()], 16, UIKit.COLOR_RED if full else UIKit.COLOR_MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	v.add_child(top)
	var nxt := Game.office.next_level()
	if nxt.is_empty():
		var region_now: int = Game.office.region()
		if region_now < Game.office.regions().size():
			var next_region: Dictionary = Game.office.region_data(region_now + 1)
			v.add_child(UIKit.label("Tamanho máximo nesta região. Próximo passo: mudar a sede para %s (%s · reputação %d) pelo mapa 🌎." % [
				String(next_region.get("name", "")), UIKit.money(float(next_region.get("move_cost", 0))), int(next_region.get("rep_required", 0))], 13, UIKit.COLOR_ACCENT, true))
		else:
			v.add_child(UIKit.muted("Você já está no maior escritório disponível.", 13))
		return card
	if full:
		v.add_child(UIKit.label("Escritório lotado. Amplie para contratar mais gente.", 14, UIKit.COLOR_RED, true))
	var check := Game.office.can_upgrade()
	v.add_child(UIKit.muted("Próximo: %s · %d lugares · rep %d" % [nxt.name, int(nxt.capacity), int(nxt.rep_required)], 13))
	var b := UIKit.button("🏗️ Ampliar por %s" % UIKit.money(float(nxt.upgrade_cost)), func():
		if Game.office.upgrade():
			popups().show_info("Ampliação feita!", "O escritório agora é %s. Cabem %d pessoas. O aluguel passa a %s/mês." % [nxt.name, int(nxt.capacity), UIKit.money(float(nxt.rent) * Game.state.rent_modifier)]), full)
	b.disabled = not check.ok
	v.add_child(b)
	if not check.ok:
		v.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	else:
		v.add_child(UIKit.muted("Aluguel passa a %s/mês." % UIKit.money(float(nxt.rent) * st.rent_modifier), 13))
	return card


## Visão geral dos departamentos: quem está em cada um e se o bônus de produtividade está ativo.
func _departments_overview() -> PanelContainer:
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	v.add_child(UIKit.label("🏢 Departamentos", 17, UIKit.COLOR_ACCENT))
	v.add_child(UIKit.muted("Gerente + %d pessoas no mesmo departamento rendem +%d%% de produtividade para todos ali." %
		[int(Game.content.departments.get("min_members_for_bonus", 2)), int(float(Game.content.departments.get("productivity_bonus", 0.08)) * 100)], 13))
	for d in Game.departments.all():
		var members: Array = Game.departments.members(d.id)
		if members.is_empty():
			continue
		var row := UIKit.hbox(8)
		var active := Game.departments.has_bonus(d.id)
		row.add_child(UIKit.label(String(d.name), 14, UIKit.COLOR_GREEN if active else UIKit.COLOR_TEXT, false))
		var names: Array = members.map(func(m): return m.name.split(" ")[0])
		row.add_child(UIKit.muted("%s%s" % [", ".join(names), " · bônus ativo" if active else ""], 13))
		v.add_child(row)
	return card


## Linha com o departamento atual e um botão para trocar (popup de escolha).
func _department_row(e: Employee) -> HBoxContainer:
	var row := UIKit.hbox(8)
	var dept: Dictionary = Game.departments.by_id(e.department)
	var label_text: String = "🏢 %s" % String(dept.get("name", "Sem departamento"))
	row.add_child(UIKit.label(label_text, 14, UIKit.COLOR_ACCENT if not dept.is_empty() else UIKit.COLOR_MUTED))
	if not dept.is_empty() and e.career_level >= DepartmentSystem.MANAGER_CAREER_LEVEL:
		row.add_child(UIKit.label("(gerente)", 13, UIKit.COLOR_GOLD))
	var b := UIKit.button("Trocar", func(): _pick_department(e), false, 32)
	b.size_flags_horizontal = 0
	b.custom_minimum_size.x = 80
	row.add_child(b)
	return row


func _pick_department(e: Employee) -> void:
	var depts: Array = Game.departments.all()
	var labels: Array = ["Sem departamento"]
	var ids: Array = [""]
	for d in depts:
		labels.append(String(d.name))
		ids.append(String(d.id))
	popups().show_choice("Departamento de %s" % e.name.split(" ")[0], "Cada departamento reforça um atributo do time. Um gerente (carreira Gerente ou acima) mais gente no mesmo departamento rende bônus de produtividade.",
		labels, func(idx): Game.departments.assign(e, ids[idx]))


func _employee_card(e: Employee) -> PanelContainer:
	var st: GameState = Game.state
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var status := e.is_busy_reason(st.day)
	var status_color := UIKit.COLOR_GREEN if status == "Livre" else (UIKit.COLOR_RED if status == "Burnout" else UIKit.COLOR_ACCENT)
	v.add_child(_person_header(e, status, status_color))
	v.add_child(UIKit.attr_grid(e))
	var morale_row := UIKit.stat_row("Moral", e.motivation, UIKit.COLOR_GREEN if e.motivation >= 50 else UIKit.COLOR_RED, 60)
	var morale_bar: ProgressBar = morale_row.get_child(1)
	morale_bar.max_value = Game.office.morale_max()
	v.add_child(morale_row)
	var mood := Game.employees.mood_of(e, st.day)
	var pressures: Array = Game.employees.morale_pressures(e)
	if mood != "" or not pressures.is_empty():
		var parts: Array = []
		if mood != "":
			parts.append(Game.employees.mood_label(mood))
		if not pressures.is_empty():
			parts.append("pesa: " + ", ".join(pressures.map(func(pr): return "%s (−%.2f/dia)" % [pr.text, float(pr.per_day)])))
		var mood_color := UIKit.COLOR_RED if mood in ["burnout", "sad", "exhausted"] or not pressures.is_empty() else UIKit.COLOR_GREEN
		v.add_child(UIKit.label(" · ".join(parts), 13, mood_color, true))
	var meta := UIKit.hbox(14)
	meta.add_child(UIKit.label("Teto de moral %d" % int(Game.office.morale_max()), 14, UIKit.COLOR_MUTED))
	meta.add_child(UIKit.label("Estresse %d" % int(e.stress), 14, UIKit.COLOR_RED if e.stress > 70 else UIKit.COLOR_MUTED))
	meta.add_child(UIKit.label("Potencial", 14, UIKit.COLOR_MUTED))
	meta.add_child(UIKit.star_row(e.potential, 2))
	v.add_child(meta)
	var meta2 := UIKit.hbox(14)
	meta2.add_child(UIKit.label("Salário %s/mês" % UIKit.money(e.salary), 14, UIKit.COLOR_MUTED))
	meta2.add_child(UIKit.label("XP %d" % int(e.experience), 14, UIKit.COLOR_MUTED))
	v.add_child(meta2)
	if Game.departments.is_unlocked():
		v.add_child(_department_row(e))
	var actions := UIKit.hbox()
	var train := UIKit.button("📚 Treinar", func(): popups().show_training(e))
	train.disabled = not e.is_available(st.day)
	actions.add_child(train)
	actions.add_child(UIKit.button("🗺️ Jornada", func(): popups().show_journey(e)))
	if not e.is_founder:
		var raise_check := Game.employees.can_give_raise(e)
		var raise_btn := UIKit.button("💰 Aumento +%d%%" % int(EmployeeSystem.RAISE_FRACTION * 100.0), func():
			var r := Game.employees.raise_by_player(e)
			if not r.ok:
				popups().show_info("Aumento", r.reason))
		raise_btn.disabled = not raise_check.ok
		raise_btn.tooltip_text = raise_check.reason if not raise_check.ok else "Zera a pressão de salário defasado; moral +10"
		actions.add_child(raise_btn)
		actions.add_child(UIKit.button("👋 Demitir", func(): _confirm_fire(e)))
	v.add_child(actions)
	return card


## Retrato + nome em negrito + cargo + personalidade, como o cartão das referências.
func _person_header(e: Employee, right_text: String, right_color: Color) -> HBoxContainer:
	var h := UIKit.hbox(12)
	h.add_child(UIKit.portrait(e, 4))
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := UIKit.hbox()
	var name := UIKit.number(e.name, 19, UIKit.COLOR_TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name)
	top.add_child(UIKit.label(right_text, 14, right_color))
	v.add_child(top)
	v.add_child(UIKit.label(Game.employees.title(e), 15, UIKit.COLOR_MUTED))
	v.add_child(UIKit.label("%s · %s" % [Game.employees.personality_name(e), Game.content.personalities.get(e.personality, {}).get("desc", "")], 13, UIKit.COLOR_BLUE, true))
	var partners: Dictionary = Game.chemistry.partners_for(e.personality)
	var parts: Array = []
	if not partners.synergy.is_empty():
		parts.append("🤝 combina com %s" % ", ".join(partners.synergy))
	if not partners.friction.is_empty():
		parts.append("⚡ atrito com %s" % ", ".join(partners.friction))
	if not parts.is_empty():
		v.add_child(UIKit.label(" · ".join(parts), 12, UIKit.COLOR_MUTED, true))
	h.add_child(v)
	return h


func _confirm_fire(e: Employee) -> void:
	popups().show_choice("👋 Demitir %s?" % e.name,
		"A rescisão custa um salário (%s). A equipe pode perder motivação." % UIKit.money(e.salary),
		["👋 Demitir", "✖️ Cancelar"],
		func(i: int):
			if i == 0:
				Game.employees.fire(e)
				for other in Game.state.employees:
					other.motivation = clampf(other.motivation - 4.0, 0.0, 100.0))


func _candidate_card(c: Employee) -> PanelContainer:
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	v.add_child(_person_header(c, "%d anos" % c.age, UIKit.COLOR_MUTED))
	v.add_child(UIKit.attr_grid(c))
	var meta := UIKit.hbox(14)
	meta.add_child(UIKit.label("Salário %s/mês" % UIKit.money(c.salary), 15, UIKit.COLOR_GREEN))
	meta.add_child(UIKit.label("Potencial", 14, UIKit.COLOR_MUTED))
	meta.add_child(UIKit.star_row(c.potential, 2))
	v.add_child(meta)
	v.add_child(UIKit.muted("Sai da lista em %d dias" % maxi(0, c.candidate_expires - Game.state.day), 13))
	var actions := UIKit.hbox()
	var check := Game.employees.can_hire(c)
	var hire := UIKit.button("✅ Contratar", func():
		var r := Game.employees.hire(c)
		if not r.ok:
			popups().show_info("Não foi possível contratar", r.reason), true)
	hire.disabled = not check.ok
	hire.tooltip_text = check.reason
	hire.set_meta("tutorial", "hire")
	actions.add_child(hire)
	actions.add_child(UIKit.button("✖️ Recusar", func(): Game.employees.decline(c)))
	v.add_child(actions)
	if not check.ok:
		v.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	return card
