extends SceneTree

func _initialize() -> void:
	var builder = load("res://scripts/villa_builder.gd").new()
	var villa: Node3D = builder.build()
	root.add_child(villa)
	var packed := PackedScene.new()
	var result := packed.pack(villa)
	if result==OK:
		for attempt in range(5):
			result = ResourceSaver.save(packed,"res://scenes/villa.tscn")
			if result==OK:break
			OS.delay_msec(150)
	print("VILLA_BUILD ",JSON.stringify({"result":result,"groups":villa.get_child_count(),"building_m":[12,12],"site_m":[22,28],"storeys":2,"stair_risers":18}))
	villa.free()
	quit(0 if result==OK else 1)
