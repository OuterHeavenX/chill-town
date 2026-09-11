extends SceneTree
## Headless checks for the Chill Town additions: English by default, the touch
## camera pad, the phone-sized HUD layout and two-finger camera gestures.
const Game=preload("res://presentation/approved_game.gd")
var game:Node
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:
	# A compile or runtime error aborts run() and would leave the headless tree
	# spinning until the CI job times out; fail loudly after three minutes.
	create_timer(180.0).timeout.connect(func():
		printerr("TIMEOUT: test_touch_hud did not reach its result line")
		quit(1))
	call_deferred("run")
func expect(value:bool,message:String)->void:
	checks+=1
	if not value:failures.append(message);printerr("FAIL ",message)
func frames(n:int=3)->void:
	for i in range(n):await process_frame
func touch(index:int,down:bool,position:Vector2)->void:
	var e:=InputEventScreenTouch.new();e.index=index;e.pressed=down;e.position=position;game._input(e)
func drag(index:int,position:Vector2,relative:Vector2)->void:
	var e:=InputEventScreenDrag.new();e.index=index;e.position=position;e.relative=relative;game._input(e)
## Pushed through the viewport so the GUI sees them, unlike game._input().
func push_touch(down:bool,position:Vector2)->void:
	var e:=InputEventScreenTouch.new();e.index=0;e.pressed=down;e.position=position;root.push_input(e)
