extends Node

## Editor-only: reports the minimum size each modal panel wants versus the
## 1280x720 design viewport, so a panel that has outgrown the screen shows up
## as a number instead of a clipped button someone notices on a phone.

const PANELS: Array[String] = [
	"res://descent/scenes/ui/permanent_upgrades.tscn",
	"res://descent/scenes/ui/pause_menu.tscn",
	"res://descent/scenes/ui/run_summary.tscn",
	"res://descent/scenes/ui/shop_panel.tscn",
]


func _ready() -> void:
	var view := get_viewport().get_visible_rect().size
	print("design viewport: %s\n" % view)

	for path in PANELS:
		var panel: Control = (load(path) as PackedScene).instantiate()
		add_child(panel)
		panel.show()
		for _i in 4:
			await get_tree().process_frame

		var frame := panel.get_node_or_null("Frame") as Control
		var wanted := Vector2.ZERO if frame == null else frame.get_combined_minimum_size()
		var verdict := "fits"
		if wanted.y > view.y:
			verdict = "OVERFLOWS by %.0f px" % (wanted.y - view.y)
		elif wanted.y > view.y * 0.92:
			verdict = "tight (%.0f px spare)" % (view.y - wanted.y)
		print("%-34s frame min %6.0f x %-6.0f %s"
			% [path.get_file(), wanted.x, wanted.y, verdict])

		panel.queue_free()
		await get_tree().process_frame

	get_tree().quit()
