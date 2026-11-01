extends RefCounted
## Reusable player-action sequences; never set quest completion flags directly.
static func pull_yarn(tree: SceneTree,interaction) -> bool:
 if not interaction.running:return false
 interaction.dragging=true
 for point in [Vector3(-5.30,.11,1.97),Vector3(-5.30,.11,2.15),Vector3(-4.48,.11,2.15)]:
  if not interaction.running:break
  interaction.goal=point
  for frame in range(150):
   await tree.physics_frame
   if not interaction.running or interaction.tip.distance_to(point)<.002:break
 return interaction.day.flag("yarn_freed")
static func rinse_plate(chapter) -> void:
 var interaction=chapter.rinse
 interaction.set_physics_process(false)
 for i in range(3):
  interaction.offset=-interaction.OFFSETS[i];interaction.update_plate();interaction.advance(interaction.DURATIONS[i]+.1)
