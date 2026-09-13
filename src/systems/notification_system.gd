class_name NotificationSystem
extends RefCounted
## Central de notificações: o assistente da agência.
##
## O jogo acumula coisas pedindo atenção ao mesmo tempo — prospect esperando resposta, currículo
## novo, projeto sem equipe, prazo de missão estourando, parcela do banco, caixa no vermelho — e
## dá para passar por tudo isso sem ver. Este sistema **não guarda estado**: ele lê os outros
## sistemas e monta a lista do que precisa de você agora, ordenada pela urgência.
##
## Cada item é `{id, icon, title, detail, urgency, screen}`:
##   urgency 2 = age agora (vermelho) · 1 = atenção (laranja) · 0 = informativo
##   screen    = aba para onde o toque leva ("clients", "team", …) ou "" / "map" / "bank"

const URGENT := 2
const WARN := 1
const INFO := 0

var game


func setup(g) -> void:
	game = g


func _item(id: String, icon: String, title: String, detail: String, urgency: int, screen: String) -> Dictionary:
	return {"id": id, "icon": icon, "title": title, "detail": detail, "urgency": urgency, "screen": screen}


## Tudo o que está pedindo atenção, do mais urgente para o menos.
func items() -> Array:
	if game.state == null:
		return []
	var st: GameState = game.state
	var out: Array = []
	_finance(out)
	_clients(out)
	_people(out)
	_projects(out)
	_quests(out)
	_office(out)
	out.sort_custom(func(a, b): return int(a.urgency) > int(b.urgency))
	return out


func urgent_count() -> int:
	return items().filter(func(i): return int(i.urgency) >= WARN).size()


func count() -> int:
	return items().size()


# --- Fontes ---------------------------------------------------------------------------

func _finance(out: Array) -> void:
	var st: GameState = game.state
	var status: Dictionary = game.finance.status()
	var level: int = int(status.get("level", 0))
	if level >= 2:
		out.append(_item("caixa", "🚨" if level >= 3 else "⚠️", "Caixa no vermelho",
			"Faltam %s para o limite de falência (%s)." % [
				FinanceSystem.format_money(float(status.get("room", 0))),
				FinanceSystem.format_money(FinanceSystem.BANKRUPT_AT)],
			URGENT if level >= 3 else WARN, "company"))
	elif level == 1:
		out.append(_item("caixa", "🟡", "Caixa negativo",
			"Dá para segurar, mas o jogo acaba em %s." % FinanceSystem.format_money(FinanceSystem.BANKRUPT_AT),
			INFO, "company"))
	for loan in game.bank.active():
		if int(loan.get("months_left", 0)) <= 1:
			out.append(_item("emprestimo", "🏦", "Última parcela do empréstimo",
				"Sai %s no próximo fechamento." % FinanceSystem.format_money(float(loan.get("installment", 0))), INFO, "map"))
	if st.money < game.finance.monthly_costs().total_with_loans and game.bank.is_available() and game.bank.active().is_empty():
		out.append(_item("banco", "🏦", "O banco pode cobrir o mês",
			"O caixa não cobre o custo fixo do próximo fechamento.", WARN, "map"))


func _clients(out: Array) -> void:
	var st: GameState = game.state
	var prospects: Array = st.prospects()
	if not prospects.is_empty():
		out.append(_item("prospects", "🤝", "%d prospect(s) esperando" % prospects.size(),
			"Envie a proposta ou dispense — prospect esquecido vai para a concorrência.", WARN, "clients"))
	var undiagnosed: Array = st.active_clients().filter(func(c): return not c.diagnosed and c.diagnosis_days_left == 0)
	if not undiagnosed.is_empty():
		out.append(_item("diagnostico", "🔍", "%d cliente(s) sem diagnóstico" % undiagnosed.size(),
			"Diagnosticar antes de vender melhora a nota da entrega.", INFO, "clients"))
	for c in st.active_clients():
		if game.calendar.can_send_gift(c).ok:
			out.append(_item("aniversario", "🎁", "Aniversário de contrato: %s" % c.name,
				"Um presente agora melhora a relação.", INFO, "company"))


