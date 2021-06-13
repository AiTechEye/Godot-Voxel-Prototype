extends Spatial

var timer = 0
var chunks_in_progress = {}
var progress2del = {}

func _init():
	core.chunk=self

#creates a new chunk array
#adds air to it so the player not reaching a empty space and things craches
func new_chunk(pos):
	var id = pos_to_chunkid(pos)
	var chunk_pos = to_chunk_pos(pos)
	var air = core.get_node_reg("air").id
	for x in range(-core.chunk_size/2,core.chunk_size/2):
		for y in range(-core.chunk_size/2,core.chunk_size/2):
			for z in range(-core.chunk_size/2,core.chunk_size/2):
				core.inset_map_node_id(air,chunk_pos+Vector3(x,y,z))
	core.chunks[id] = MeshInstance.new()
	var chunk = core.chunks[id]
	chunk.transform.origin = chunk_pos
	add_child(chunk)
	var staticbody = StaticBody.new()
	staticbody.name = "body"
	chunk.add_child(staticbody)
	var collision = CollisionShape.new()
	collision.name = "collision"
	staticbody.add_child(collision)

func to_chunk_pos(pos):
	var c = core.chunk_size
	var s = core.chunk_size/2
	return ((pos+Vector3(s,s,s))/c).floor()*c
	
func get_chunk_at_pos(pos):
	var c = core.chunk_size
	var s = core.chunk_size/2
	var c_pos = ((pos+Vector3(s,s,s))/c).floor()
	return core.chunks.get(c_pos)
	
func pos_to_chunkid(pos):
	var c = core.chunk_size
	var s = core.chunk_size/2
	return ((pos+Vector3(s,s,s))/c).floor()
	
func get_chunk(id):
	return core.chunks.get(id)

#sends chunks to update in a list to process
#this keeps performance well, even we can expect somewhat slower loading
func _process(delta):
	timer += delta
	if timer > 0.0:
		timer = 0
		
		for i in progress2del:
			chunks_in_progress.erase(i)
		progress2del.clear()
		var max_nodes = core.settings.max_update_nodes
		for di in chunks_in_progress:
			var data = chunks_in_progress.get(di)
			var chunk_mesh = get_chunk(data.chunkid)
			for x in range(data.range_x.a,data.range_x.b):
				for y in range(data.range_y.a,data.range_y.b):
					for z in range(data.range_z.a,data.range_z.b):

						max_nodes -= 1
						if max_nodes < 0:
							data.range_x.a = x
							data.range_y.a = y
							data.range_z.a = z
							return
						
						var lpos = Vector3(x,y,z)
						var id = core.map.get(lpos+data.chunk_pos)
						
						if id:
							var n = core.register.id.get(id) if id != null else "default"
							var reg = core.register.nodes.get(n)
							var tile = core.default_texture if reg.tiles.size() < 1 else reg.tiles[0]
							if reg.drawtype != "none":
								for f in core.default_node.faces.size():
									var neighbour_id = core.map.get(lpos+core.default_node.dir[f]+data.chunk_pos)
									var neighbour_name = core.register.id.get(neighbour_id) if neighbour_id != null else "none"
									var neighbour_reg = core.register.nodes.get(neighbour_name)
									
									if (data.full_cubes and neighbour_id == null) or (neighbour_id != id and neighbour_reg.get("solid_surface") == false):
										data.st.begin(Mesh.PRIMITIVE_TRIANGLE_FAN)
										var mat = SpatialMaterial.new()
										var transparent = reg.get("transparent") == true
										if f < reg.tiles.size():
											tile = reg.tiles[f]
										mat.albedo_texture = tile
										mat.flags_transparent = transparent 
										data.st.set_material(mat)
										data.st.add_color(Color(0,1,1))
										var cmf = []
										for v in range(0,4):
											data.st.add_uv(core.default_node.uv[v])
											data.st.add_vertex(core.default_node.faces[f][v]+lpos)
											cmf.push_back(core.default_node.faces[f][v]+lpos)
										
											data.st.commit(data.mesh)
										# the faces is added, now add to the collision
										# the TRIANGLE_FAN allows us to be more flexible models, but the trimesh do not work with it
										# so we are using TRIANGLES for that
										if reg.get("collidable") != false:
											data.cst.begin(Mesh.PRIMITIVE_TRIANGLES)
											data.cst.add_triangle_fan(cmf)
											data.cst.commit(data.collision_mesh)
			data.st.clear()
			data.cst.clear()
			chunk_mesh.mesh = data.mesh
			chunk_mesh.get_node_or_null("body/collision").shape = data.collision_mesh.create_trimesh_shape()
			chunks_in_progress.erase(di)
			progress2del[di] = di
			# the chunk is done, now work on next update
func update(pos):
	if get_chunk_at_pos(pos) == null:
		new_chunk(pos)
		#no chunk here, generate it quickly
		core.current_mapgen.call_func(to_chunk_pos(pos))
		return
		
	var chunkid =  pos_to_chunkid(pos)
	var data = {
		vertex = {},
		full_cubes = core.settings.full_3d_cubes,
		mesh = Mesh.new(),
		collision_mesh = Mesh.new(),
		chunkid =  chunkid,
		chunk_pos = get_chunk(chunkid).transform.origin,
		st = SurfaceTool.new(),
		cst = SurfaceTool.new(),
		range_x = {a=-core.chunk_size/2,b=core.chunk_size/2},
		range_y = {a=-core.chunk_size/2,b=core.chunk_size/2},
		range_z = {a=-core.chunk_size/2,b=core.chunk_size/2},
	}
	chunks_in_progress[chunkid] = data
