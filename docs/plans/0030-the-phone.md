# 0030 The phone looks and works like a real phone

| Field | Value |
|---|---|
| Status | Draft |
| Branch | `feat/0030-phone`, made from the newest branch of the town when the work starts. |
| Depends on | 0003 (the phone and its apps), 0018 (the clock, the touch controls, the scooter), 0028 (the weather of the hour, for the app Weather). |
| Changes | 0003 (the button "Phone", the home screen, the name of the app Listen), AGENTS.md section 5a. |

## 1. Goal

The phone of the traveler looks and works like a smartphone of 2019. On the screen, the phone is an icon, not a button with the word "Phone". When the player raises it, it shows a home screen: a wallpaper, the time and the date, the weather of the hour, and the apps as icons with their names, with a dock at the bottom.

The picture `0030/phone_mockup.jpg` shows the idea: the icon and the joystick at rest when the player walks (top), and the home screen when the phone is up (bottom). It is a mockup in HTML over a screenshot of the game, not a design to copy pixel by pixel.

## 2. Out of scope

- Phone calls, a camera that saves photos, and a ride app (plan 0010).
- The app Photos with the photo of the passport (plan 0007).
- The illustrated map of plan 0029: until then, Maps shows a plain map (R5).

## 3. Decisions

| # | Decision | Why |
|---|---|---|
| D1 | The button "Phone" becomes a round icon of a phone, with a red badge for the count of unread messages. The same place on the screen (bottom right), the same size for a thumb (at least 64 px at 1280 × 720). | A real player knows the shape of a phone. |
| D2 | The home screen: the status line (the time, the signal, the battery), the time in large digits, the date in Vietnamese and in English ("Thứ Ba, 22 tháng 1 · Tuesday, January 22"), the weather of the hour (plan 0028), a grid of apps, and a dock of four apps. The wallpaper is a soft view of the bay. | The look of a real phone, and it teaches the date in Vietnamese. |
| D3 | The apps. Dock: Messages, Translate, Maps, Lens. Grid: Sổ tay, Weather, Clock, Settings. Translate is the app Listen of plan 0003 with a new name (the transcript, the meaning in English, and the phrasebook); Lens stays as it is. | In 2019 a traveler used a translate app to listen and to answer. The notebook keeps its name (design rule "The notebook"). |
| D4 | The icons are made for this game, as vector shapes (SVG or code). They do not copy the icon of a real phone maker or a real app (for example, no green speech bubble of one maker). An app has a red badge when it has news (an unread message, a new card in Sổ tay). | Design rule "No real businesses". |
| D5 | Maps now: a plain map drawn by code from the data of the game (the coast, the roads with their names, the landmarks, the start points), with the dot of the player and its direction, the scooter that the player rode last (plan 0018), drag and zoom. Plan 0029 later puts its illustrated map in this app. | I need a map now to find my way on the scooter. |
| D6 | Weather: the weather of the hour and of the rest of the day from `data/weather/2019.json` (plan 0028), in °C, with the words in Vietnamese and in English ("Nắng · Sunny"). Until plan 0028 is built, the app does not show. | The phone of a traveler shows the weather. |
| D7 | The controls stay as in plan 0003 and plan 0004: a tap on an icon opens its app, "Home" goes back, Tab and Esc on a computer, the D-pad and A on a gamepad. | The play tests of plan 0003 keep their steps, with the new names. |

## 4. Requirements

- **R1.** The icon of D1, at 1280 × 720, 2400 × 1080, and 720 × 1280, clear of the joystick, the action button, and the subtitles.
- **R2.** The home screen of D2 and D3, and the icons and the badges of D4.
- **R3.** Listen becomes Translate: the name in the data (`data/ui/`), the dialogue text that names the app, the messages of cô Nga that name it, and the play tests.
- **R4.** Each app opens from its icon, and "Home" goes back, with a touch, the mouse, the keys, and a gamepad.
- **R5.** The app Maps of D5.
- **R6.** The app Weather of D6.
- **R7.** AGENTS.md, section 5a: the apps and their names.

## 5. Play-test scenarios

- **PT-84 `phone_home`.** At 1280 × 720, 2400 × 1080, and 720 × 1280: the icon shows with the badge of an unread message; a tap raises the phone; the home screen shows the time and the date of the clock; each icon opens its app and "Home" goes back; the badge goes away after the message is read. In Maps, the player drags and zooms, lowers the phone, walks 30 m, and opens Maps again: the dot moved 30 m. Screenshots of each state, by day and at night. The same with the keys and with a gamepad.
- PT-18 to PT-24 of plan 0003 pass with the new names.

## 6. Acceptance criteria

| # | Criterion |
|---|---|
| 1 | The unit tests, PT-84, and PT-18 to PT-24 pass, and CI is green. |
| 2 | I use the phone on the web build on a phone and on a computer. |

## 7. Open questions

- **Q1.** The date line in Vietnamese and in English, or only in English, as on the phone of an American? (I answer.)
