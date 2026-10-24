extends AudioStreamPlayer
## Continuous outdoor ambience, attenuated indoors. Cinematics retain volume ownership.
const STREAM_PATH := "res://assets/audio/summer_afternoon.ogg"
@export var indoor_volume_db := -28.0
@export var outdoor_volume_db := -8.0
@export var transition_seconds := 1.5
var listener: Node3D
var controller: Node
var house: Node3D
var footprint := Rect2(-6,-6,12,12)
var terraces: Array[Dictionary] = []
var outdoors := false

func configure(actor: Node3D, game: Node, building: Node3D) -> void:
	listener = actor;controller = game;house = building
	if not is_instance_valid(house):return
	var size: Vector2 = house.get_meta("building_size",Vector2(12,12))
	footprint = Rect2(-size*.5,size)
	for zone in house.get_meta("room_zones",[]):
		if zone.name!="露台":continue
		var bounds: Rect2 = zone.bounds
		bounds.position -= size*.5
		terraces.append({"bounds":bounds,"floor_y":float(zone.floor)*3.0})

func _ready() -> void:
	name = "SummerAfternoonAmbience"
	var source := load(STREAM_PATH) as AudioStreamOggVorbis
	if source==null:
		push_error("Summer afternoon ambience could not be loaded.")
		return
	var looped := source.duplicate() as AudioStreamOggVorbis
	looped.loop = true;stream = looped
	outdoors = is_outdoor_at(listener.global_position)
	volume_db = outdoor_volume_db if outdoors else indoor_volume_db
	play()

func is_outdoor_at(world_point: Vector3, was_outside := false) -> bool:
	var point := house.to_local(world_point) if is_instance_valid(house) else world_point
	# The basement remains muffled even where its footprint extends past a wall.
	if point.y<-.20:return false
	var flat := Vector2(point.x,point.z)
	# An 8 cm margin prevents doorway jitter from repeatedly switching levels.
	if not footprint.grow(-.08 if was_outside else .08).has_point(flat):return true
	for terrace in terraces:
		var bounds: Rect2 = terrace.bounds
		if point.y>=terrace.floor_y-.4 and bounds.grow(.08 if was_outside else -.08).has_point(flat):return true
	return false

func _process(delta: float) -> void:
	if not is_instance_valid(listener):return
	# The comic and dog scene already fade this same player; never fight their mix.
	if is_instance_valid(controller) and controller.cinematic_active:return
	outdoors = is_outdoor_at(listener.global_position,outdoors)
	var target := outdoor_volume_db if outdoors else indoor_volume_db
	volume_db = lerpf(volume_db,target,1-exp(-3.0*delta/maxf(.1,transition_seconds)))
