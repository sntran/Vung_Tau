class_name Layers
extends RefCounted
## The physics layers.

## The ground that the player walks on.
const FLOOR := 1
## The areas that a tap or the focus can find: spots and people.
const TOUCH := 2
## Walls and objects that stop the player: houses, carts, stools, people, trees.
const SOLID := 4
## People that move, for example the hủ tiếu gõ helper. The navigation mesh
## does not use this layer, so the walk area does not change when they move.
const MOVING := 8