func push_drag(position:Vector2,relative:Vector2)->void:
	var e:=InputEventScreenDrag.new();e.index=0;e.position=position;e.relative=relative;root.push_input(e)
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
	expect(hud._help_dock_button.visible,"phone dock keeps the help button")
	expect(not hud._tabs.army.visible,"army stays hidden until the barracks is standing")
	expect(hud._has_completed("hall") and not hud._has_completed("barracks"),"completed-building lookup reads the simulation")
	# Once a barracks is standing the army button takes the help button's slot.
	hud._army_ready = true;hud._layout();await frames(2)
	expect(hud._tabs.army.visible and not hud._help_dock_button.visible,"army replaces help on a phone once available")
	expect(row_width(hud._dock_row)<=hud._dock.size.x-16.0+0.5,"dock still fits with the army button (%.0f of %.0f)"%[row_width(hud._dock_row),hud._dock.size.x-16.0])
	hud._army_ready = false;hud._layout();await frames(2)
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
	# --- Notch and status-bar insets keep every panel clear of system chrome.
	hud.set_safe_area(Vector4(47,0,34,0));await frames(2)
	expect(hud._top.position.y>=47.0,"top bar clears the status bar inset")
	expect(hud._dock.position.y+hud._dock.size.y<=root.size.y-34.0+0.5,"dock clears the home indicator inset")
	expect(hud._camera_pad.position.y>=47.0 and hud._camera_pad.position.y+hud._camera_pad.size.y<=hud._dock.position.y+0.5,"camera pad stays between the insets")
	hud.set_safe_area(Vector4.ZERO);await frames(2)
	# Landscape with a notch on both sides, as iOS reports it.
	root.size=Vector2i(844,390);hud.set_safe_area(Vector4(0,47,21,47));await frames(4)
	expect(hud._top.position.x>=47.0 and hud._top.position.x+hud._top.size.x<=844.0-47.0+0.5,"top bar honours left and right insets")
	expect(hud._camera_pad.position.x+hud._camera_pad.size.x<=844.0-47.0+0.5,"camera pad honours the right inset")
	expect(row_width(hud._top_row)<=hud._top.size.x-20.0+0.5,"top bar contents fit between the notch insets")
	root.size=Vector2i(390,664);hud.set_safe_area(Vector4.ZERO);await frames(4)
	expect(hud._resource_buttons.gold.visible and not hud._resource_buttons.trunks.visible,"a phone keeps four counters when nothing is inset")
	# --- Two fingers twisting rotate the view the same way they turn.
	var twist_a := Vector2(120,430)
	var twist_b := Vector2(240,430)
	touch(0,true,twist_a);touch(1,true,twist_b)
	drag(0,twist_a,Vector2.ZERO);drag(1,twist_b,Vector2.ZERO)
	var yaw_start:float=game.world.target_yaw
	var pivot:Vector2=(twist_a+twist_b)*0.5
	var turned_a:Vector2=pivot+(twist_a-pivot).rotated(0.3)
	var turned_b:Vector2=pivot+(twist_b-pivot).rotated(0.3)
	drag(0,turned_a,turned_a-twist_a);drag(1,turned_b,turned_b-twist_b)
	expect(game.world.target_yaw>yaw_start,"a clockwise twist turns the view clockwise")
	touch(0,false,turned_a);touch(1,false,turned_b)
	expect(game.pinch_angle==0.0,"lifting the fingers clears the twist angle")
	# --- Side panels stay fully on screen on a phone.
	hud.inspect(game.sim.buildings[0]);await frames(2)
	expect(hud._inspector.visible and hud._inspector.position.x>=0.0 and hud._inspector.position.x+hud._inspector.size.x<=root.size.x+0.5,"inspector fits the phone width")
	expect(hud._inspector.position.y+hud._inspector.size.y<=hud._dock.position.y+0.5,"inspector ends above the dock")
	hud._toggle_menu();await frames(2)
	expect(hud._menu.visible and hud._menu.position.x>=0.0 and hud._menu.position.x+hud._menu.size.x<=root.size.x+0.5,"menu fits the phone width")
	expect(hud._menu.position.y+hud._menu.size.y<=hud._dock.position.y+0.5,"menu ends above the dock")
	hud.close_panels()
	# --- Drawers fit the phone width instead of clipping their cards.
	hud._toggle_drawer("build");await frames(4)
	expect(hud._build_grid.columns==2,"build drawer uses two columns on a phone")
	expect(hud._build_grid.get_combined_minimum_size().x<=hud._drawer_scroll.size.x+0.5,"build cards fit the drawer (%.0f of %.0f)"%[hud._build_grid.get_combined_minimum_size().x,hud._drawer_scroll.size.x])
	expect(hud._drawer.get_combined_minimum_size().x<=hud._drawer.size.x+0.5,"nothing widens the build drawer past the screen (%.0f of %.0f)"%[hud._drawer.get_combined_minimum_size().x,hud._drawer.size.x])
	hud._toggle_drawer("training");await frames(4)
	expect(hud._role_grid.columns==2,"trades drawer uses two columns on a phone")
	expect(hud._role_grid.get_combined_minimum_size().x<=hud._drawer_scroll.size.x+0.5,"role cards fit the drawer (%.0f of %.0f)"%[hud._role_grid.get_combined_minimum_size().x,hud._drawer_scroll.size.x])
	expect(hud._drawer_content.get_child(3)==hud._role_grid,"the quantity row stays above the role cards on a phone")
	expect(hud._drawer.get_combined_minimum_size().x<=hud._drawer.size.x+0.5,"nothing widens the trades drawer past the screen (%.0f of %.0f)"%[hud._drawer.get_combined_minimum_size().x,hud._drawer.size.x])
	expect(hud._drawer.position.x>=0.0 and hud._drawer.position.x+hud._drawer.size.x<=root.size.x+0.5,"the trades drawer stays on screen")
	expect(hud._drawer.position.y+hud._drawer.size.y<=hud._dock.position.y+0.5,"the drawer ends above the dock")
	# --- A drag scrolls the panel from anywhere, including on top of a card.
	var card:Button=hud._role_grid.get_child(0)
	var grip:Vector2=card.get_global_rect().get_center()
	var scrolled_from:int=hud._drawer_scroll.scroll_vertical
	var queued_before:int=game.sim.training.size()
	push_touch(true,grip)
	# One short drag that stays inside the card: the card itself must react.
	push_drag(grip-Vector2(0,10),Vector2(0,-10))
	await frames(1)
	expect(card.dragged,"the card records that the press was a scroll")
	for step in range(5):
		push_drag(grip-Vector2(0,10.0+12.0*(step+1)),Vector2(0,-12))
	push_touch(false,grip-Vector2(0,70))
	await frames(2)
	expect(hud._drawer_scroll.scroll_vertical>scrolled_from,"a drag on a card scrolls the drawer (%d to %d)"%[scrolled_from,hud._drawer_scroll.scroll_vertical])
	expect(game.sim.training.size()==queued_before,"scrolling over a card trains nobody")
	hud.close_panels();await frames(2)
	# --- The village report lists every building kind with its count and use.
	hud._show_report();await frames(4)
	expect(hud._report.visible,"the village report opens")
	var counts:Dictionary=hud._building_counts()
	expect(int(counts.hall.complete)==1 and int(counts.training.complete)==1,"the report counts the starting buildings")
	expect(not counts.has("barracks"),"a kind with nothing built is absent from the counts")
	var rows:=0
	for child in hud._report_body.get_children():
		if child is PanelContainer:rows+=1
	expect(rows==hud.REPORT_ORDER.size(),"one row per building kind (%d of %d)"%[rows,hud.REPORT_ORDER.size()])
	expect(hud._report.position.x>=0.0 and hud._report.position.x+hud._report.size.x<=root.size.x+0.5,"the report fits the phone width")
	expect(hud._report.position.y+hud._report.size.y<=root.size.y+0.5,"the report fits the phone height")
	expect(hud._report.get_combined_minimum_size().x<=hud._report.size.x+0.5,"nothing widens the report past the screen")
	expect(hud.blocks_pointer(hud._report.position+hud._report.size*0.5),"the report blocks taps reaching the world")
	# A row is not a control, so a drag across it must reach the scroll area.
	var report_row:Control=null
	for child in hud._report_body.get_children():
		if child is PanelContainer:report_row=child;break
	expect(report_row!=null,"the report has rows to drag")
	var report_grip:Vector2=report_row.get_global_rect().get_center()
	push_touch(true,report_grip)
	for step in range(6):
		push_drag(report_grip-Vector2(0,12.0*(step+1)),Vector2(0,-12))
	push_touch(false,report_grip-Vector2(0,72))
	await frames(2)
	expect(hud._report_scroll.scroll_vertical>0,"a drag on a report row scrolls the list")
	expect(tr("Precisa de {role}").format({"role":"instructor"})=="Needs one instructor","the worker line reads as English")
	hud.close_panels();await frames(2)
	expect(not hud._report.visible,"closing the panels hides the report")
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
