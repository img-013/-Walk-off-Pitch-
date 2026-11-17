extends SceneTree
func _initialize():
 var scene=load("res://models/cabaret.glb").instantiate()
 own(scene,scene)
 var p=PackedScene.new();p.pack(scene);ResourceSaver.save(p,"res://models/cabaret_editable.tscn")
 scene.free();quit()
func own(n,root):
 for c in n.get_children():
  c.owner=root
  if c is Light3D:
   c.light_energy=0.28
   if c is OmniLight3D:c.omni_range=2.2
   if c.name=="TableLight":c.light_energy=2.6;c.spot_range=3.0;c.spot_angle=65.0
   elif c.name=="EnemyKeyLight":c.light_energy=0.5
   elif c.name=="AmbientFill_Cool":c.light_energy=0.12
   elif c.name=="CrimsonRim":c.light_energy=0.32
   if c is OmniLight3D:
    c.set_script(load("res://scripts/candle_flicker.gd"));c.phase=float(c.get_index())
  if c is Camera3D:c.current=false
  own(c,root)
