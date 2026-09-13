class_name FinanceSystem
extends RefCounted
## Caixa, custos mensais, histórico e falência.

const TOOLS_PER_EMPLOYEE := 250.0
const BANKRUPT_AT := -30000.0
## Dois avisos antes da derrota. O jogador reclamou de perder de surpresa: ficar no vermelho é
## normal por um tempo, então o jogo precisa dizer em voz alta onde fica a linha.
const WARN_AT := [-6000.0, -18000.0]

var game


func setup(g) -> void:
	game = g


func add_money(delta: float, reason: String = "", kind: String = "other") -> void:
	var st: GameState = game.state
	st.money += delta
	if delta > 0.0:
		st.month_revenue += delta
		st.stats["total_revenue"] = float(st.stats["total_revenue"]) + delta
	else:
		st.month_expenses += -delta
	if reason != "" and absf(delta) >= 1.0:
		var sign := "+" if delta >= 0.0 else "-"
		game.add_log("%s %s (%s)" % [sign, format_money(absf(delta)), reason], "money")
	EventBus.money_changed.emit(st.money, delta)
	check_alerts()


## Situação do caixa, para a aba Empresa mostrar em tempo real e para os avisos decidirem a hora.
## Devolve {level, name, color_kind, money, limit, room, months_left, warning}.
## level: 0 saudável · 1 atenção (no vermelho) · 2 alerta · 3 risco de derrota.
func status() -> Dictionary:
	var st: GameState = game.state
	var money: float = st.money
	var level := 0
	if money < BANKRUPT_AT * 0.6:          # passou do segundo aviso
		level = 3
	elif money < float(WARN_AT[0]):
		level = 2
	elif money < 0.0:
		level = 1
	var names := ["Saudável", "No vermelho", "Alerta", "Risco de falência"]
	var kinds := ["green", "text", "accent", "red"]
	# quantos meses o caixa aguenta no ritmo atual (receita recorrente menos custo fixo e parcelas)
	var costs := monthly_costs()
	var burn: float = float(costs.total_with_loans) - st.mrr()
	var months := -1.0
	if burn > 0.0:
		months = (money - BANKRUPT_AT) / burn
	return {
		"level": level, "name": names[level], "color_kind": kinds[level],
		"money": money, "limit": BANKRUPT_AT, "room": money - BANKRUPT_AT,
		"months_left": months, "burn": burn,
	}


## Dispara os avisos de falência quando o caixa cruza cada linha, uma vez por queda.
## Voltar para o positivo rearma os avisos.
func check_alerts() -> void:
	var st: GameState = game.state
	if st.game_over:
		return
	if st.money >= 0.0:
		if st.bankrupt_warnings != 0:
			st.bankrupt_warnings = 0
		return
	for i in WARN_AT.size():
		if st.money < float(WARN_AT[i]) and st.bankrupt_warnings <= i:
			st.bankrupt_warnings = i + 1
			EventBus.bankruptcy_warning.emit(i + 1, status())
			return


func monthly_costs() -> Dictionary:
	var st: GameState = game.state
	var salaries := 0.0
	for e in st.employees:
		salaries += e.salary
	var rent: float = game.office.rent()
	var tools := TOOLS_PER_EMPLOYEE * st.employees.size()
	var hr: float = game.hr.salary() + game.recruitment.salary()
	if game.calendar.has_focus("caixa"):
		rent *= 0.9
		tools *= 0.9
	# a parcela do banco entra à parte: sai no fechamento, mas não é custo fixo da operação
	var loans: float = game.bank.monthly_payment()
	return {"salaries": salaries, "rent": rent, "tools": tools, "hr": hr, "loans": loans,
		"total": salaries + rent + tools + hr, "total_with_loans": salaries + rent + tools + hr + loans}


func on_month() -> void:
	var st: GameState = game.state
	var costs := monthly_costs()
	st.money -= costs.total
	st.month_expenses += costs.total
	game.add_log("Fechamento do mês: salários %s, aluguel %s, ferramentas %s%s." % [
		format_money(costs.salaries), format_money(costs.rent), format_money(costs.tools),
		(", RH %s" % format_money(costs.hr)) if costs.hr > 0.0 else ""], "money")
	st.finance_history.append({
		"month_index": st.month_index() - 1, "revenue": st.month_revenue,
		"expenses": st.month_expenses, "cash": st.money,
	})
	if st.finance_history.size() > 24:
		st.finance_history.pop_front()
	st.month_revenue = 0.0
	st.month_expenses = 0.0
	EventBus.money_changed.emit(st.money, -costs.total)
	if st.money < BANKRUPT_AT:
		game.end_game("A agência quebrou. O caixa passou de %s negativos." % format_money(-BANKRUPT_AT))
	elif st.money < 0.0:
		game.add_log("Caixa negativo! Feche projetos ou corte custos.", "warn")


## Versão curta, para onde o espaço é apertado (o HUD). O valor exato continua em format_money:
## a partir de 100 mil vira "R$ 850 mil" e a partir de 1 milhão "R$ 2,4 mi" — assim o rótulo tem
## largura previsível e o topo da tela não estoura os 524 px úteis num jogo longo.
static func format_money_short(value: float) -> String:
	var negative := value < 0.0
	var v := absf(value)
	var prefix := "-R$ " if negative else "R$ "
	if v >= 1000000000.0:
		return prefix + ("%.1f bi" % (v / 1000000000.0)).replace(".", ",")
	if v >= 1000000.0:
		return prefix + ("%.1f mi" % (v / 1000000.0)).replace(".", ",")
	if v >= 100000.0:
		return prefix + "%d mil" % int(roundf(v / 1000.0))
	return format_money(value)


static func format_money(value: float) -> String:
	var negative := value < 0.0
	var v := absf(value)
	var whole := int(roundf(v))
	var text := str(whole)
	var out := ""
	var count := 0
	for i in range(text.length() - 1, -1, -1):
		out = text[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "." + out
	return ("-R$ " if negative else "R$ ") + out
