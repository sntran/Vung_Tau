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

These plans are not written yet. The order can change.

| Number | Name | Content |
|---|---|---|
| 0002 | Look of the hẻm | Tube houses with true proportions and materials, light by time of day, the sea, people. The goal is a real place, not boxes. |
| 0003 | Phở shop | The table close-up. Order with the cuts ("một tô phở tái nạm gầu bò viên"), the extras, the herb plate, the sauces, eating, and paying. Port the flow from `docs/prototype/hem-2d.html`. |
| 0004 | Cà phê cóc | Order "đen đá", "sữa đá" or "nâu đá", "bạc sỉu". Watch the phin drip. |
| 0005 | Homestay meal | Eat with the host family. Home dishes and strong-smelling sauces. The owner names the dishes. |
| 0006 | Street snacks | Bánh mì at dawn, bánh khọt, hột vịt lộn, hủ tiếu gõ at night. |
| 0007 | Bãi Trước | Morning exercise, the boats, the fish, the evening on the coast road. |
| 0008 | Scooter | Wear a helmet and ride along the coast in the evening. |
| 0009 | Store release | Signed Android and iOS builds, store pages, privacy text. |
