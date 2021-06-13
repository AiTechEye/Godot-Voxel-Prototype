extends Node

var timer = 1

func _ready():
	core.current_mapgen = funcref(self,"super_flatland")
	yield(get_tree().create_timer(2),"timeout")
	for x in range(-4,4):
		for z in range(-4,4):
			core.inset_map_node_id(5,Vector3(x,0,z))
	core.chunk.update(Vector3(0,0,0))

var n2gc_timer = -0.01
var n2gc_time = 0
func _process(delta):
	timer += delta
	if timer > n2gc_time:
		if n2gc_timer >= 1:
			n2gc_timer = 0
			n2gc_time = 1
		else:
			n2gc_timer += timer
		timer = 0

		var ppos = core.player.object.global_transform.origin
		
		var pos = core.chunk.to_chunk_pos(ppos)
		if core.chunk.get_chunk_at_pos(pos) == null:
			core.chunk.new_chunk(pos)
			core.current_mapgen.call_func(pos)
			n2gc_time = 0
			n2gc_timer = 0
		#return
		for i in range(1,core.settings.ganerate_chunk_range):
			var r = core.chunk_size*i
			var s = core.chunk_size
			for x in range(-r,r,s):
				for y in range(-r,r,s):
					for z in range(-r,r,s):
						pos = Vector3(x,y,z) + core.chunk.to_chunk_pos(ppos)
						if core.chunk.get_chunk_at_pos(pos) == null:
							core.chunk.new_chunk(pos)
							core.current_mapgen.call_func(pos)
							n2gc_time = 0
							n2gc_timer = 0
							
#generates a flat map:
#all nodes above 9 will be air
#0 = grassy
#-1 - -3 = dirt
#-4 and lower = stone
func super_flatland(pos):
	var id
	var grassy = core.get_node_reg("grassy").id
	var dirt = core.get_node_reg("dirt").id
	var stone = core.get_node_reg("stone").id
	var air = core.get_node_reg("air").id
	var Y
	for x in range(-core.chunk_size/2,core.chunk_size/2):
		for y in range(-core.chunk_size/2,core.chunk_size/2):
			for z in range(-core.chunk_size/2,core.chunk_size/2):
				Y = pos.y+y
				if Y == 0:
					id = grassy
				elif Y < -3:
					id = stone
				elif Y < 0:
					id = dirt
				else:
					id = air
				core.inset_map_node_id(id,Vector3(x,y,z)+pos)
	core.chunk.update(pos)
