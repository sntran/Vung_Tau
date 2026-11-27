extends GutTest
## Report 0031, D-0031-06: the touch controls of CI ended with exit code 134 (an
## abort) when the game quit about 1 s after its first frame. The ground of the
## Vũng Tàu world started its chunks and patches in other threads, kept no
## handle of them, and did not wait for them when it left the tree: a task could
## still run on the world while the world was freed. The world now keeps each
## task and waits for it when it leaves the tree (as the town does).


func test_the_world_waits_for_its_tasks_when_it_leaves_the_tree() -> void:
	var world := VungTau.new()
	add_child(world)
	var done := {"count": 0}
	for i in 3:
		world.add_task(func() -> void:
			OS.delay_msec(150)
			done.count += 1, "test")
	assert_eq(world.task_count(), 3, "the world keeps a handle of each task")
	remove_child(world)
	assert_eq(done.count, 3, "each task is done when the world leaves the tree")
	assert_eq(world.task_count(), 0)
	world.free()
