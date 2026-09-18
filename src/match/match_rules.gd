class_name MatchRules
extends RefCounted

enum State {
	WAITING,
	PLAYING,
	MATCH_OVER,
}

var state: State = State.WAITING
var target_score := 5
var respawn_delay := 3.0
var winner_id := 0

var _scores: Dictionary = {}
var _respawns: Dictionary = {}


func _init(config_target_score := 5, config_respawn_delay := 3.0) -> void:
	target_score = maxi(1, int(config_target_score))
	respawn_delay = maxf(0.0, float(config_respawn_delay))


func start_match(player_ids: Array) -> void:
	state = State.PLAYING
	winner_id = 0
	_scores.clear()
	_respawns.clear()
	for player_id in player_ids:
		_scores[int(player_id)] = 0


func score_for(player_id: int) -> int:
	return int(_scores.get(player_id, 0))


func is_respawning(player_id: int) -> bool:
	return _respawns.has(player_id)


func respawn_remaining(player_id: int) -> float:
	return maxf(0.0, float(_respawns.get(player_id, 0.0)))


func record_kill(killer_id: int, victim_id: int) -> Dictionary:
	if state != State.PLAYING:
		return _rejected("比赛已经结束")
	if killer_id == victim_id or not _scores.has(killer_id) or not _scores.has(victim_id):
		return _rejected("击杀者和受害者无效")
	if _respawns.has(victim_id):
		return _rejected("受害者已经在重生倒计时")

	_scores[killer_id] = score_for(killer_id) + 1
	_respawns[victim_id] = respawn_delay
	var result := {
		"accepted": true,
		"killer_id": killer_id,
		"victim_id": victim_id,
		"score": score_for(killer_id),
		"winner_id": 0,
		"state": state,
	}
	if score_for(killer_id) >= target_score:
		state = State.MATCH_OVER
		winner_id = killer_id
		result["winner_id"] = winner_id
		result["state"] = state
	return result


func advance(delta: float) -> Array[int]:
	if state != State.PLAYING:
		return []
	var ready: Array[int] = []
	var elapsed := maxf(0.0, delta)
	for player_id in _respawns:
		_respawns[player_id] = maxf(0.0, respawn_remaining(player_id) - elapsed)
	for player_id in _respawns:
		if respawn_remaining(player_id) <= 0.0001:
			ready.append(int(player_id))
	for player_id in ready:
		_respawns.erase(player_id)
	return ready


func snapshot() -> Dictionary:
	return {
		"state": state,
		"target_score": target_score,
		"winner_id": winner_id,
		"scores": _scores.duplicate(),
		"respawns": _respawns.duplicate(),
	}


func _rejected(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason, "winner_id": winner_id, "state": state}
