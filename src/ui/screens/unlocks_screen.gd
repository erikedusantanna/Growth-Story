class_name UnlocksScreen
extends BaseScreen
## Agência: eventos promovidos e árvore de serviços (o RH tem aba própria).

const TIER_NAMES := {"inicio": "Início", "intermediario": "Intermediário", "avancado": "Avançado", "endgame": "Endgame"}


func build() -> void:
	_build_agency_events()
	var era: Dictionary = Game.era.current()
	content.add_child(header("Serviços", "%d/%d" % [Game.state.unlocked_services.size(), Game.content.service_order.size()]))
	content.add_child(UIKit.muted("Cada segmento de cliente combina melhor com certos serviços. Descubra as combinações perfeitas."))
	if not era.is_empty():
		content.add_child(UIKit.card([
			UIKit.label("🔥 Em alta em %d: %s" % [Game.state.year(), String(era.get("name", ""))], 15, UIKit.COLOR_ACCENT, true),
			UIKit.muted(String(era.get("flavor", "")), 13),
			UIKit.label("Projetos com %s rendem +%d na nota." % [", ".join(Game.era.trending_names()), int(ProjectSystem.BONUS_TRENDING)], 13, UIKit.COLOR_GREEN, true),
		]))
	var last_tier := ""
	for id in Game.content.service_order:
		var svc: Dictionary = Game.content.services[id]
		if svc.get("tier", "") != last_tier:
			last_tier = svc.get("tier", "")
			content.add_child(UIKit.label(TIER_NAMES.get(last_tier, last_tier), 17, UIKit.COLOR_ACCENT))
		content.add_child(_service_card(svc))
	content.add_child(UIKit.spacer(4))
	content.add_child(header("Combinações por segmento"))
	for seg in Game.content.match_table:
		var best: Array = Game.content.match_table[seg].get("best", [])
		var poor: Array = Game.content.match_table[seg].get("poor", [])
		var card := UIKit.card()
		var v := UIKit.card_content(card)
		v.add_child(UIKit.label(Game.content.segment_names.get(seg, seg), 17))
		v.add_child(UIKit.label("Funciona: %s" % ", ".join(best.map(func(s): return Game.content.service_name(s))), 14, UIKit.COLOR_GREEN, true))
		v.add_child(UIKit.label("Evite: %s" % ", ".join(poor.map(func(s): return Game.content.service_name(s))), 14, UIKit.COLOR_RED, true))
		content.add_child(card)


# --- Eventos da agência ----------------------------------------------------------

func _build_agency_events() -> void:
	var st: GameState = Game.state
	content.add_child(header("Eventos da agência"))
	if not Game.agency_events.is_unlocked():
		content.add_child(UIKit.card([UIKit.label("Eventos promovidos pela agência abrem com 40 de reputação.", 15, UIKit.COLOR_TEXT, true),
			UIKit.muted("Palestras, feiras e patrocínios trazem reputação, prospects, candidatos e até patrocínio.", 13)]))
		content.add_child(UIKit.spacer(4))
		return
	for r in st.agency_events:
		var ev := Game.agency_events.event_by_id(String(r.get("id", "")))
		content.add_child(UIKit.label("Em andamento: %s (termina em %d dias)" % [ev.get("name", "?"), int(r.get("ends_day", 0)) - st.day], 14, UIKit.COLOR_BLUE, true))
	for ev in Game.agency_events.events():
		content.add_child(_agency_event_card(ev))
	content.add_child(UIKit.spacer(4))


func _agency_event_card(ev: Dictionary) -> PanelContainer:
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var top := UIKit.hbox()
	var name := UIKit.number(String(ev["name"]), 18, UIKit.COLOR_TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(UIKit.label(UIKit.money(float(ev.get("cost", 0))), 15, UIKit.COLOR_NUMBER))
	v.add_child(top)
	v.add_child(UIKit.muted(String(ev.get("desc", "")), 13))
	var needs: Array = []
	if int(ev.get("people", 0)) > 0:
		needs.append("%d pessoa%s por %d dias" % [int(ev["people"]), "" if int(ev["people"]) == 1 else "s", int(ev.get("days", 0))])
	needs.append("rep %d" % int(ev.get("requires_rep", 0)))
	v.add_child(UIKit.muted("Exige: %s" % " · ".join(needs), 13))
	v.add_child(UIKit.label("Rende: %s" % _agency_effects_text(ev), 13, UIKit.COLOR_GREEN, true))
	var check := Game.agency_events.can_run(ev, [])
	var needs_people := int(ev.get("people", 0)) > 0
	var blocked: bool = not check.ok and not (needs_people and check.reason.begins_with("Escolha"))
	var b := UIKit.button("Escolher equipe e promover" if needs_people else "Promover", func():
		if needs_people:
			popups().show_people_picker(ev)
		else:
			var r := Game.agency_events.run(ev, [])
			if not r.ok:
				popups().show_info("Evento", r.reason), true)
	b.disabled = blocked
	v.add_child(b)
	if blocked:
		v.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	return card


func _agency_effects_text(ev: Dictionary) -> String:
	var fx: Dictionary = ev.get("effects", {})
	var parts: Array = []
	if fx.has("reputation"):
		parts.append("+%d reputação" % int(fx["reputation"]))
	if fx.has("prospects"):
		parts.append("%d prospect(s)%s" % [int(fx["prospects"]), " maiores" if int(fx.get("prospect_tier_bonus", 0)) > 0 else ""])
	if fx.has("candidates"):
		parts.append("%d candidato(s) fortes" % int(fx["candidates"]))
	if fx.has("money"):
		parts.append("patrocínio de %s" % UIKit.money(float(fx["money"])))
	if fx.has("morale"):
		parts.append("+%d moral" % int(fx["morale"]))
	if int(fx.get("delay_days", 0)) > 0:
		parts.append("projetos atrasam %d dia" % int(fx["delay_days"]))
	return ", ".join(parts)


func _service_card(svc: Dictionary) -> PanelContainer:
	var id: String = svc["id"]
	var unlocked := Game.services.is_unlocked(id)
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var top := UIKit.hbox()
	var name := UIKit.label(("🔥 " if Game.era.is_trending(id) else "") + String(svc["name"]), 19, UIKit.COLOR_TEXT if unlocked else UIKit.COLOR_MUTED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(UIKit.label("ativo" if unlocked else "bloqueado", 13, UIKit.COLOR_GREEN if unlocked else UIKit.COLOR_MUTED))
	v.add_child(top)
	var weights: Dictionary = svc.get("weights", {})
	var parts: Array = []
	for key in weights:
		parts.append("%s %d%%" % [Employee.ATTR_NAMES[key], int(float(weights[key]) * 100)])
	v.add_child(UIKit.muted("Usa: %s" % ", ".join(parts), 13))
	if not unlocked:
		var check := Game.services.can_unlock(id)
		var b := UIKit.button("Desbloquear (%s · rep %d)" % [UIKit.money(float(svc.get("unlock_cost", 0))), int(svc.get("rep_required", 0))],
			func(): Game.services.unlock(id), true)
		b.disabled = not check.ok
		v.add_child(b)
		if not check.ok:
			v.add_child(UIKit.label(check.reason, 13, UIKit.COLOR_RED))
	return card
