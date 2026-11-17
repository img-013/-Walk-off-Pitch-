extends SceneTree
func _initialize():
 for name in ["tavern_interior","round_table","blank_die"]:
  var scene=load("res://models/"+name+".glb").instantiate()
  if name=="blank_die":
   var mesh=scene.find_children("*","MeshInstance3D",true,false)[0]
   ResourceSaver.save(mesh.mesh,"res://models/die_mesh.tres")
  else:
   own(scene,scene)
   var pack=PackedScene.new();pack.pack(scene);ResourceSaver.save(pack,"res://models/"+name+".tscn")
  scene.free()
 quit()
func own(node,root):
 for child in node.get_children():
  child.owner=root
  own(child,root)
