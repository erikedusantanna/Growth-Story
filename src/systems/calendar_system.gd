class_name CalendarSystem
extends RefCounted
## Agenda da agência: junta num só lugar tudo que já tem data marcada (datas comemorativas,
## fechamento do mês, Prêmios do Marketing, prazos de projeto e de missão, leads de mídia paga,
## fim da semana de mudança, liberação da investida contra rivais) e acrescenta duas mecânicas
## simples próprias: aniversário de contrato dos clientes (com presente) e o foco do mês.

const GIFT_WINDOW := 3                 # dias antes/depois do aniversário em que dá para mandar o presente
const GIFT_RELATIONSHIP := 12.0
const GIFT_COST_PER_TIER := 500.0

## Foco do mês: escolhido uma vez por mês, vale até o mês virar.
const FOCUS := [
	{"id": "vendas", "icon": "🤝", "name": "Foco em vendas", "desc": "+8 pontos de chance nas propostas; prospects aparecem com mais frequência."},
	{"id": "entrega", "icon": "📣", "name": "Foco em entrega", "desc": "+6% de produtividade nos projetos."},
	{"id": "gente", "icon": "❤️", "name": "Foco em gente", "desc": "Estresse sobe 25% mais devagar e a moral ganha +0,1 por dia."},
	{"id": "caixa", "icon": "💰", "name": "Foco em caixa", "desc": "Ferramentas e aluguel saem 10% mais baratos no mês."},
]

var game


func setup(g) -> void:
	game = g


# --- Foco do mês ---------------------------------------------------------------------------

func focus() -> Dictionary:
	var st: GameState = game.state
	if int(st.focus.get("month_index", -1)) != st.month_index():
		return {}
	return focus_by_id(String(st.focus.get("id", "")))


func focus_by_id(id: String) -> Dictionary:
	for f in FOCUS:
		if String(f["id"]) == id:
			return f
	return {}


func has_focus(id: String) -> bool:
	return String(focus().get("id", "")) == id


func set_focus(id: String) -> Dictionary:
	if focus_by_id(id).is_empty():
		return {"ok": false, "reason": "Foco desconhecido."}
	var st: GameState = game.state
	if not focus().is_empty():
		return {"ok": false, "reason": "O foco deste mês já foi definido."}
	st.focus = {"id": id, "month_index": st.month_index()}
	game.add_log("%s %s definido para %s." % [String(focus_by_id(id).get("icon", "📅")), String(focus_by_id(id).get("name", "")), st.date_text().substr(3)], "unlock")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


# --- Aniversário de contrato ----------------------------------------------------------------

## Dia do próximo aniversário de contrato do cliente (1 ano de casa, depois a cada ano).
func anniversary_day(c: Client) -> int:
	var st: GameState = game.state
	var years: int = maxi(1, (st.day - c.known_on) / 360 + (1 if (st.day - c.known_on) % 360 > 0 else 0))
	return c.known_on + years * 360


func gift_cost(c: Client) -> float:
	return GIFT_COST_PER_TIER * float(c.tier) + 500.0


func can_send_gift(c: Client) -> Dictionary:
	var st: GameState = game.state
	if not c.is_active():
		return {"ok": false, "reason": "O cliente não está ativo."}
	if int(st.gifts_sent.get(str(c.id), -9999)) > st.day - 300:
		return {"ok": false, "reason": "Presente já enviado neste aniversário."}
	if absi(anniversary_day(c) - st.day) > GIFT_WINDOW and absi(anniversary_day(c) - 360 - st.day) > GIFT_WINDOW:
		return {"ok": false, "reason": "Só na semana do aniversário do contrato."}
	if st.money < gift_cost(c):
		return {"ok": false, "reason": "Caixa insuficiente."}
	return {"ok": true, "reason": ""}


func send_gift(c: Client) -> Dictionary:
	var check := can_send_gift(c)
	if not check.ok:
		return check
	var st: GameState = game.state
	game.finance.add_money(-gift_cost(c), "Presente de aniversário: %s" % c.name, "expense")
	c.relationship = clampf(c.relationship + GIFT_RELATIONSHIP, 0.0, 100.0)
	st.gifts_sent[str(c.id)] = st.day
	game.reputation.add(1.0)
	game.add_log("🎁 Presente de aniversário para %s: a relação melhorou." % c.name, "client")
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


# --- Agenda ---------------------------------------------------------------------------------

