extends SceneTree
const Game=preload("res://presentation/approved_game.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:
	create_timer(180).timeout.connect(func(): quit(1))
	call_deferred("run")
func expect(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL ",message)
func frames(n:int=4)->void:
	for i in range(n):await process_frame
func button(c:Node,id:int,down:bool=true)->void:
	var e:=InputEventJoypadButton.new();e.device=0;e.button_index=id;e.pressed=down;c._input(e)
func find_road_point(g:Node)->Vector2:
	var road_point:=Vector2.ZERO
	for y in range(14,19):
		for x in range(10,16):
			var cell:=Vector2i(x,y)
			var point:Vector2=g.world.camera.unproject_position(Vector3(x*g.world.CELL,0,y*g.world.CELL))
			if g.sim.can_place_road(cell).is_empty() and not g.hud.blocks_pointer(point):road_point=point;break
		if road_point!=Vector2.ZERO:break
	return road_point
func run()->void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.size=Vector2i(1280,800)
	var g=Game.new();g.resume_on_start=false;root.add_child(g);g.set_process(false)
	g.hud._dismiss_tutorial();g.hud._toast.hide();await frames()
	var c=g.controller;c.set_process(false)
	button(c,JOY_BUTTON_X);await frames()
	expect(g.hud._drawer.visible,"X opens build drawer")
	button(c,JOY_BUTTON_B);expect(not g.hud._drawer.visible and g.build_kind.is_empty(),"B closes panels/cancels placement")
	button(c,JOY_BUTTON_Y);await frames();expect(g.hud._drawer.visible,"Y opens worker training")
	button(c,JOY_BUTTON_B)
	var focus:Vector3=g.world.target_focus
	c.motion_axes=Vector4(1,0,0,0);c._process(0.1)
	expect(g.world.target_focus!=focus,"left stick moves camera")
	var pointer:Vector2=c.pointer;c.motion_axes=Vector4(0,0,1,0);c._process(0.1)
	expect(c.pointer.x>pointer.x,"right stick moves cursor")
	var zoom:float=g.world.target_size
	button(c,JOY_BUTTON_DPAD_UP);c._process(0.1);button(c,JOY_BUTTON_DPAD_UP,false)
	expect(g.world.target_size<zoom and c.zoom_hold==0,"D-pad zoom and release")
	var yaw:float=g.world.target_yaw;button(c,JOY_BUTTON_RIGHT_SHOULDER)
	expect(g.world.target_yaw>yaw,"shoulder rotates camera")
	button(c,JOY_BUTTON_RIGHT_STICK);expect(g.build_kind=="road","R3 selects road tool")
	c._set_click_source("a",true);c._set_click_source("trigger",true);c._set_click_source("trigger",false)
	expect(c.clicking,"trigger release does not cancel held A")
	c._connection(0,false)
	expect(not c.clicking and not c.controller_active and c.motion_axes==Vector4.ZERO,"disconnect releases held inputs")
	button(c,JOY_BUTTON_B)
	button(c,JOY_BUTTON_START);await frames();expect(g.hud._menu.visible,"Menu opens settings")
	button(c,JOY_BUTTON_B)
	g.hud.request_reset("load_mission",{"id":"tsk-01"});await frames()
	expect(g.hud._reset_dialog.visible and g.sim.mission==null,"mission switch waits for confirmation")
	button(c,JOY_BUTTON_B)
	expect(not g.hud._reset_dialog.visible and g.hud._pending_reset.is_empty(),"B cancels scenario confirmation")
	# Root UI clicks are exercised through the same virtual mouse events as gameplay.
	g.hud._toggle_menu();await frames()
	g.hud._menu_scroll.ensure_control_visible(g.hud._sound_button);await frames()
	c._activate(0);c.pointer=g.hud._sound_button.get_global_rect().get_center()
	var audio_on:bool=g.audio.enabled;c._click(true);await frames();c._click(false);await frames()
	expect(g.audio.enabled!=audio_on,"A/trigger virtual click operates a real menu button")
	g.audio.set_enabled(audio_on)
	# The same controller click path reaches the road tool in the world.
	g.hud.close_panels();g.hud._toast.hide();g._select_build("road");await frames()
	var road_count:int=g.sim.roads.size()
	var road_point:Vector2=find_road_point(g)
	c.pointer=road_point;c._click(true);await frames();c._click(false);await frames()
	expect(road_point!=Vector2.ZERO and g.sim.roads.size()>road_count,"controller selection places an actual road tile")
	var cancel_point:Vector2=find_road_point(g);c.pointer=cancel_point
	road_count=g.sim.roads.size();c._click(true);await frames();button(c,JOY_BUTTON_B);await frames()
	expect(cancel_point!=Vector2.ZERO and g.sim.roads.size()==road_count and not g.pointer_down,"B cancels a held road stroke without placing it")
	g._select_build("road");c.pointer=find_road_point(g);c._click(true);await frames();c._connection(0,false);await frames()
	expect(g.sim.roads.size()==road_count and not g.pointer_down,"disconnect cancels a held road stroke")
	# Invalid import must leave the active simulation untouched.
	var before:Dictionary=g.sim.snapshot();expect(not g._import_save_text("{}") and g.sim.snapshot()==before,"invalid import preserves village")
	g.queue_free();await frames(2)
	print("CONTROLLER_RESULT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
