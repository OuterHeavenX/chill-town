extends SceneTree
## Headless checks for the Chill Town additions: English by default, the touch
## camera pad, the phone-sized HUD layout and two-finger camera gestures.
const Game=preload("res://presentation/approved_game.gd")
var game:Node
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:call_deferred("run")
func expect(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL ",message)
func frames(n:int=3)->void:
	for i in range(n):await process_frame
func touch(index:int,down:bool,position:Vector2)->void:
	var e:=InputEventScreenTouch.new();e.index=index;e.pressed=down;e.position=position;game._input(e)
func drag(index:int,position:Vector2,relative:Vector2)->void:
	var e:=InputEventScreenDrag.new();e.index=index;e.position=position;e.relative=relative;game._input(e)
func row_width(row:Control)->float:
	var total:=0.0;var visible:=0
	for child in row.get_children():
		if child is Control and child.visible:
			total+=child.size.x;visible+=1
	return total+maxf(0,visible-1)*row.get_theme_constant("separation")
func run()->void:
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	# --- English is the default language when nothing was saved on the device.
	Locale.set_language("en",false)
	expect(Locale.current()=="en","English locale is active")
	expect(TranslationServer.translate("Construir")=="Build","Portuguese keys translate to English")
	expect(TranslationServer.translate("Cortando árvore")=="Chopping a tree","newly added strings are translated")
	# --- Phone-sized window: portrait 390x664 logical pixels.
	root.size=Vector2i(390,664)
	game=Game.new();root.add_child(game);game.set_process(false);game.sim.paused=true
	game.hud._dismiss_tutorial();game.hud._toast.hide();await frames(8)
	var hud=game.hud
	expect(hud._tabs.build.text=="Build" and hud._tabs.road.text=="Roads","dock labels are English")
	expect(not hud._help_dock_button.visible,"phone layout hides the help dock button")
	expect(not hud._resource_buttons.population.visible and not hud._resource_buttons.trunks.visible and hud._resource_buttons.gold.visible,"phone layout keeps four counters")
	expect(row_width(hud._dock_row)<=hud._dock.size.x-16.0+0.5,"dock buttons fit the phone width (%.0f of %.0f)"%[row_width(hud._dock_row),hud._dock.size.x-16.0])
	expect(row_width(hud._top_row)<=hud._top.size.x-20.0+0.5,"top bar fits the phone width (%.0f of %.0f)"%[row_width(hud._top_row),hud._top.size.x-20.0])
	expect(not hud._camera_pad.visible,"camera pad hidden until touch is detected")
	# --- The first touch reveals the camera pad and it blocks world clicks.
	var ground:=Vector2(140,360)
	touch(0,true,ground);touch(0,false,ground);await frames(2)
	expect(hud.is_touch_mode() and hud._camera_pad.visible,"a touch shows the camera pad")
	var pad_center:Vector2=hud._camera_pad.position+hud._camera_pad.size*0.5
	expect(hud.blocks_pointer(pad_center),"camera pad is a HUD region")
	expect(hud._camera_pad.position.x+hud._camera_pad.size.x<=root.size.x and hud._camera_pad.position.y+hud._camera_pad.size.y<=hud._dock.position.y,"camera pad sits inside the screen above the dock")
	# --- Camera pad buttons drive the camera.
	var yaw_before:float=game.world.target_yaw;var size_before:float=game.world.target_size
	hud.camera_requested.emit("orbit_right");hud.camera_requested.emit("zoom_in")
	expect(game.world.target_yaw>yaw_before,"orbit_right rotates the view")
	expect(game.world.target_size<size_before,"zoom_in reduces the orthographic size")
	game.world.target_focus=Vector3(5,0,5);hud.camera_requested.emit("focus")
	expect(game.world.target_focus.x>10.0,"focus recenters on the village hub")
	# --- Two fingers: pinch zooms and moving both pans the camera.
	var focus_before:Vector3=game.world.target_focus;size_before=game.world.target_size
	touch(0,true,Vector2(150,330));touch(1,true,Vector2(230,400))
	drag(0,Vector2(140,320),Vector2(-10,-10));drag(1,Vector2(240,410),Vector2(10,10))
	expect(game.world.target_size<size_before,"spreading two fingers zooms in")
	drag(0,Vector2(170,320),Vector2(30,0));drag(1,Vector2(270,410),Vector2(30,0))
	expect(game.world.target_focus!=focus_before,"dragging two fingers pans the camera")
	touch(0,false,Vector2(170,320));touch(1,false,Vector2(270,410))
	expect(game.touch_points.is_empty() and game.pinch_distance==0.0,"lifting both fingers resets the gesture")
	# --- Side panels stay fully on screen on a phone.
	hud.inspect(game.sim.buildings[0]);await frames(2)
	expect(hud._inspector.visible and hud._inspector.position.x>=0.0 and hud._inspector.position.x+hud._inspector.size.x<=root.size.x+0.5,"inspector fits the phone width")
	expect(hud._inspector.position.y+hud._inspector.size.y<=hud._dock.position.y+0.5,"inspector ends above the dock")
	hud._toggle_menu();await frames(2)
	expect(hud._menu.visible and hud._menu.position.x>=0.0 and hud._menu.position.x+hud._menu.size.x<=root.size.x+0.5,"menu fits the phone width")
	expect(hud._menu.position.y+hud._menu.size.y<=hud._dock.position.y+0.5,"menu ends above the dock")
	hud.close_panels()
	# --- The stone deposit is visible and highlighted while placing a quarry.
	var rocks:Node3D=game.world.get_node_or_null("StoneDeposit")
	expect(rocks!=null and rocks.get_child_count()==game.sim.stone_deposits.size(),"one granite outcrop per deposit cell")
	game._select_build("quarry")
	expect(game.world.deposit_highlight.get_child_count()>0,"quarry tool highlights the deposit cells")
	expect(game.sim.can_place("quarry",Vector2i(10,17)).is_empty(),"a quarry fits just north of the deposit")
	expect(not game.sim.can_place("quarry",Vector2i(4,4)).is_empty(),"a quarry away from the deposit is refused")
	game._select_build("")
	expect(game.world.deposit_highlight.get_child_count()==0,"leaving the quarry tool clears the highlight")
	# --- Desktop width returns to the full layout.
	root.size=Vector2i(1280,800);await frames(4)
	expect(hud._help_dock_button.visible and hud._resource_buttons.population.visible,"desktop layout restores every control")
	print("TOUCH_HUD_RESULT checks=%d failures=%s"%[checks,failures])
	quit(0 if failures.is_empty() else 1)
