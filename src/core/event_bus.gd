extends Node
## Barramento global de sinais. Os sistemas emitem, a UI escuta.
## Mantém a lógica de jogo desacoplada das telas.

signal day_passed(day: int)
signal month_passed(month_index: int)
signal year_passed(year: int)
signal state_changed()                       # algo relevante mudou; telas devem atualizar
signal log_added(text: String, kind: String) # feed do escritório
signal money_changed(value: float, delta: float)
signal reputation_changed(value: float, delta: float)
signal employee_hired(employee)
signal employee_left(employee, reason: String)
signal employee_promoted(employee)
signal client_signed(client)
signal client_lost(client)
signal diagnosis_done(client)
signal project_started(project)
signal project_completed(project, result: Dictionary)
signal retainer_offer(client, project)
signal event_triggered(event: Dictionary)
signal agency_event_finished(event: Dictionary, people: Array, summary: String)  # evento promovido terminou
signal awards_ceremony(ceremony: Dictionary)  # Prêmios do Marketing na virada do ano
signal game_over(reason: String)
signal office_feedback(employee_id: int, text: String, kind: String)  # balão/número flutuante sobre o personagem
signal game_started()
