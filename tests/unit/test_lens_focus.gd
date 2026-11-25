extends GutTest
## Tests for the card of the Lens app (plan 0003, R23) when the focus is not a
## spot or a person: a parked scooter (plan 0018, R4) has the focus
## "scooter.N", and the lens must not read it as a spot (PT-09 soak, run 9).

const SAVE_PATH := "user://test/lens_focus_save.json"

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


func test_the_lens_of_a_parked_scooter_is_not_a_spot() -> void:
	main.focus_id = "scooter.0"
	var card: Dictionary = main.lens_card()
	assert_ne(card.get("kind", ""), "spot", "a parked scooter is not a spot: %s" % card)
	main._learn_from_lens()
	assert_eq(main.lens_line, "", "the lens learns nothing from a parked scooter")


func test_the_lens_of_a_spot_is_a_spot() -> void:
	main.focus_id = "spot.pho"
	assert_eq(main.lens_card().get("kind", ""), "spot")
