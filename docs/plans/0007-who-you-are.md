# 0007 Who you are: the passport and the forms of address

| Field | Value |
|---|---|
| Status | Approved |
| Branch | `feat/0007-who-you-are` |
| Depends on | 0003 (status "Done": the corrections of `docs/playtests/0003-report.md`, mainly D-0003-04, the introductions) |

## 1. Goal

The traveler has an age and a gender. People address the traveler with the correct Vietnamese words for that age and gender, and the traveler answers with the correct words. A 25-year-old woman hears "con" from Bà Tư and "em" from Cô Út. A 60-year-old man hears "anh" from Cô Út and calls her "em". The player learns why.

The player gives the age and the gender in the game world: cô Nga asks for a photo of the passport, because the homestay must register the guest with the police.

## 2. Out of scope

- The start at the bus station, the free walk, the ride to the homestay, and the check-in at the door. A later plan does this ("Arrival", after the houses are on the real lots).
- A name that people say aloud. People in the game do not say the traveler's name.
- New dialogue, except the variants of the lines that have a form of address, and the lines in R2 and R13.

## 3. Decisions

| ID | Decision | Reason |
|---|---|---|
| D1 | Vietnamese has no neutral "you" and "I". People choose a kinship word by the age and the gender of the listener, and the words come in pairs (bà–con, chị–em, chú–cháu). Strangers often ask each other's age to find the correct words. The game uses this system for all speech to the traveler and from the traveler. | It is one of the strongest daily experiences of a foreigner in Vietnam ([Vietnamese pronouns](https://en.wikipedia.org/wiki/Vietnamese_pronouns)). It is also hard to learn from a book. |
| D2 | The player sets the age and the gender in a passport on the phone, when cô Nga asks for a photo of it. There is no menu outside the world. | Accommodation providers must register each foreign guest with the police immediately after arrival, with the passport number, full name, gender, date of birth, and nationality ([Việt Nam News, 2026-07-22](https://vietnamnews.vn/society/1785912/accommodation-providers-required-to-register-foreign-guests-temporary-residence-immediately-upon-arrival.html)). Hosts often ask for a photo of the passport before the guest arrives. |
| D3 | The rules are data: `data/address.json`. Code does not hold a form of address. | Content is data. I know these customs, and I correct them in the file. |
| D4 | The age is a number from 18 to 80, not a range. The rules compare the age of the person with the age of the traveler. | The correct word depends on the difference of age, not on a range of the traveler alone. |
| D5 | Gender: "male" or "female". | The kinship words have these two forms (anh/chị, chú/cô, ông/bà). |
| D6 | A line with a form of address has one voice file for each variant that the rules can make for its speaker. The voices build makes all variants. | The person must say the same word as the subtitle. |

## 4. Requirements

### The passport

- **R1.** The phone has a **Passport** app. It shows a passport page of the traveler: given name, family name, nationality "United States of America", gender, date of birth, and a passport number. The look is a generic passport. It does not copy the design, the seal, or the emblem of a real passport.
- **R2.** At the first start, the first message of cô Nga welcomes the traveler and asks for a photo of the passport "for the registration with the police (khai báo tạm trú)". The message has a button **Send a photo of my passport**. It opens the Passport app.
- **R3.** In the Passport app, the player sets the gender (male, female) and the date of birth (the age is 18 to 80 on the game date). Given name and family name have default values that the player can change. Then **Send**. The phone sends the photo in the Messages thread, and cô Nga answers (for example "Cảm ơn con! Cô đăng ký tạm trú cho con rồi nha." with the form of address of R6).
- **R4.** Until the player sends the passport, people use the default traveler: a man of 30. Cô Nga sends a reminder after 30 minutes of game time.
- **R5.** The Settings app has **Change passport details**. A change takes effect at once. The save keeps the passport. A save of plan 0003 loads with the default traveler and the first message again.

### The forms of address

- **R6.** `data/address.json` has the rules. For each person (the speaker ID), the age, the gender, and a role (`elder`, `host`, `seller`, `neighbor`). For each pair of person and traveler, the rules give:
  - `you`: what the person calls the traveler (con, cháu, em, anh, chị, chú, cô, dì, bác, ông, bà),
  - `me`: what the person calls themself (bà, bác, cô, dì, chú, chị, anh, em, con, cháu, or tui),
  - `them`: what the traveler calls the person,
  - `self`: what the traveler calls themself.
  The rules select by the age difference (the person minus the traveler) and the gender of each. A rule for one role or one person can override the general rule.
- **R7.** The general rules (I approved the table, see Q1):

  | Age difference (person − traveler) | `you` | `me` | `them` | `self` |
  |---|---|---|---|---|
  | 35 or more | con (cháu in the North) | bà, ông, bác | bà, ông, bác | con, cháu |
  | 15 to 34 | con (cháu in the North) | cô, chú, bác | cô, chú, bác | con, cháu |
  | 5 to 14 | em | chị, anh | chị, anh | em |
  | −4 to 4 | anh, chị | tui | anh, chị | tui |
  | −5 to −14 | anh, chị | em | em | anh, chị |
  | −15 or less | chú, cô | con, cháu, em | con, cháu, em | chú, cô |

  Role rules: a `seller` younger than 50 calls a traveler of 25 or more "anh" or "chị", and calls themself "em" or "chị" (my decision, 2026-10-24). The `host` (cô Nga) knows the traveler's age from the passport and uses the general rules.
- **R8.** The display name of a person is the traveler's word for them and the given name: "Cô Sáu" for a traveler of 30, "Chị Sáu" for a traveler of 50. When the traveler's word is "em", "con", or "cháu", the display name is the name that the neighbors use (`name` in the data, for example "Cô Út"), see Q4. Put the display name rules in `data/address.json`. The subtitles, the Listen app, the Lens app, and the Sổ tay use the display name, after the introduction (D-0003-04).
- **R9.** Dialogue text has the fields `{you}`, `{me}`, `{them}`, and `{self}`, with a capital letter form (`{You}`, `{Me}`, `{Them}`, `{Self}`) at the start of a sentence. `Content` replaces them for the current traveler. The English meaning does not depend on them, except an optional `{dear}` that is "dear" for `con` and `cháu` and empty for the others.
- **R10.** Change the lines of plan 0003 to use the fields. For example "Ủa, con dậy rồi hả? Ăn sáng chưa con?" becomes "Ủa, {you} dậy rồi hả? Ăn sáng chưa {you}?", and the "say again" phrase becomes "Dạ, {them} nói lại được không ạ?". Check that each line reads correctly for each variant. Some sentences change more than one word: "Dạ, con cảm ơn cô" for a traveler of 30, "Dạ, em cảm ơn chị" for 50, "Cảm ơn em" for 65. A line can have a `variants` object for these cases.

### Voices

- **R11.** `tools/voices/build.py` makes one clip for each variant of each line: `LINE@KEY.ogg`, where KEY is the resolved words (for example `batu.greet@con`). It makes only the variants that the rules can make for the speaker of the line. The manifest and the check of R4 of plan 0003 cover each variant.
- **R12.** The game plays the clip of the current variant. When no clip exists for the variant, `Content` reports an error at start (the same check as R4 of plan 0003).

### Learn it

- **R13.** A Sổ tay card "Xưng hô" (forms of address). The player learns it the first time a person calls the traveler by a kinship word. It explains in short English: there is no neutral "you"; the words come from the family; they depend on age; and why Bà Tư says "con" and Cô Út says "anh". Status "check".
- **R14.** When the Listen app shows a line with a form of address, the English line adds the word and its meaning in brackets the first 3 times, for example "Have you had breakfast yet? [con: 'child', from an older person]".

## 5. Play-test scenarios

The play-test driver needs: `set_passport(gender, birth_date)` that uses the Passport app with real taps, and `address(npc_id)` (the resolved `you`, `me`, `them`, `self`).

- **PT-48 `passport`.** A fresh start. The first message asks for the passport. Open it with the button. Set female, 25 years. Send. The photo shows in Messages, and cô Nga answers with "con". Quit, start again: the passport stays.
- **PT-49 `address_matrix`.** For each traveler (male 25, female 25, male 40, female 40, male 60, female 60): talk with each person who can talk. Check that the subtitle, the Listen entry, the phrasebook, and the voice clip ID use the words of the rules. Take a screenshot of each subtitle.
- **PT-50 `display_names`.** For a traveler of 30 and of 60: the name of Cô Sáu in the subtitle, the Listen app, and the Lens app after her introduction.
- **PT-51 `change_passport`.** Change the age in the Settings app during a talk. The next line uses the new words. No error.

Unit tests: each row of R7 and each role rule, the capital letter forms, the `{dear}` field, the variant keys of R11, and that each line resolves for each traveler of PT-49 without a field left in the text.

## 6. Acceptance criteria

1. I checked the rules of R7 and the variants of each line (Q1, Q2).
2. The voices workflow made all variants.
3. All unit tests and all play tests pass. The builder looked at all screenshots.
4. `AGENTS.md` describes the passport, `data/address.json`, and the dialogue fields.

## 7. Open questions

- **Q1.** Answered: the table of R7 is correct.
- **Q2.** Partly answered. Bác Hà (from the North) says "cháu", not "con", to a younger traveler. In the South, people can say "dì" where the North says "cô" for a woman of about the age of one's mother. I am not sure, because my family has relatives from the North and the South, and many people from the North live in Vũng Tàu. So the word is a value for each person in `data/address.json` (`aunt_word`: "cô" or "dì"). The first value is "cô" for all, with the status "check".
- **Q3.** Answered: with people of about the same age, the traveler and the person say "tui" (the Southern spoken form of "tôi"). It is friendlier than "tôi".
- **Q4.** Answered: a person who is younger than the traveler keeps the name that the neighbors use, for example "Cô Út" (R8).
