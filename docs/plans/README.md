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
| 0003 | [Voices and the phone](0003-voices-and-phone.md) | Built |
| 0004 | [Desktop and the house detail kit](0004-desktop-and-house-detail.md) | Approved |
| 0005 | [Real geography of Vũng Tàu](0005-real-geography.md) | Approved |

## Proposed order of the next plans

The order can change.

| Number | Name | Content |
|---|---|---|
| 0003 | [Voices and the phone](0003-voices-and-phone.md) | Built. People speak aloud in Vietnamese with subtitles. The traveler's phone has Listen (transcribe and translate), Lens, Messages, Sổ tay, Clock, and Settings. It replaces the talk panel and the 2D sheets. |
| 0004 | [Desktop and the house detail kit](0004-desktop-and-house-detail.md) | Approved. Desktop becomes the main platform, with the Forward+ renderer and quality presets. Tube houses get depth, brick under plaster and paint, wear, and the clutter of a real street. |
| 0005 | [Real geography of Vũng Tàu](0005-real-geography.md) | Approved. The real ground, hills, coast, beaches, sea, and roads, from OpenStreetMap and the Copernicus elevation data. |
| 0006 | Known structures | Tượng Chúa Kitô Vua, Hải đăng, Bạch Dinh, Tượng Đức Mẹ Bãi Dâu, Miếu Hòn Bà (with its gate and the old bunkers), Chùa Tam Bảo, the ferry pier near Bãi Trước, the park of Bãi Trước, the main bus station, the old markets, the big roundabout, Ngã Năm, and others that I name. Made by code from their real outlines and sizes. |
| 0007 | Houses on the lots | A house generator that uses the kit of plan 0004 and puts houses on the lots between the roads. The homestay hẻm moves to its real place. |
| 0008 | Phở shop | Sit at the table. Order with the cuts ("một tô phở tái nạm gầu bò viên"), the extras, the herb plate, the sauces, eating, and paying. Port the flow from `docs/prototype/hem-2d.html`. |
| 0009 | Cà phê cóc | Order "đen đá", "sữa đá" or "nâu đá", "bạc sỉu". Watch the phin drip. |
| 0010 | Homestay meal | Eat with the host family. Home dishes and strong-smelling sauces. I name the dishes. |
| 0011 | Street snacks | Bánh mì at dawn, bánh khọt, hột vịt lộn, hủ tiếu gõ at night. |
| 0012 | Beach mornings and evenings | Morning exercise, the boats, the fish, the evening on the coast road. |
| 0013 | Hòn Bà at low tide | Check the tide, walk the rock path to Miếu Hòn Bà, and come back before the sea covers it. Locals warn the player about the time. |
| 0014 | Afternoon on the Vi Ba road | Jog or ride up Núi Lớn in the afternoon. Stop at Chùa Tam Bảo to watch the monkeys (and keep your bag closed). At the top, eat sữa chua and trứng lòng đào. |
| 0015 | Scooter | Wear a helmet and ride along the coast in the evening, and up the Vi Ba road. |
| 0016 | Release | Signed desktop builds (Windows, macOS, Linux), signed Android and iOS builds, store pages, privacy text. |
