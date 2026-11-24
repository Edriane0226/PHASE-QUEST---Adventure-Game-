extends RefCounted
## Versioned question results shared by capstone providers. The caller owns the save transaction.
var questions: Array

func _init(bank: Array) -> void:
	questions = bank

func initial_state() -> Dictionary:
	return {"version":1, "answers":{}, "started":false, "help_used":false}

func valid(state: Variant) -> bool:
	if not state is Dictionary or state.get("version") != 1 or not state.get("answers") is Dictionary or not state.get("started") is bool or not state.get("help_used") is bool:
		return false
	if not state.started and (not state.answers.is_empty() or state.help_used):
		return false
	if state.answers.size() > questions.size():
		return false
	for index in range(state.answers.size()):
		var question: Dictionary = questions[index]
		var answer: Variant = state.answers.get(question.id)
		if not answer is Dictionary:
			return false
		for field in ["first", "last"]:
			var choice: Variant = answer.get(field)
			if not choice is int or choice < 0 or choice >= question.choices.size():
				return false
		if answer.first == question.correct and answer.last != question.correct:
			return false
		if index + 1 < state.answers.size() and answer.last != question.correct:
			return false
	if state.has("review_pending"):
		var pending: Variant = state.review_pending
		if not pending is int or pending < 0 or pending != passed_count(state) - 1 or state.answers.size() != pending + 1:
			return false
	return true

func passed_count(state: Dictionary) -> int:
	for index in range(questions.size()):
		var question: Dictionary = questions[index]
		if state.answers.get(question.id, {}).get("last", -1) != question.correct:
			return index
	return questions.size()

func passed(state: Dictionary) -> bool:
	return valid(state) and passed_count(state) == questions.size()

func perfect(state: Dictionary) -> bool:
	if not passed(state) or state.help_used:
		return false
	return questions.all(func(question): return state.answers[question.id].first == question.correct)

func review_index(state: Dictionary) -> int:
	return state.get("review_pending",passed_count(state))

func acknowledge_review(state: Dictionary, index: int) -> bool:
	if state.get("review_pending",-1) != index or index < 0:
		return false
	state.erase("review_pending")
	return true

func record(state: Dictionary, index: int, choice: String) -> bool:
	if not valid(state) or not state.started or state.has("review_pending") or index < 0 or index >= questions.size() or index != passed_count(state):
		return false
	var question: Dictionary = questions[index]
	if not choice.is_valid_int() or choice.to_int() < 0 or choice.to_int() >= question.choices.size():
		return false
	var selected := choice.to_int()
	var answer: Dictionary = state.answers.get(question.id, {"first":selected})
	answer.last = selected
	state.answers[question.id] = answer
	if selected == question.correct: state.review_pending = index
	return true

func question_view(state: Dictionary, index: int, show_feedback: bool) -> Dictionary:
	var question: Dictionary = questions[index]
	var selected: int = state.answers.get(question.id, {}).get("last", -1)
	var reviewed := selected >= 0 and show_feedback
	var correct: bool = reviewed and selected == question.correct
	var choices: Array = []
	if not reviewed:
		for number in range(question.choices.size()):
			choices.append({"id":str(number), "label":question.choices[number]})
	var action := {"id":"submit", "label":"Check answer", "enabled":true}
	if reviewed:
		action = {"id":"next_question" if correct else "retry_question", "label":"Continue" if correct else "Try again", "enabled":true}
	var actions := [action]
	if not correct: actions.append({"id":"help", "label":"Free help", "enabled":true})
	return {
		"title":"Finn’s field questions", "speaker":"finn", "body":question.prompt,
		"status":"Question %d / %d" % [index + 1, questions.size()], "choices":choices,
		"selected_choice":"", "feedback":question.feedback[selected] if reviewed else "",
		"expression":"happy" if correct else ("concerned" if reviewed else "explaining"),
		"actions":actions,
	}
