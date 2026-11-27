class_name SafeWait
## The screens' waits on the scene tree (P153, Combat Chat 69).
##
## F3 quick-loads mid-fight by restarting the game scene: the old scene leaves the tree at once and
## is freed at the end of the frame. A wait that ends in that frame (a timer, the next frame, a
## message line's end) resumes its function on a screen with no tree, and the next
## `get_tree().create_timer()` or `.process_frame` hit a null tree (Jeremy's 0.1.8, driders:
## combat_screen.gd's `_ai_step`). Off the tree these return the node's `tree_entered`, which a
## freed scene never sends: the function stops there and goes with the node.


## The next frame.
static func frame(n: Node) -> Signal:
	return n.get_tree().process_frame if n.is_inside_tree() else n.tree_entered


## `secs` seconds.
static func secs(n: Node, t: float) -> Signal:
	return n.get_tree().create_timer(t).timeout if n.is_inside_tree() else n.tree_entered
