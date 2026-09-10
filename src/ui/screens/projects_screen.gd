class_name ProjectsScreen
extends BaseScreen
## Projetos em execução (indicadores ao vivo) e histórico de entregas.


func _ready() -> void:
	super._ready()
	refresh_daily = true


func build() -> void:
	var st: GameState = Game.state
	var running := st.running_projects()
	content.add_child(header("⚙️ Em execução", "%d" % running.size()))
	if running.is_empty():
		content.add_child(UIKit.muted("Nenhum projeto rodando. Vá em Clientes e inicie um."))
	for p in running:
		content.add_child(_running_card(p))
	content.add_child(UIKit.spacer(4))
	content.add_child(header("📜 Histórico"))
	var done := Game.projects.recent_finished(10)
	if done.is_empty():
		content.add_child(UIKit.muted("Suas campanhas entregues aparecem aqui."))
	for p in done:
		content.add_child(_done_card(p))


func _running_card(p: Project) -> PanelContainer:
	var st: GameState = Game.state
	var c: Client = st.client_by_id(p.client_id)
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var top := UIKit.hbox()
	var title := UIKit.label(p.title, 19)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(UIKit.label(ServiceSystem.MATCH_NAMES.get(p.match_quality, ""), 13, UIKit.match_color(p.match_quality)))
	v.add_child(top)
	v.add_child(UIKit.muted("%s · %s" % [c.name if c != null else "?", UIKit.money(p.budget) + ("/mês" if p.kind == Project.Kind.RETAINER else "")]))
	var services: Array = p.services.map(func(s): return Game.content.service_name(s))
	v.add_child(UIKit.muted("Serviços: %s" % ", ".join(services), 13))
	var team_names: Array = Game.projects.team_members(p).map(func(e): return e.name.split(" ")[0])
	v.add_child(UIKit.muted("Equipe: %s" % (", ".join(team_names) if not team_names.is_empty() else "ninguém!"), 13))
	var days_color := UIKit.COLOR_RED if p.is_late() else UIKit.COLOR_MUTED
	var days := UIKit.hbox(14)
	days.add_child(UIKit.label("Dia %d de %d" % [p.days_elapsed, p.deadline_days], 14, days_color))
	days.add_child(UIKit.label("Previsão: %d dias" % Game.projects.estimated_days(p), 14, UIKit.COLOR_MUTED))
	if p.kind == Project.Kind.RETAINER:
		days.add_child(UIKit.label("%d meses restantes" % p.months_left, 14, UIKit.COLOR_GREEN))
	v.add_child(days)
	v.add_child(UIKit.stat_row("Progresso", p.progress() * 100.0, UIKit.COLOR_TEXT))
	for key in Project.INDICATORS:
		var row := UIKit.stat_row(Project.INDICATOR_NAMES[key], p.indicators[key], UIKit.indicator_color(key))
		row.add_child(UIKit.icon("ind_" + key))
		row.move_child(row.get_child(row.get_child_count() - 1), 0)
		v.add_child(row)
	if p.addresses_problem:
		v.add_child(UIKit.label("🎯 A estratégia ataca o problema real do cliente.", 13, UIKit.COLOR_GREEN))
	v.add_child(UIKit.button("🗑️ Cancelar projeto", func(): _confirm_cancel(p)))
	return card


func _confirm_cancel(p: Project) -> void:
	popups().show_choice("🗑️ Cancelar %s?" % p.title, "O cliente não paga nada e perde confiança na agência.",
		["🗑️ Cancelar projeto", "↩️ Voltar"], func(i: int):
			if i == 0:
				var c: Client = Game.state.client_by_id(p.client_id)
				Game.projects.cancel(p)
				if c != null:
					c.relationship = clampf(c.relationship - 20.0, 0.0, 100.0)
				Game.reputation.add(-2.0))


func _done_card(p: Project) -> PanelContainer:
	var c: Client = Game.state.client_by_id(p.client_id)
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	var top := UIKit.hbox()
	var title := UIKit.label("%s · %s" % [c.name if c != null else "?", p.title], 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(title)
	if p.status == Project.Status.CANCELLED:
		top.add_child(UIKit.label("❌ cancelado", 14, UIKit.COLOR_RED))
	else:
		top.add_child(UIKit.star_row(int(p.result.get("stars", 0)), 2))
	v.add_child(top)
	if p.status != Project.Status.CANCELLED:
		v.add_child(UIKit.muted("💰 %s · ROI %.1fx · %s" % [UIKit.money(float(p.result.get("payment", 0))), float(p.result.get("roi", 0)), ServiceSystem.MATCH_NAMES.get(p.match_quality, "")], 13))
	return card
