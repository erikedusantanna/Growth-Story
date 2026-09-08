class_name FinanceSystem
extends RefCounted
## Caixa, custos mensais, histórico e falência.

const TOOLS_PER_EMPLOYEE := 250.0
const BANKRUPT_AT := -30000.0

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


func monthly_costs() -> Dictionary:
	var st: GameState = game.state
	var salaries := 0.0
	for e in st.employees:
		salaries += e.salary
	var rent: float = game.office.rent()
	var tools := TOOLS_PER_EMPLOYEE * st.employees.size()
	var hr: float = game.hr.salary()
	return {"salaries": salaries, "rent": rent, "tools": tools, "hr": hr, "total": salaries + rent + tools + hr}


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
