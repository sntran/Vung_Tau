# Plans

A plan describes one block of work. The builder builds only what an approved plan describes.

## Status values

| Status | Meaning |
|---|---|
| Draft | The architect writes it. Do not build it. |
| Approved | I approved it. The builder can start. |
| In progress | The builder works on it. |
| Built | All unit tests and play tests pass. The architect audits it. |
| Done | The architect audited it, and the builder corrected all defects. |

## Plan file format

Each plan has these sections:

1. Status, branch, and dependencies.
2. Goal: what the game has at the end.
3. Out of scope.
4. Decisions, with the reason for each decision.
5. Requirements, numbered `R1`, `R2`, and so on.
6. Play-test scenarios, numbered `PT-01`, `PT-02`, and so on.
7. Acceptance criteria.
8. Open questions.

The builder writes questions and answers under "Open questions". The builder does not change the requirements. To change a requirement, the architect writes the change and I approve it.

## List of plans

| Number | Name | Status |
|---|---|---|
| 0001 | [Foundation and the walkable hẻm](0001-foundation.md) | Built |
| 0002 | [First-person walking](0002-first-person.md) | Built |

## Proposed order of the next plans

The order can change.

| Number | Name | Content |
|---|---|---|
| 0003 | [Voices and the phone](0003-voices-and-phone.md) | Written, status "Draft". People speak aloud in Vietnamese with subtitles. The traveler's phone has Listen (transcribe and translate), Lens, Messages, Sổ tay, Clock, and Settings. It replaces the talk panel and the 2D sheets. |
| 0004 | [Real geography of Vũng Tàu](0004-real-geography.md) | Written, status "Draft". The real ground, hills, coast, beaches, sea, and roads, from OpenStreetMap and the Copernicus elevation data. |
| 0005 | Known structures | Tượng Chúa Kitô Vua, Hải đăng, Bạch Dinh, Miếu Hòn Bà, Chùa Tam Bảo, the main bus station, the old markets, the big roundabout, Ngã Năm, and others that I name. Made by code from their real outlines and sizes. |
| 0006 | Houses on the lots | A house generator with real proportions and a detail kit (shutters, balconies, wires, signs, plants). It puts houses on the lots between the roads. The homestay hẻm moves to its real place. |
| 0007 | Phở shop | Sit at the table. Order with the cuts ("một tô phở tái nạm gầu bò viên"), the extras, the herb plate, the sauces, eating, and paying. Port the flow from `docs/prototype/hem-2d.html`. |
| 0008 | Cà phê cóc | Order "đen đá", "sữa đá" or "nâu đá", "bạc sỉu". Watch the phin drip. |
| 0009 | Homestay meal | Eat with the host family. Home dishes and strong-smelling sauces. I name the dishes. |
| 0010 | Street snacks | Bánh mì at dawn, bánh khọt, hột vịt lộn, hủ tiếu gõ at night. |
| 0011 | Beach mornings and evenings | Morning exercise, the boats, the fish, the evening on the coast road. |
| 0012 | Hòn Bà at low tide | Check the tide, walk the rock path to Miếu Hòn Bà, and come back before the sea covers it. Locals warn the player about the time. |
| 0013 | Afternoon on the Vi Ba road | Jog or ride up Núi Lớn in the afternoon. Stop at Chùa Tam Bảo to watch the monkeys (and keep your bag closed). At the top, eat sữa chua and trứng lòng đào. |
| 0014 | Scooter | Wear a helmet and ride along the coast in the evening, and up the Vi Ba road. |
| 0015 | Store release | Signed Android and iOS builds, store pages, privacy text. |
