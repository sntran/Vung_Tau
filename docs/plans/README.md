# Plans

A plan describes one block of work. The builder builds only what an approved plan describes.

## Status values

| Status | Meaning |
|---|---|
| Draft | The architect writes it. Do not build it. |
| Approved | The owner approved it. The builder can start. |
| In progress | The builder works on it. |
| Built | All unit tests and play tests pass. The architect audits it. |
| Done | The architect audited it, and the builder corrected all defects. |

## Plan file format

Each plan has these sections:

1. Status, branch, and dependencies.
2. Goal: what the owner gets at the end.
3. Out of scope.
4. Decisions, with the reason for each decision.
5. Requirements, numbered `R1`, `R2`, and so on.
6. Play-test scenarios, numbered `PT-01`, `PT-02`, and so on.
7. Acceptance criteria.
8. Open questions.

The builder writes questions and answers under "Open questions". The builder does not change the requirements. To change a requirement, the architect writes the change and the owner approves it.

## List of plans

| Number | Name | Status |
|---|---|---|
| 0001 | [Foundation and the walkable hẻm](0001-foundation.md) | Draft |

## Proposed order of the next plans

The order can change.

| Number | Name | Content |
|---|---|---|
| 0002 | [First-person walking](0002-first-person.md) | Written, status "Draft". The player sees through the eyes of the visitor and walks like a person. Landscape layout, joystick, look drag, gyroscope look, tap to walk. |
| 0003 | [Real geography of Vũng Tàu](0003-real-geography.md) | Written, status "Draft". The real ground, hills, coast, beaches, sea, and roads, from OpenStreetMap and the Copernicus elevation data. |
| 0004 | Known structures | Bãi Trước, Bãi Sau, Mũi Nghinh Phong, Tượng Chúa Kitô Vua, Hải đăng, Bạch Dinh, and others that the owner names. Made by code from their real outlines and sizes. |
| 0005 | Houses on the lots | A house generator with real proportions and a detail kit (shutters, balconies, wires, signs, plants). It puts houses on the lots between the roads. The homestay hẻm moves to its real place. |
| 0006 | Phở shop | Sit at the table. Order with the cuts ("một tô phở tái nạm gầu bò viên"), the extras, the herb plate, the sauces, eating, and paying. Port the flow from `docs/prototype/hem-2d.html`. |
| 0007 | Cà phê cóc | Order "đen đá", "sữa đá" or "nâu đá", "bạc sỉu". Watch the phin drip. |
| 0008 | Homestay meal | Eat with the host family. Home dishes and strong-smelling sauces. The owner names the dishes. |
| 0009 | Street snacks | Bánh mì at dawn, bánh khọt, hột vịt lộn, hủ tiếu gõ at night. |
| 0010 | Beach mornings and evenings | Morning exercise, the boats, the fish, the evening on the coast road. |
| 0011 | Scooter | Wear a helmet and ride along the coast in the evening. |
| 0012 | Store release | Signed Android and iOS builds, store pages, privacy text. |
