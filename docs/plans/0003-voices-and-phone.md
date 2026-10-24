# 0003 Voices and the phone

| Field | Value |
|---|---|
| Status | Built |
| Branch | `feat/0003-voices-and-phone` |
| Depends on | 0002 (status "Built") |

## 1. Goal

People in the game speak aloud in Vietnamese, with subtitles. The player is a traveler who does not speak Vietnamese. The player uses a phone, as a real traveler does: a listen app transcribes and translates speech, a lens app tells what a place is, and the homestay family sends text messages.

The talk panel, the top bar, the toast, and the 2D sheets go away. The phone is the only flat thing on the screen, and it is an object that the traveler holds.

## 2. Out of scope

- Voice input from the real microphone of the player. The listen app is a game feature. It shows the lines that the game plays.
- New dialogue content. Change the form of the dialogue that exists. Write new lines only where this plan says so.
- A voice for the player.

## 3. Decisions

| ID | Decision | Reason |
|---|---|---|
| D1 | People speak with recorded voice audio. The subtitle shows what they say in Vietnamese. The English meaning shows only on the phone (listen app). A setting changes the subtitles to English, to both, or to off. | It is the real experience of a traveler. Subtitles in the language that people speak help listeners learn to understand that speech. Subtitles in the native language of the listener make it worse ([Mitterer and McQueen 2009](https://pmc.ncbi.nlm.nih.gov/articles/PMC2775720)). The English setting is for players who only want the story. |
| D2 | Make the voices with VieNeu-TTS v3 Turbo in CI. Commit the audio files. | Its code and weights are Apache 2.0, and its model page permits commercial use of audio from the preset voices ([model page](https://huggingface.co/pnnbao-ump/VieNeu-TTS-v3-Turbo)). It has Southern, Central, and Northern preset voices. It runs on a CPU without a GPU. The development workspace cannot download the weights, but GitHub Actions runners can. |
| D3 | Do not use the text-to-speech of the phone operating system. | Many phones have no Vietnamese voice, or only a Northern voice. The voice must be the same on all phones. |
| D4 | Do not clone the voice of a real person without written consent. Use only the preset voices. | Respect and the license terms of the model. |
| D5 | No speech bubbles. No narrator text box. | My decision. Text that floats in 3D is also hard to read on a small screen. |
| D6 | The phone has these apps: **Listen**, **Lens**, **Messages**, **Sổ tay**, **Clock**, **Settings**. Their names and look are fictional. They do not copy a real app or brand. | Each 2D function of plans 0001 and 0002 moves into one app. See section 4. |
| D7 | The player keeps control while the phone is up. The joystick works. The look drag works outside the phone area. The gyroscope look works. | A conversation must not stop the world. The player can walk away. |
| D8 | The player answers in three ways: an action in the world (for example, tap the menu board or hold out cash), a phrase from the phrasebook in the listen app, or English. | Real travelers do all three. People react in a different way to each one. |

## 4. Where each function goes

| Function in plans 0001 and 0002 | New place |
|---|---|
| Spoken lines of people (`speaker` is set) | Voice audio, subtitle, and the Listen app. |
| Description of a place (`spot.*.look`, open or closed status, hours) | The Lens app. Point the phone at the place. The app shows the name, the English name, open or closed now, the hours, and a short description. |
| Hints and tips (`hint`, `hem.tip.*`) | Messages from cô Nga of the host family. She writes in English. |
| Intro (`intro.welcome`) | The first message from the host family. |
| Choices of a spoken line | The phrasebook of the Listen app, and actions in the world. |
| Choices that are not speech ("Okay", "Rest one hour", "Go in") | The action button and actions in the world. "Okay" goes away. |
| Top bar: time, part of the day, day | The status bar of the phone (time) and the Clock app (part of the day, day, date). |
| Clock sheet (wait and sleep) | The Clock app. Waiting is "Rest" in the Clock app. |
| Notebook sheet | The Sổ tay app. |
| Toast for a new card | A notification on the phone. A short vibration on the phone when the phone is down. |
| Settings sheet, sound on and off | The Settings app. |
| The "lóc cóc" bubble of the hủ tiếu gõ | The clack sound and a sound caption: "[lóc cóc]". |

## 5. Requirements

### Dialogue data

- **R1.** Change the format of each spoken line in `data/dialogue/*.json`:
  - `vi`: the Vietnamese text that the person says. This is the subtitle.
  - `en`: the English meaning. The Listen app shows it.
  - `say` (optional): the text that the voice reads, when it must differ from `vi`. For example, write numbers and prices as words. Use Southern words ("năm chục ngàn"), not Northern words.
  - `voice_style` (optional): a tag of VieNeu-TTS, for example `[cười]` (laugh).
  - `replies`: the phrasebook entries for the answer. Each entry has `vi`, `en`, and `next`. One entry can be `"english": true`. It is the answer in English.
  - `actions`: the answers by action. Each entry has a world target (a test ID) and `next`.
- **R2.** Move the text of each line without a speaker to its new place in section 4. Remove the narration that has no place. For example, "Upstairs, a TV is on" becomes a sound from the upper floor.
- **R3.** `data/voices.json` gives a VieNeu-TTS preset voice to each speaker. The first values: Southern voices for all people of the hẻm, a Northern voice for Bác Hà. I make the final choice after the audition in R9.
- **R4.** `Content` checks at start that each spoken line has an audio file, and that the hash of the file entry matches `say` (or `vi`), the voice, and the model version.

### Voices

- **R5.** `tools/voices/build.py` makes one Ogg Vorbis file (mono, 48 kHz) for each spoken line in `assets/voices/LINE_ID.ogg`. It uses the Python package `vieneu` with the CPU (ONNX) engine and fp32 precision. Pin the package version.
- **R6.** `build.py` writes `assets/voices/manifest.json`: for each line, the file, the duration, the hash in R4, the voice, and the model version. It makes a file again only when its hash changes.
- **R7.** `.github/workflows/voices.yml` runs by hand, and on a push to `main` that changes `data/dialogue/` or `data/voices.json`. It runs `build.py` and commits the changed audio files to `main` with the identity in `CONTRIBUTING.md` and the message "Update the voices".
- **R8.** Normalize the loudness of all files to the same level (−16 LUFS). Remove the silence at the start and the end.
- **R9.** Audition: the workflow also makes a web page with each Southern, Central, and Northern preset voice. Each voice reads the same five lines from the game. Publish the page on GitHub Pages at `/voices/`. I listen on my phone and choose the voice of each person.
- **R10.** Add the licenses of VieNeu-TTS, MOSS-Audio-Tokenizer-Nano, and sea-g2p to `assets/CREDITS.md`. The builder checks the license of sea-g2p.

### Speech in the world

- **R11.** A person speaks through an `AudioStreamPlayer3D` at the head. The volume goes down with the distance. At more than 12 m, the player does not hear the line.
- **R12.** The subtitle shows while the audio plays, and 0.6 s more. It shows the speaker name in the speaker color, then the text.
- **R13.** Subtitle rules ([80.lv](https://80.lv/articles/10-golden-rules-on-subtitles-for-games), [GameAnalytics](https://www.gameanalytics.com/blog/adding-subtitles-to-your-mobile-game-dos-and-donts)):
  - At the bottom center of the screen, clear of the joystick zone and the phone.
  - The text height is at least 31 px at the 720 px base height. (This is 46 px at 1080 px.) A setting makes it larger.
  - A dark background box. A setting changes its opacity.
  - Two lines at most, with 38 characters or fewer in each line. Split a longer line into parts by sentence and by phrase. Each part shows for a time in proportion to its length in the audio.
- **R14.** Sound captions: important sounds that are not speech show a caption in brackets, for example "[lóc cóc]" or "[a scooter starts]". The data of each sound gives its caption.
- **R15.** When the player walks more than 6 m from a person during a talk, the talk ends. The person can call after the player with a short line.

### The phone

- **R16.** A phone button at the bottom right raises the phone. The phone takes the right part of the screen, at most 38% of the width. It must not cover the center dot or the subtitles. A second tap, or a swipe down on the phone, lowers it.
- **R17.** The status bar of the phone shows the game time. The phone screen is in English. Vietnamese words in it have all diacritics.
- **R18.** A small dot on the phone button shows a new message or a new card.

#### Listen

- **R19.** The Listen app has a "Listen" button. While it is on, the app adds each line that the player hears to a transcript: speaker, Vietnamese, and English. The speaker name shows only after the player has met that person. Before that, the app shows "Someone".
- **R20.** The app does not show the lines that played while it was off. In a talk, the phrasebook always has "Dạ, cô nói lại được không ạ?" (Could you say that again?). The form of address (cô, chú, bà, bác, anh, chị, em) matches the speaker. The person then says the last line again.
- **R21.** The phrasebook shows the replies of the current line. Each reply shows the Vietnamese, the English, and two buttons:
  - **Play**: the phone speaks the phrase aloud with a neutral voice. The person answers.
  - **I'll say it**: the phrase shows large on the phone with its tones. The player says it. The person answers in a warmer way (the data has a second `next` for this, `next_said`).
- **R22.** A tap on a transcript entry saves the phrase to the Sổ tay.

#### Lens

- **R23.** The Lens app shows the camera view of the game with a frame in the center. When a place or a cart is in the frame (the focus of plan 0002), the app shows its card: name, English name, open or closed now, hours, and the description. This replaces the "Look" action.

#### Messages

- **R24.** A thread with cô Nga of the homestay family. The messages come at fixed times and after events (data in `data/messages.json`). They hold the intro and the hints. Write them in friendly, plain English, with Vietnamese words where they are natural.
- **R25.** The sender is cô Nga. Put her name and her speaker color in `data/messages.json`. She is also a person in the world, at the homestay, with a Southern voice.

#### Sổ tay, Clock, Settings

- **R26.** The Sổ tay app shows the cards of plan 0001 and the saved phrases.
- **R27.** The Clock app shows the time, the part of the day in Vietnamese, the day number, and the "Rest" choices of the clock sheet. "Sleep until morning" is available only at the homestay.
- **R28.** The Settings app has the settings of plan 0002, sound on and off, the subtitle language (Vietnamese, English, both, off), the subtitle size, and the box opacity.

### Remove

- **R29.** Remove the talk panel, the top bar, the toast, the clock sheet, the notebook sheet, and the settings sheet. Remove their play-test steps, or change them to use the phone.

## 6. Play-test scenarios

The play-test driver needs: `raise_phone()`, `lower_phone()`, `open_app(name)`, `tap_phone_id(test_id)`, `subtitle()` (the visible subtitle text and speaker), `transcript()` (the entries in the Listen app), and `audio_playing(npc_id)`.

Run each scenario at 1280×720 and 2400×1080.

- **PT-18 `talk_listen`.** Start at 06:00. The first message from cô Nga arrives. Go to Bà Tư and talk with the phone down. Her audio plays, and the Vietnamese subtitle shows. Raise the phone, open Listen. The transcript is empty. Choose "Dạ, cô nói lại được không ạ?". She says the line again. Turn on Listen, and ask again. The transcript shows the line in Vietnamese and English. Answer with **Play**, then on a second visit with **I'll say it**. Check the two different answers.
- **PT-19 `overhear`.** Two neighbors talk. Turn on Listen at 4 m. The lines go into the transcript. Walk to 15 m. No new line goes into the transcript, and no subtitle shows.
- **PT-20 `reply_modes`.** For each reply type (phrase with Play, phrase with I'll say it, English, action in the world): give the reply and check the line ID of the answer.
- **PT-21 `phone_apps`.** Open each app. Lens: point at Phở Cô Sáu at 06:00 and at 11:00, and check "Open now" and "Closed now". Clock: rest until 11:00. Sổ tay: the card count. Settings: change each setting, quit, start again, and check that they stay.
- **PT-22 `subtitle_rules`.** Play every spoken line. For each part of each subtitle: two lines or fewer, 38 characters or fewer in each line, text height at least 31 px at the base height, fully on the screen, not under the phone or the joystick zone. Check each subtitle language setting.
- **PT-23 `walk_away`.** Start a talk, then walk away with the joystick. The talk ends at 6 m. The phone stays usable.
- **PT-24 `sound_captions`.** At 20:30, the hủ tiếu gõ clack plays, and the caption "[lóc cóc]" shows.

Change PT-01, PT-03, PT-04, PT-06, PT-08, PT-14, PT-16, and PT-17 to use the phone in place of the removed sheets and panel.

## 7. Acceptance criteria

1. The voices workflow ran in CI. Each spoken line has an audio file. The audition page is on GitHub Pages.
2. I chose the voice of each person, and `data/voices.json` has my choices.
3. All unit tests and all play tests pass. The builder looked at all screenshots.
4. Unit tests check the subtitle split, the transcript rules (only while Listen is on, only within 12 m), the form of address in R20, and the manifest check in R4.
5. On the Android debug APK, the voices play, and the subtitles are easy to read in daylight on a phone.
6. `AGENTS.md` describes the phone, the voices workflow, and the new dialogue format.

## 8. Open questions

- **Q1.** Do the VieNeu-TTS voices sound like people in Vũng Tàu? I decide after the audition. If no voice is good enough, the next choice is to record real people with their written consent.
- **Q2.** Answered: cô Nga of the host family writes the messages (R25).
- **Q3.** Answered for now: the forms of address below are correct. The traveler is an adult. "cô" for Cô Sáu, "bà" for Bà Tư, "chú" for Chú Bảy, "bác" for Bác Hà, and "con" or "cháu" for the player in their answers.
- **Q4.** The builder added a second neighbor for PT-19: Chú Chín, who argues about football with Chú Bảy at the cà phê cóc (`coc.talk.1` to `coc.talk.4`). Is the name correct for a neighbor of Chú Bảy, and is the talk natural?
- **Q5.** The neutral phone voice (the Play button) is "Mai Anh" (Northern, news style), because a phone voice is usually standard and neutral. A Southern voice is the other choice. Which one do I want?

## 9. Builder notes

- **N1. New lines.** The plan permits new lines only where it says so. The builder wrote these, all with the status "check": the warmer answers for "I'll say it" (`next_said`), the answers to the replies of Cô Sáu, Bác Hà, and cô Nga, the calls after a player who walks away (R15), the talk of the two neighbors (PT-19), the call of Cô Út ("Bánh khọt nè!" was a phrase in her description), and the messages of cô Nga (R24). The old lines without a speaker went to their new places (R2): the descriptions of the spots are in the Lens app, the hints are messages, "Upstairs, a TV is on" is a TV sound with the caption "[a TV upstairs]", and the "lóc cóc" bubble is the caption "[lóc cóc]". The hints "Coming in a later version" had no place, so they are not in the game.
- **N2. People in the world.** Each speaker is a person in the hẻm: Cô Sáu and Bác Hà at their shops, Cô Út at the bánh khọt shop, cô Nga at the homestay (09:00 to 22:00, after Bà Tư), and Chú Bảy and Chú Chín at the cà phê cóc (05:30 to 10:00). The first line of each person depends on the time (`lines` in `data/spots.json`), as before.
- **N3. The voices in the workspace.** D2 says that the workspace cannot download the weights. In this workspace, Hugging Face is reachable, and VieNeu-TTS runs on the CPU (about 2 s for each line). So the builder made the first voice files and the audition page in the workspace, with the same script as the workflow. The workflow makes them again when the dialogue or the voices change. The audition page is in `docs/voices/`, and the export workflow publishes it at `/voices/`. GitHub Pages must be on in the repository settings (source: GitHub Actions).
- **N4. The talk.** A tap on a person, or the action "Talk", starts a talk. The person turns to the player, and the view turns to the person. After a line with replies, the phrasebook shows them until the player answers. "I'll say it" shows the phrase large, with the tone of each syllable, and a button "I said it": the person answers when the player taps it. A talk ends at 6 m (R15), after 45 s with no answer, or when the player starts a talk with another person. After a talk ends, a tap on the person starts it again.
- **N5. Subtitles.** The joystick zone for R13 is the bottom left corner where the left thumb holds the joystick: 340 × 260 base pixels. The subtitles are at the bottom, at the right of this zone, when there is room. Else they are above the zone, at the left of the phone. On a narrow screen (the web build in portrait), a line has fewer than 38 characters, so that the box fits beside the phone. The speaker name is on the first line of each part, and it counts in the 38 characters. The "Both" setting shows one Vietnamese line and one English line in each part. The "Off" setting hides the spoken lines. The sound captions still show.
- **N6. The Lens app.** A second camera follows the camera of the player and renders the view at a half of the size, only while the app shows. The frame is the focus of plan 0002 (3 m, 18°). A person in the frame shows the name, or "Someone" before the player met that person.
- **N7. The Clock app and the homestay.** The action at the homestay is "Rest". It opens the Clock app. "Sleep until morning" is a choice at 5 m or less from the homestay door. At 23:30, cô Nga sends the "late" message. The clock stops at 23:59 until the player sleeps.
- **N8. Messages and notifications.** A message has a time (`at`, `before`, `day`) or an event (`start`, `wake`, `heard:LINE`, `lens:LINE`). A new message or a new card shows a banner on the phone when it is up, or vibrates when it is down, and puts the dot on the phone button. The dot goes away when the player opens Messages or the Sổ tay.
- **N9. Save file.** The save stays version 2. It has new fields with defaults: the people that the player met, the saved phrases, the messages, the unread count, and the subtitle settings. A save of plan 0002 loads.
- **N10. Play tests.** PT-22 shows each line in the subtitle box at 4 times the speed of the audio, because the rules are about the layout. The old scenarios PT-01, PT-03 to PT-06, PT-08 to PT-10, and PT-13 to PT-17 use the phone now. Plan 0004 has its scenarios as PT-25 to PT-32, and the geography plan (now 0005) has PT-33 to PT-39, so the numbers do not conflict.
- **N11. The stools of the cà phê cóc.** The soak test (PT-09) found that the player could stand on a stool of the cà phê cóc: the stool is 0.32 m high, and the round bottom of the player capsule climbed it. Now the collision of each stool is 0.6 m high, and PT-12 pushes the player into two stools at 06:00.

