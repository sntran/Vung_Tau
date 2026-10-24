extends GutTest
## Tests for the transcript rules of the Listen app (plan 0003, R19, R20):
## a line goes into the transcript only while Listen is on, and only when
## the player hears it (at 12 m or less).

const SAVE_PATH := "user://test/transcript_save.json"

var main: Node


func before_each() -> void:
	GameState.save_path = SAVE_PATH
	GameState.new_game()
	main = load("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	await wait_frames(3)


func after_each() -> void:
	main.stop_sounds()


func after_all() -> void:
	DirAccess.remove_absolute(SAVE_PATH)
	GameState.save_path = GameState.DEFAULT_SAVE_PATH
	GameState.load_game()


## Puts the player at the distance from Bà Tư, along the hẻm.
func _stand_at(distance: float) -> void:
	var npc: Npc = main.hem.npcs["batu"]
	var point := Vector3(npc.global_position.x + distance, 0.0, npc.global_position.z)
	main.player.place(point, 90.0, 0.0)
	await wait_frames(2)


func test_only_while_listen_is_on() -> void:
	await _stand_at(2.0)
	main.listen_on = false
	main.speak("batu", "batu.greet")
	assert_eq(main.transcript.size(), 0, "Listen is off: no line in the transcript")
	assert_true(main.subtitles.visible, "the player hears the line: the subtitle shows")
	main.listen_on = true
	main.speak("batu", "batu.reply_chua")
	assert_eq(main.transcript.size(), 1, "Listen is on: the line is in the transcript")
	assert_eq(main.transcript[0].line, "batu.reply_chua")


func test_only_within_12_m() -> void:
	main.listen_on = true
	await _stand_at(11.0)
	main.speak("batu", "batu.greet")
	assert_eq(main.transcript.size(), 1, "at 11 m the player hears the line")
	main.subtitles.clear()
	await _stand_at(15.0)
	main.speak("batu", "batu.reply_chua")
	assert_eq(main.transcript.size(), 1, "at 15 m the line is not in the transcript")
	assert_false(main.subtitles.visible, "at 15 m no subtitle shows")


func test_the_name_shows_after_the_player_met_the_person() -> void:
	main.listen_on = true
	await _stand_at(2.0)
	main.speak("batu", "batu.greet")
	assert_eq(main.transcript_view()[0].speaker, Content.string("someone"), "before the talk: \"Someone\"")
	GameState.meet("batu")
	assert_eq(main.transcript_view()[0].speaker, "Bà Tư", "after the talk: her name")
