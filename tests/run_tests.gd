extends SceneTree

const TestCore = preload("res://tests/test_core.gd")


func _initialize() -> void:
	var suite := TestCore.new()
	var failures := suite.run_all()
	if failures == 0:
		print("PASS: all %d checks passed" % suite.check_count)
	else:
		push_error("FAIL: %d of %d checks failed" % [failures, suite.check_count])
	quit(1 if failures > 0 else 0)

