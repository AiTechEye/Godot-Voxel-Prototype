extends Control

var _screeninfo = {
	player_pos = Vector3(),
	chunk_id = Vector3(),
	chunk_pos = Vector3(),
	pointing_at = "",
}

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	var ss = get_viewport_rect().size/2
	var cs = $crosshair.rect_size / 2
	$crosshair.rect_position = ss - cs
	
	var p = OS.get_screen_size()/2
	var s = OS.window_size/2
	var winpos = p-s
	winpos.y = 0 #now we can see the output
	OS.set_window_position(winpos)

#if you are not trying to solve a problem, this one is kinda useless
func screeninfo(lab,v):
	_screeninfo[lab] = v
	var s = _screeninfo.player_pos.round()
	var c = _screeninfo.chunk_id
	var p = _screeninfo.chunk_pos
	$screeninfo.text = str("Pos: ",s.x,",",s.y,",",s.z," Chunk ID: ",c.x,",",c.y,",",c.z," Chunk pos: ",p.x,",",p.y,",",p.z," Pointing at: ",_screeninfo.pointing_at)