func _people(out: Array) -> void:
	var st: GameState = game.state
	if st.new_candidates > 0:
		out.append(_item("candidatos", "📄", "%d currículo(s) novo(s)" % st.new_candidates,
			"Chegou gente para a equipe. Veja antes que o prazo deles acabe.", WARN, "team"))
	var talent = game.talent.active()
	if talent != null:
		var days: int = talent.candidate_expires - st.day
		out.append(_item("talento", "⭐", "Talento raro no mercado",
			"%s sai em %d dia(s) — se você não fechar, uma rival fecha." % [talent.name, maxi(days, 0)],
			URGENT if days <= 4 else WARN, "team"))
	var burned: Array = st.employees.filter(func(e): return e.stress >= 85.0)
	if not burned.is_empty():
		out.append(_item("estresse", "🔥", "%d pessoa(s) no limite" % burned.size(),
			"Estresse acima de 85. Uma ação de RH ou folga evita o burnout.", WARN, "hr" if game.hr.is_unlocked() else "team"))
	var idle: Array = st.employees.filter(func(e): return e.project_id == -1 and e.is_available(st.day) and e.idle_days >= 10)
	if not idle.is_empty():
		out.append(_item("parados", "💤", "%d pessoa(s) sem projeto" % idle.size(),
			"Há mais de 10 dias sem trabalho. A moral cai e o salário continua saindo.", INFO, "projects"))


func _projects(out: Array) -> void:
	var st: GameState = game.state
	for p in st.running_projects():
		var c: Client = st.client_by_id(p.client_id)
		var name: String = c.name if c != null else "cliente"
		if p.team.is_empty():
			out.append(_item("sem_equipe_%d" % p.id, "🚧", "Projeto sem equipe: %s" % p.title,
				"Ninguém alocado — o prazo corre do mesmo jeito.", URGENT, "projects"))
			continue
		if p.kind == Project.Kind.RETAINER:
			continue
		var left: int = p.deadline_days - p.days_elapsed
		if left <= 3:
			out.append(_item("prazo_%d" % p.id, "⏳", "Prazo apertado: %s" % p.title,
				"%s · %d dia(s) para entregar." % [name, maxi(left, 0)], URGENT if left <= 1 else WARN, "projects"))
	var ready: Array = st.active_clients().filter(func(c): return c.diagnosed and not st.running_projects().any(func(p): return p.client_id == c.id))
	if not ready.is_empty():
		out.append(_item("sem_projeto", "📣", "%d cliente(s) sem projeto" % ready.size(),
			"Cliente ativo parado não gera receita.", INFO, "clients"))


func _quests(out: Array) -> void:
	var st: GameState = game.state
	for q in game.quests.active():
		var t: Dictionary = game.quests.template(String(q.get("id", "")))
		var left: int = game.quests.days_left(q)
		if left <= 7 and not game.quests.is_done(q):
			out.append(_item("missao_%s" % String(q.get("id", "")), String(t.get("icon", "📜")),
				"Missão acaba em %d dia(s)" % maxi(left, 0),
				"%s · %s" % [String(t.get("title", "")), game.quests.progress_text(q)],
				URGENT if left <= 2 else WARN, "company"))
	if game.crisis.is_active():
		out.append(_item("crise", "⚠️", game.crisis.headline(),
			"A região inteira está afetada. Produtividade e prospects caem enquanto durar.", WARN, "company"))


func _office(out: Array) -> void:
	var st: GameState = game.state
	if st.employees.size() >= game.office.capacity() and game.office.can_upgrade().ok:
		out.append(_item("lotado", "🏢", "Escritório lotado",
			"Não cabe mais ninguém. Ampliar libera %d lugares." % game.office.capacity(), INFO, "company"))
	if game.hr.is_unlocked() or not game.hr.can_hire().ok:
		return
	out.append(_item("rh", "❤️", "Dá para contratar o RH",
		"Libera as ações de moral, estresse e as políticas pet friendly.", INFO, "hr"))
