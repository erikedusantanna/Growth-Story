class_name ClientsScreen
extends BaseScreen
## Clientes: prospects para fechar e clientes ativos para diagnosticar/iniciar projetos.

const SEGMENT_ICONS := {
	"alimentacao": "🍕", "varejo": "🛍️", "servicos": "✂️", "tecnologia": "💻",
	"fashion": "👗", "industria": "🏭", "saude": "🏥", "imobiliario": "🏠",
}


func build() -> void:
	var st: GameState = Game.state
	var prospects := st.prospects()
	content.add_child(header("🔎 Prospects", "até tier %d" % Game.clients.max_tier()))
	if prospects.is_empty():
		content.add_child(UIKit.muted("Nenhum prospect agora. Novos aparecem com o tempo e com reputação."))
	for c in prospects:
		content.add_child(_prospect_card(c))
	content.add_child(UIKit.spacer(4))
	var actives := st.active_clients()
	content.add_child(header("🤝 Clientes ativos", "%d" % actives.size()))
	if actives.is_empty():
		content.add_child(UIKit.muted("Feche um contrato para começar a trabalhar."))
	for c in actives:
		content.add_child(_active_card(c))


func _client_header(c: Client, v: VBoxContainer) -> void:
	var top := UIKit.hbox()
	var name := UIKit.label("%s %s" % [SEGMENT_ICONS.get(c.segment, "🏢"), c.name], 20)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name)
	top.add_child(UIKit.label("Tier %d" % c.tier, 14, UIKit.COLOR_ACCENT))
	v.add_child(top)
	v.add_child(UIKit.muted("%s · %s · Expectativa %s" % [Game.clients.segment_name(c), Game.clients.personality_name(c), c.expectation]))
	v.add_child(UIKit.label("\"%s\"" % c.goal, 15, UIKit.COLOR_TEXT, true))


func _prospect_card(c: Client) -> PanelContainer:
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	_client_header(c, v)
	v.add_child(UIKit.muted("Orçamento de referência: %s/mês" % UIKit.money(c.budget)))
	var chance := Game.clients.proposal_chance(c)
	var actions := UIKit.hbox()
	var propose := UIKit.button("🤝 Proposta (%d%%)" % int(chance), func(): popups().show_proposal(c), true)
	propose.set_meta("tutorial", "proposal")
	actions.add_child(propose)
	actions.add_child(UIKit.button("✖️ Dispensar", func(): Game.clients.drop_prospect(c)))
	v.add_child(actions)
	if c.proposal_attempts > 0:
		v.add_child(UIKit.label("Tentativas: %d de 3" % c.proposal_attempts, 13, UIKit.COLOR_RED))
	return card


func _active_card(c: Client) -> PanelContainer:
	var st: GameState = Game.state
	var card := UIKit.card()
	var v := UIKit.card_content(card)
	_client_header(c, v)
	var meta := UIKit.hbox(14)
	meta.add_child(UIKit.heart_row(c.satisfaction))
	meta.add_child(UIKit.label("Projetos: %d" % c.projects_done, 14, UIKit.COLOR_MUTED))
	var pct := int(roundf((c.price_factor - 1.0) * 100.0))
	meta.add_child(UIKit.label("Orçamento %s/mês%s" % [UIKit.money(c.budget), (" (%s%d%%)" % ["+" if pct >= 0 else "", pct]) if pct != 0 else ""], 14, UIKit.COLOR_MUTED))
	v.add_child(meta)
	v.add_child(UIKit.stat_row("Relação", c.relationship, UIKit.COLOR_GREEN))
	if c.diagnosed:
		v.add_child(UIKit.label("Problema real: %s" % Game.clients.problem_name(c), 15, UIKit.COLOR_ACCENT, true))
	elif c.diagnosis_days_left > 0:
		v.add_child(UIKit.label("Diagnóstico em andamento (%d dias)" % c.diagnosis_days_left, 15, UIKit.COLOR_BLUE))
	else:
		v.add_child(UIKit.muted("Problema real: ??? (faça um diagnóstico para descobrir)"))
	var running := st.project_for_client(c.id)
	var actions := UIKit.hbox()
	if not c.diagnosed and c.diagnosis_days_left == 0:
		var diag := UIKit.button("🔍 Diagnóstico (%s, %d dias)" % [UIKit.money(Game.clients.diagnosis_cost(c)), Game.clients.diagnosis_days(c)], func():
			var r := Game.clients.start_diagnosis(c)
			if not r.ok:
				popups().show_info("Diagnóstico", r.reason))
		diag.set_meta("tutorial", "diagnosis")
		actions.add_child(diag)
	if running == null:
		var new_project := UIKit.button("📣 Novo projeto", func(): popups().show_new_project(c), true)
		new_project.set_meta("tutorial", "new_project")
		actions.add_child(new_project)
	v.add_child(actions)
	if running != null:
		v.add_child(UIKit.label("Em andamento: %s (%d%%)" % [running.title, int(running.progress() * 100)], 14, UIKit.COLOR_BLUE))
	if c.retainer_months_left > 0:
		v.add_child(UIKit.label("Retainer: %d meses restantes" % c.retainer_months_left, 14, UIKit.COLOR_GREEN))
	elif Game.clients.retainer_available(c):
		v.add_child(UIKit.label("Retainer disponível! Escolha em Novo projeto.", 14, UIKit.COLOR_GREEN))
	return card
