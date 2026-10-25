extends SceneTree
## Runs the real rendered scene, captures only its viewport, then exits.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://main.tscn").instantiate()
	app.save_path = "user://preview-only-never-written.json"
	root.add_child(app)
	for frame in range(5):
		await process_frame
	app.queue_redraw()
	await RenderingServer.frame_post_draw
	var warm_styles: int = app._style_cache.size()
	# Exercise the actual renderer repeatedly, rather than measuring a mock.
	for frame in range(20):
		app.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	if app._style_cache.size() != warm_styles:
		push_error("Style cache grew during repeated unchanged board rendering")
		quit(1)
		return
	print("RENDER: stable style cache across 20 redraws (", warm_styles, " resources)")
	var path: String = ProjectSettings.globalize_path("res://../Builds/SummitShards-preview.png")
	var image: Image = root.get_texture().get_image()
	var result: int = image.save_png(path)
	print("Native viewport capture: ", path, " result=", result)
	quit(0 if result == OK else 1)
