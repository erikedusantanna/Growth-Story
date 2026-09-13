class_name BankSystem
extends RefCounted
## O banco do World Map: capital de giro. A partir da região 2 o mapa ganha um prédio de banco;
## o jogador escolhe uma linha, o dinheiro cai na conta na hora e a parcela passa a sair todo mês,
## junto com o fechamento. Conteúdo em data/loans.json.
##
## A parcela é fixa (tabela Price): parcela = P * i / (1 - (1 + i)^-n). Sem caixa na hora do
## débito, o que faltar vira multa sobre o saldo devedor e custa reputação — não quebra a agência
## sozinho, mas encarece a dívida.

var game


func setup(g) -> void:
	game = g


func data() -> Dictionary:
	return game.content.loans


## O banco só existe a partir da região indicada no conteúdo (padrão: região 2).
func is_available() -> bool:
	return game.office.region() >= int(data().get("min_region", 2))


func all_offers() -> Array:
	return data().get("offers", [])


func offer_by_id(id: String) -> Dictionary:
	for o in all_offers():
		if String(o.get("id", "")) == id:
			return o
	return {}


## Linhas que a agência alcança hoje (região da sede e reputação).
func offers() -> Array:
	var st: GameState = game.state
	var region: int = game.office.region()
	return all_offers().filter(func(o):
		return region >= int(o.get("min_region", 2)) and st.reputation >= float(o.get("requires_rep", 0)))


## Parcela fixa da tabela Price.
static func installment_for(amount: float, months: int, rate: float) -> float:
	if months <= 0:
		return amount
	if rate <= 0.0:
		return amount / float(months)
	var factor: float = pow(1.0 + rate, -float(months))
	return amount * rate / (1.0 - factor)


func installment(o: Dictionary) -> float:
	return installment_for(float(o.get("amount", 0)), int(o.get("months", 12)), float(o.get("monthly_rate", 0.0)))


## Quanto se paga no total (o custo do dinheiro, para o jogador decidir com clareza).
func total_cost(o: Dictionary) -> float:
	return installment(o) * float(o.get("months", 12))


func active() -> Array:
	return game.state.loans


func monthly_payment() -> float:
	var total := 0.0
	for loan in active():
		total += float(loan.get("installment", 0))
	return total


func debt() -> float:
	var total := 0.0
	for loan in active():
		total += float(loan.get("remaining", 0))
	return total


func can_take(o: Dictionary) -> Dictionary:
	var st: GameState = game.state
	if o.is_empty():
		return {"ok": false, "reason": "Linha desconhecida."}
	if not is_available():
		return {"ok": false, "reason": "O banco atende a partir da Região 2."}
	if game.office.region() < int(o.get("min_region", 2)):
		return {"ok": false, "reason": "Essa linha só existe a partir da Região %d." % int(o.get("min_region", 2))}
	if st.reputation < float(o.get("requires_rep", 0)):
		return {"ok": false, "reason": "O gerente pede %d de reputação." % int(o.get("requires_rep", 0))}
	if active().size() >= int(data().get("max_active", 2)):
		return {"ok": false, "reason": "Você já tem %d empréstimos abertos. Quite um antes." % active().size()}
	if active().any(func(l): return String(l.get("id", "")) == String(o.get("id", ""))):
		return {"ok": false, "reason": "Essa linha já está em andamento."}
	return {"ok": true, "reason": ""}


## Contrata o empréstimo: o valor entra no caixa na hora.
func take(id: String) -> Dictionary:
	var o := offer_by_id(id)
	var check := can_take(o)
	if not check.ok:
		return check
	var st: GameState = game.state
	var amount := float(o.get("amount", 0))
	var months := int(o.get("months", 12))
	var parcel := installment(o)
	st.loans.append({
		"id": id, "amount": amount, "remaining": parcel * float(months), "installment": parcel,
		"months_left": months, "rate": float(o.get("monthly_rate", 0.0)), "taken_day": st.day,
	})
	game.finance.add_money(amount, "Empréstimo: %s" % String(o.get("name", "")), "revenue")
	st.stats["loans"] = int(st.stats.get("loans", 0)) + 1
	game.add_log("%s %s aprovado: %s na conta. Parcela de %s por %d meses." % [
		String(o.get("icon", "🏦")), String(o.get("name", "Empréstimo")), FinanceSystem.format_money(amount),
		FinanceSystem.format_money(parcel), months], "money")
	EventBus.loan_taken.emit(st.loans.back())
	EventBus.state_changed.emit()
	return {"ok": true, "reason": ""}


## Quitar o que falta de uma vez, com o saldo devedor cheio (sem desconto: é o banco).
func settle(id: String) -> Dictionary:
	var st: GameState = game.state
	for loan in active():
		if String(loan.get("id", "")) != id:
			continue
		var remaining := float(loan.get("remaining", 0))
		if st.money < remaining:
			return {"ok": false, "reason": "Precisa de %s para quitar." % FinanceSystem.format_money(remaining)}
		game.finance.add_money(-remaining, "Quitação: %s" % String(offer_by_id(id).get("name", "")), "expense")
		st.loans.erase(loan)
		game.add_log("Empréstimo quitado: %s a menos na dívida." % FinanceSystem.format_money(remaining), "money")
		EventBus.state_changed.emit()
		return {"ok": true, "reason": ""}
	return {"ok": false, "reason": "Empréstimo não encontrado."}


## Cobrança do mês. Chamado pelo fechamento, depois dos custos fixos.
func on_month() -> void:
	if active().is_empty():
		return
	var st: GameState = game.state
	var done: Array = []
	for loan in active():
		var parcel := float(loan.get("installment", 0))
		var name: String = String(offer_by_id(String(loan.get("id", ""))).get("name", "empréstimo"))
		if st.money >= parcel:
			game.finance.add_money(-parcel, "Parcela: %s" % name, "expense")
			loan["remaining"] = maxf(float(loan.get("remaining", 0)) - parcel, 0.0)
			loan["months_left"] = int(loan.get("months_left", 0)) - 1
			if int(loan["months_left"]) <= 0 or float(loan["remaining"]) <= 0.0:
				done.append(loan)
			continue
		# sem caixa: a parcela não sai, o saldo cresce com a multa e o mercado fica sabendo
		var fee := float(loan.get("remaining", 0)) * float(data().get("late_fee_rate", 0.08))
		loan["remaining"] = float(loan.get("remaining", 0)) + fee
		game.reputation.penalize(float(data().get("late_reputation", 2)), "parcela do banco atrasada")
		game.add_log("⚠️ Parcela de %s atrasada (%s). Multa de %s na dívida." % [
			name, FinanceSystem.format_money(parcel), FinanceSystem.format_money(fee)], "warn")
	for loan in done:
		st.loans.erase(loan)
		game.add_log("🏦 %s quitado. Dívida encerrada." % String(offer_by_id(String(loan.get("id", ""))).get("name", "Empréstimo")), "money")
	EventBus.state_changed.emit()
