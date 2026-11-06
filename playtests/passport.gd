extends RefCounted
# PT-48 passport (plan 0007, R1 to R5). A fresh start: the first message of cô
# Nga asks for a photo of the passport. Until the player sends it, people use
# the default traveler (a man of 30). Open the Passport app with the button of
# the message. Set female, 25 years. Send. The photo shows in Messages, and cô
# Nga answers with "con". Quit, start again: the passport stays. The third run
# starts fresh and waits one hour with the Clock app: cô Nga sends the reminder
# (R4), with the button.
# sizes: 1280x720
# phase: --fresh-save --start-time=06:00
# phase:
# phase: --fresh-save --start-time=06:00

const GENDER := "female"
const BIRTH := "1993-06-15"
## The age of BIRTH on day 1 (22 January 2019).
const AGE := 25


func run(d: PlaytestDriver) -> void:
	await d.wait_idle()
	match d.phase:
		1:
			await _send(d)
		2:
			_reload(d)
		3:
			await _reminder(d)


func _send(d: PlaytestDriver) -> void:
	var ids: Array = d.state().messages
	d.expect(ids.has("welcome"), "the first message came: %s" % [ids])
	d.expect(not GameState.passport_sent(), "the passport is not sent yet")
	d.expect(d.address("batu").you == "con" and d.address("cout").you == "anh",
			"before the passport, people use the default traveler: %s, %s" % [d.address("batu"), d.address("cout")])
	await d.open_app("messages")
	await d.show_in_phone("message.welcome")
	await d.screenshot("first_message")
	if not d.expect(d.find("message.welcome.passport") != null, "the first message has the passport button"):
		return
	await d.tap_phone_id("message.welcome.passport")
	if not d.expect(d.main().phone.app == "passport", "the button opens the Passport app: %s" % d.main().phone.app):
		return
	await d.screenshot("passport_app")
	if not await d.set_passport(GENDER, BIRTH):
		return
	d.expect(GameState.traveler() == {"gender": GENDER, "age": AGE}, "the traveler is a woman of 25: %s" % [GameState.traveler()])
	d.expect(d.main().phone.app == "messages", "the phone shows the thread after the photo: %s" % d.main().phone.app)
	ids = d.state().messages
	d.expect(ids.has("passport_photo") and ids.has("passport_thanks"), "the photo and the answer are in the thread: %s" % [ids])
	var thanks := _message_text("passport_thanks")
	d.expect(thanks.begins_with("Cảm ơn con!"), "cô Nga answers with \"con\" (R3): %s" % thanks)
	d.expect(d.find("message.passport_photo") != null, "the photo shows in Messages")
	d.expect(d.find("message.welcome.passport") == null, "the passport button is gone after the photo")
	await d.show_in_phone("message.passport_thanks")
	await d.screenshot("photo_sent")
	d.expect(d.address("batu").you == "con" and d.address("cout").you == "chị",
			"the words of the rules for a woman of 25: Bà Tư %s, Cô Út %s" % [d.address("batu"), d.address("cout")])
	await d.lower_phone()


func _reload(d: PlaytestDriver) -> void:
	d.expect(GameState.passport_sent(), "the passport stays sent after a new start")
	d.expect(str(GameState.passport.birth) == BIRTH and str(GameState.passport.gender) == GENDER,
			"the save keeps the passport: %s" % [GameState.passport])
	d.expect(GameState.traveler() == {"gender": GENDER, "age": AGE}, "the traveler is a woman of 25: %s" % [GameState.traveler()])
	var ids: Array = d.state().messages
	d.expect(ids.count("welcome") == 1 and ids.has("passport_thanks"), "the thread is the same: %s" % [ids])


func _reminder(d: PlaytestDriver) -> void:
	d.expect(not GameState.passport_sent(), "a fresh start has no passport")
	await d.open_app("clock")
	await d.tap_phone_id("clock.wait_hour")
	await d.wait_frames(5)
	var ids: Array = d.state().messages
	if not d.expect(ids.has("passport_reminder"), "cô Nga sends a reminder after 30 minutes (R4): %s" % [ids]):
		return
	var reminder := _message_text("passport_reminder")
	d.expect(reminder.begins_with("Con ơi"), "the reminder uses the default traveler: %s" % reminder)
	await d.open_app("messages")
	await d.show_in_phone("message.passport_reminder")
	d.expect(d.find("message.passport_reminder.passport") != null, "the reminder has the passport button")
	await d.screenshot("reminder")


static func _message_text(message_id: String) -> String:
	for message: Dictionary in GameState.messages:
		if message.id == message_id:
			return str(message.text)
	return ""
