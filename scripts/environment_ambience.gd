extends AudioStreamPlayer
## Continuous outdoor ambience, attenuated indoors. Cinematics retain volume ownership.
const STREAM_PATH := "res://assets/audio/summer_afternoon.ogg"
const BASEMENT_STREAM_PATH := "res://assets/audio/basement_unease.wav"
const BASEMENT_VOLUME_DB := -25.0
const VOLUME_GAIN_DB := 2.278867 # 20 * log10(1.3): thirty percent more linear volume.
@export var indoor_volume_db := -28.0
@export var outdoor_volume_db := -8.0
@export var transition_seconds := 1.5
var listener: Node3D
var controller: Node
var house: Node3D
var footprint := Rect2(-6,-6,12,12)
var terraces: Array[Dictionary] = []
var outdoors := false
var basement_music: AudioStreamPlayer

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
	basement_music=AudioStreamPlayer.new();basement_music.name="BasementUndertone"
	basement_music.stream=make_basement_music();basement_music.volume_db=BASEMENT_VOLUME_DB
	add_child(basement_music)
	var source := load(STREAM_PATH) as AudioStreamOggVorbis
	if source==null:
		push_error("Summer afternoon ambience could not be loaded.")
		return
	var looped := source.duplicate() as AudioStreamOggVorbis
	looped.loop = true;stream = looped
	outdoors = is_outdoor_at(listener.global_position)
	volume_db = (outdoor_volume_db if outdoors else indoor_volume_db)+VOLUME_GAIN_DB
	play()

func make_basement_music() -> AudioStreamWAV:
	# Quiet midrange tones remain audible on small speakers without a loud bass bed.
	var source: AudioStreamWAV=load(BASEMENT_STREAM_PATH)
	var music:=source.duplicate() as AudioStreamWAV
	music.loop_mode=AudioStreamWAV.LOOP_FORWARD
	music.loop_begin=0;music.loop_end=roundi(music.get_length()*music.mix_rate)
	return music

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
	if not playing and not stream_paused:
		if basement_music.playing:basement_music.stop()
		return
	var ending: Node=controller.get_node_or_null("Ending") if is_instance_valid(controller) else null
	if ending and ending.flag("a11_escape"):
		basement_music.stop();stream_paused=false
		return
	var below_ground: bool=listener.global_position.y<-.45
	stream_paused=below_ground
	if below_ground:
		if not basement_music.playing:
			basement_music.volume_db=-58
			basement_music.play()
		basement_music.volume_db=lerpf(basement_music.volume_db,BASEMENT_VOLUME_DB,1-exp(-3.0*delta))
		return
	if basement_music.playing:
		basement_music.volume_db=lerpf(basement_music.volume_db,-60.0,1-exp(-3.0*delta))
		if basement_music.volume_db<-56:basement_music.stop()
	# The comic and dog scene already fade this same player; never fight their mix.
	if is_instance_valid(controller) and controller.cinematic_active:return
	outdoors = is_outdoor_at(listener.global_position,outdoors)
	var target := (outdoor_volume_db if outdoors else indoor_volume_db)+VOLUME_GAIN_DB
	volume_db = lerpf(volume_db,target,1-exp(-3.0*delta/maxf(.1,transition_seconds)))