## Tudo que está marcado dos próximos `days` dias: [{day, icon, title, detail, kind}] em ordem.
func upcoming(days: int = 120) -> Array:
	var st: GameState = game.state
	var out: Array = []
	var limit: int = st.day + days

	# fechamento do mês (só os dois próximos, para não entupir a lista) e datas comemorativas
	var month_end: int = (st.month_index() + 1) * GameState.DAYS_PER_MONTH
	var closings := 0
	while month_end <= limit:
		var mi: int = month_end / GameState.DAYS_PER_MONTH
		var costs: Dictionary = game.finance.monthly_costs()
		closings += 1
		if closings <= 2:
			out.append({"day": month_end, "icon": "💰", "kind": "money",
				"title": "Fechamento do mês", "detail": "Salários, aluguel e ferramentas: %s" % FinanceSystem.format_money(float(costs.total))})
		var theme: Dictionary = game.seasons.theme_for_month(mi % GameState.MONTHS_PER_YEAR)
		if not theme.is_empty():
			out.append({"day": month_end, "icon": String(theme.get("icon", "🎉")), "kind": "season",
				"title": String(theme.get("name", "")), "detail": "Decoração nova no escritório."})
		if mi % GameState.MONTHS_PER_YEAR == 0:
			out.append({"day": month_end, "icon": "🏆", "kind": "award",
				"title": "Prêmios do Marketing", "detail": "A premiação do ano que fecha."})
		month_end += GameState.DAYS_PER_MONTH

	# prazos de projeto
	for p in st.running_projects():
		var c: Client = st.client_by_id(p.client_id)
		var due: int = p.started_on + (ProjectSystem.RETAINER_CYCLE_DAYS if p.kind == Project.Kind.RETAINER else p.deadline_days)
		if due <= limit:
			out.append({"day": due, "icon": "📣", "kind": "project",
				"title": ("Ciclo do retainer: %s" if p.kind == Project.Kind.RETAINER else "Prazo: %s") % p.title,
				"detail": "%s · %d%% concluído" % [c.name if c != null else "", int(p.progress() * 100)]})

	# missões
	for q in game.quests.active():
		var t: Dictionary = game.quests.template(String(q.get("id", "")))
		out.append({"day": int(q.get("deadline_day", 0)), "icon": String(t.get("icon", "📜")), "kind": "quest",
			"title": "Missão: %s" % String(t.get("title", "")), "detail": "%s · vale %s" % [game.quests.progress_text(q), game.quests.reward_text(t)]})

	# leads de mídia paga
	for camp in st.campaigns:
		out.append({"day": int(camp.get("arrive_day", 0)), "icon": "📣", "kind": "client",
			"title": "Lead da mídia paga", "detail": "Um prospect novo chega neste dia."})

	# aniversários de contrato
	for c in st.active_clients():
		var day := anniversary_day(c)
		if day <= limit:
			var years: int = maxi(1, (day - c.known_on) / 360)
			out.append({"day": day, "icon": "🎁", "kind": "client",
				"title": "Aniversário de contrato: %s" % c.name,
				"detail": "%d ano(s) de casa. Um presente melhora a relação." % years})

	# semana de mudança
	if game.office.is_moving():
		out.append({"day": st.moving_until_day, "icon": "🚚", "kind": "office",
			"title": "Fim da semana de mudança", "detail": "A produtividade volta ao normal."})

	# investida contra rivais
	if not game.competitors.active_rivals().is_empty():
		var ready: int = st.last_raid_day + int(game.content.competitors.get("raid_cooldown_days", 90))
		if ready > st.day and ready <= limit:
			out.append({"day": ready, "icon": "⚔️", "kind": "rival",
				"title": "Investida liberada", "detail": "Dá para propor a um cliente ou contratar alguém de uma rival."})

	out.sort_custom(func(a, b): return int(a["day"]) < int(b["day"]))
	return out


## Marcadores por mês (12 meses a partir do mês atual), para o grid do calendário.
func month_markers() -> Array:
	var st: GameState = game.state
	var out: Array = []
	for k in GameState.MONTHS_PER_YEAR:
		var mi: int = st.month_index() + k
		var icons: Array = []
		var theme: Dictionary = game.seasons.theme_for_month(mi % GameState.MONTHS_PER_YEAR)
		if not theme.is_empty():
			icons.append(String(theme.get("icon", "🎉")))
		if mi % GameState.MONTHS_PER_YEAR == 11:
			icons.append("🏆")
		out.append({"month_index": mi, "month": mi % GameState.MONTHS_PER_YEAR,
			"year": GameState.START_YEAR + mi / GameState.MONTHS_PER_YEAR, "icons": icons,
			"name": GameState.MONTH_NAMES[mi % GameState.MONTHS_PER_YEAR]})
	return out


func on_day() -> void:
	var st: GameState = game.state
	for c in st.active_clients():
		if anniversary_day(c) - st.day == 0:
			var years: int = maxi(1, (st.day - c.known_on) / 360)
			game.add_log("🎁 %s completa %d ano(s) de contrato. Um presente cai bem." % [c.name, years], "client")
