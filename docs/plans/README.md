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
| 0003 | [Voices and the phone](0003-voices-and-phone.md) | Done |
| 0004 | [Desktop and the house detail kit](0004-desktop-and-house-detail.md) | Built |
| 0005 | [Real geography of Vũng Tàu](0005-real-geography.md) | Built |
| 0006 | [People](0006-people.md) | Approved |
| 0007 | [Who you are: the passport and the forms of address](0007-who-you-are.md) | Approved |
| 0020 | [Real trees](0020-real-trees.md) | Approved |

## Proposed order of the next plans

The order can change. A number is only a name: plans 0020 to 0022 were added after 0019, and they come earlier in the order.

| Number | Name | Content |
|---|---|---|
| 0003 | [Voices and the phone](0003-voices-and-phone.md) | Done. People speak aloud in Vietnamese with subtitles. The traveler's phone has Listen (transcribe and translate), Lens, Messages, Sổ tay, Clock, and Settings. It replaces the talk panel and the 2D sheets. |
| 0004 | [Desktop and the house detail kit](0004-desktop-and-house-detail.md) | Built (all defects fixed; I try the macOS and Windows builds after plan 0008). Desktop becomes the main platform, with the Forward+ renderer and quality presets. Tube houses get depth, brick under plaster and paint, wear, and the clutter of a real street. |
| 0005 | [Real geography of Vũng Tàu](0005-real-geography.md) | Built. The real ground, hills, coast, beaches, sea, and roads, from OpenStreetMap and the Copernicus elevation data. |
| 0006 | [People](0006-people.md) | Approved. People with real bodies, faces, hair, and clothes, made by code with MPFB 2. Library animations, head and eye movement, blinks, faces for each line, and lip sync from the voice audio. |
| 0007 | [Who you are](0007-who-you-are.md) | Approved. Cô Nga asks for a photo of the passport for the police registration. The player sets the age and the gender. People address the traveler with the correct kinship words (con, em, anh, chị, chú, cô…), and the traveler answers with the correct words. |
| 0020 | [Real trees](0020-real-trees.md) | Approved. Trees made by code in Blender, with real leaves near the player and simpler forms far away: coconut palms at Bãi Trước, bàng, casuarina, phượng vĩ, hoa sứ, palms, the street shade trees, and the hill forest. They move in the wind and follow the season. |
| 0008 | Known structures | Tượng Chúa Kitô Vua, Hải đăng, Bạch Dinh, Tượng Đức Mẹ Bãi Dâu, Miếu Hòn Bà (with its gate and the old bunkers), Chùa Tam Bảo, the ferry pier near Bãi Trước, Cảng Cầu Đá (the old French stone jetty on Hạ Long), Nhà thờ lớn Vũng Tàu and Tượng đài Trần Hưng Đạo on Trần Hưng Đạo, the temples and pagodas on the slope above Hạ Long, the park of Bãi Trước, the main bus station, the old markets (with chợ Xóm Lưới), the big roundabout, Ngã Năm, and others that I name. Made by code from their real outlines and sizes. |
| 0009 | Houses on the lots | A house generator that uses the kit of plan 0004 and puts houses on the lots between the roads. Houses are not in line: they face in different directions, with different depths, back extensions, and roofs at many heights. The real homestay hẻm (Hẻm 2 Hải Đăng) replaces the test street: only homes, the slope of Núi Nhỏ on one side with some houses on it, one row of houses on the other. The homestay is on an empty lot on the slope side, with terraces behind it for the garden of plan 0022. The shops and the people of the test street (Cô Sáu, Bác Hà, Cô Út, the cà phê cóc, the bánh mì and hủ tiếu gõ carts) move to the streets near chợ Xóm Lưới. Bà Tư and cô Nga stay at the homestay. The houses use public data of 2019: [Google Open Buildings 2.5D Temporal](https://sites.research.google/gr/open-buildings/temporal) gives where buildings stood and how tall they were each year from 2016 to 2023 (about 4 m, CC BY 4.0 or ODbL), so the town is as it was in 2019, with no newer towers. |
| 0010 | Arrival | The game starts on Tuesday 22 January 2019 at the bus station (Bến xe Vũng Tàu). The player can walk anywhere, or take a taxi or a ride from a ride app (a fictional app, not a real brand) to the homestay. At the door, the traveler shows the passport, and cô Nga registers the stay. |
| 0011 | Phở shop | Sit at the table. Order with the cuts ("một tô phở tái nạm gầu bò viên"), the extras, the herb plate, the sauces, eating, and paying. Port the flow from `docs/prototype/hem-2d.html`. |
| 0012 | Cà phê cóc | Order "đen đá", "sữa đá" or "nâu đá", "bạc sỉu". Watch the phin drip. |
| 0013 | Homestay meal | Eat with the host family. Home dishes and strong-smelling sauces. I name the dishes. |
| 0014 | Street snacks | Bánh mì at dawn, bánh khọt, hột vịt lộn, hủ tiếu gõ at night. |
| 0021 | Tết | The two weeks before Tết and the first days of the year (day 1 to about day 22). The markets sell Tết items. Houses decorate. The flower market at Bãi Trước sells hoa mai, hoa đào, and other plants, and people carry them home. The family makes bánh tét (and a Northern neighbor bánh chưng): the old way over a wood fire through the night, or a new way, or they buy them. Ông Táo on day 7, the five-fruit tray, giao thừa on the night of day 14 (30 Tết), lì xì, and the quiet streets of Mùng 1. Facts in the culture notes, section Tết. |
| 0015 | Beach mornings and evenings | Morning exercise, the boats moored all over the bay, the fishermen near the rocks at the south end, the flat rocks at low tide, the fish, and the evening swim of the families at the main beach, with rented swim rings. The evening on the coast road. |
| 0016 | Hòn Bà at low tide | Check the tide, walk the rock path to Miếu Hòn Bà, and come back before the sea covers it. Locals warn the player about the time. |
| 0017 | Afternoon on the Vi Ba road | Jog or ride up Núi Lớn in the afternoon. Stop at Chùa Tam Bảo to watch the monkeys (and keep your bag closed). At the top, eat sữa chua and trứng lòng đào. |
| 0018 | Scooter | Wear a helmet and ride along the coast in the evening, and up the Vi Ba road. |
| 0022 | The homestay garden | A small farming game on the terraces behind the homestay: small terraced rice fields (like ruộng bậc thang, but smaller), vegetables and herbs, five fruit trees (mãng cầu, đu đủ, chuối, xoài, dừa), a small fish pond, and a few animals (chickens and pigs). The player plants, waters, picks, and feeds the animals and the fish with Bà Tư, and the food goes to the family meals and the Tết tray. |
| 0019 | Release | Signed desktop builds (Windows, macOS, Linux), signed Android and iOS builds, store pages, privacy text. |
