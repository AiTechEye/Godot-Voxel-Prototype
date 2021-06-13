extends Node

var chunk #noderef functions
var chunks = {} #contains all chucks, using Vector3() as keys or "id"
var chunk_size=8#16 are more common for this kind of game, but is 4X slower to update

var default_texture = load("res://res/stone.png")#used if we are unable to get the nodes tiles
var player = {name="singleplayer",object=null,inventory=["stone","dirt","grassy","water_source"],inventory_index=0}
var map = {}#contains all nodes, using Vector3() as keys or "id", contains a number/node id, strings would use too much memory
var collision_map = {}
var settings = {
		full_3d_cubes=false,
		update_chunk_rules=[Vector3(-1,0,0),Vector3(1,0,0),Vector3(0,0,-1),Vector3(0,0,1),Vector3(0,-1,0),Vector3(0,1,0)],
		ganerate_chunk_range=4,
		max_update_nodes=512,
	}
var default_node_id = 7
var mapgen = {}
var current_mapgen # funcref
var register = {
	nodes = {
		none={id=0,name="none",drawtype="none",tiles=[]},
		air={id=1,name="air",drawtype="none",tiles=[],collidable=false,solid_surface=false},
		stone={id=2,name="stone",drawtype="default",tiles=[load("res://res/stone.png")]},
		grassy={id=3,name="grassy",drawtype="default",tiles=[
				load("res://res/grass.png"),
				load("res://res/dirt.png"),
				load("res://res/grass_dirt.png"),
				load("res://res/grass_dirt.png"),
				load("res://res/grass_dirt.png"),
				load("res://res/grass_dirt.png"),
				]},
		dirt={id=4,name="dirt",drawtype="default",tiles=[load("res://res/dirt.png")]},
		water_source={id=5,name="water_source",replaceable=true,drawtype="liquid",collidable=false,transparent=true,solid_surface=false,tiles=[load("res://res/water.png")]},
	},
	id = {0:"none",1:"air",2:"stone",3:"grassy",4:"dirt",5:"water_source"},
}
var default_node = {
	uv = [Vector2(0,0),Vector2(0,1),Vector2(1,1),Vector2(1,0)],
	dir = [Vector3(0,1,0),Vector3(0,-1,0),Vector3(1,0,0),Vector3(-1,0,0),Vector3(0,0,-1),Vector3(0,0,1)],
	faces = [
		[Vector3(1,0,0),Vector3(1,0,1),Vector3(0,0,1),Vector3(0,0,0)], #up y+
		[Vector3(0,-1,0),Vector3(0,-1,1),Vector3(1,-1,1),Vector3(1,-1,0)], #down y-
		[Vector3(1,0,0),Vector3(1,-1,0),Vector3(1,-1,1),Vector3(1,0,1)], #north x+
		[Vector3(0,0,1),Vector3(0,-1,1),Vector3(0,-1,0),Vector3(0,0,0)], #south x-
		[Vector3(0,0,0),Vector3(0,-1,0),Vector3(1,-1,0),Vector3(1,0,0)], #east z+
		[Vector3(1,0,1),Vector3(1,-1,1),Vector3(0,-1,1),Vector3(0,0,1)], #west z-
	]
}

#returns name of node you are pointing at, pos would be more usefull i think
#use the penultimate pos to get the node next to it
func pointed_at_node():
	var pos = player.object.get_translation()
	var aim = player.object.get_node("head/Camera").get_global_transform().basis
	var hpos = player.object.get_node("head").get_translation()
	for i in range(-1,-500,-1):
		var p = (pos + hpos+(aim.z*Vector3(i*0.01,i*0.01,i*0.01)))#.round()
		var rp = p.round()
		var id = map.get(rp)
		var reg = get_node_reg(id)
		if reg != null and reg.get("drawtype") != "none" and reg.get("collidable") != false:
				if (p.x >= rp.x-0.5 and p.x <= rp.x+0.5) and (p.y >= rp.y-0.5 and p.y <= rp.y+0.5) and (p.z >= rp.z-0.5 and p.z <= rp.z+0.5):
					return reg.name
	return "none"


#problity you finds a better way to use this
#but this is what i used while testing
func pointed_node_action(n):
	var pos = player.object.get_translation()
	var aim = player.object.get_node("head/Camera").get_global_transform().basis
	var hpos = player.object.get_node("head").get_translation()
	var lpos = (pos + hpos+aim.z).round()
	
	for i in range(-1,-500,-1):
		var p = (pos + hpos+(aim.z*Vector3(i*0.01,i*0.01,i*0.01)))#.round()
		var rp = p.round()
		var id = map.get(rp)
		

		if id and id != 1:
			if core.chunk.get_chunk_at_pos(rp):
				if (p.x >= rp.x-0.5 and p.x <= rp.x+0.5) and (p.y >= rp.y-0.5 and p.y <= rp.y+0.5) and (p.z >= rp.z-0.5 and p.z <= rp.z+0.5):
					var node = player.inventory[player.inventory_index] if n == 0 else "air"
					var pp = rp
					if n == 0:
						var Name = register.id[id]
						var reg = register.nodes[Name]
						pp = rp if reg.get("replaceable") == true else lpos
					set_node({name=node,pos=pp})
					return
		lpos = rp

func get_node_reg(v):#a flexible way to get node properties by pos, id or name
	if v is Vector3:
		v = v.round()
		v = map.get(v)
	elif v is String:
		return register.nodes.get(v)
	var n = register.id.get(v)
	return register.nodes.get(n)

func get_node(pos):#returns node id
	assert(typeof(pos) == TYPE_VECTOR3,"ERROR: set_node: pos required!")
	return map.get(pos)
	
func set_node(def:Dictionary):# set node
	assert(typeof(def.get("pos")) == TYPE_VECTOR3 and typeof(def.get("name")) == TYPE_STRING,"ERROR: set_node: def.pos & def.name required!")
	var n = register.nodes.get(def.name)
	assert(n != null,str('ERROR: set_node: "',def.name,'"', " doesn't exists"))
	var rpos = def.pos.round()
	map[rpos] = get_node_reg(def.name).id

#check if chunks around the node need to be updated
	var cid = chunk.pos_to_chunkid(rpos)
	for r in settings.update_chunk_rules.size():
		var near_chunk = rpos+settings.update_chunk_rules[r]
		if chunk.pos_to_chunkid(near_chunk) != cid:
			chunk.update(near_chunk)
#check the chunk
	chunk.update(rpos)

func inset_map_node_id(id,pos):# easyer to use
	map[pos] = id
