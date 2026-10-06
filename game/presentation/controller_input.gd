extends Node
## Controller-only pointer. Mouse, Steam Input trackpad and touch keep their native paths.
const DEADZONE := 0.18
var game: Node
var pointer := Vector2.ZERO
var last_mouse := Vector2.ZERO
var controller_active := false
var device := -1
var cursor: Control
var hint: Label
var clicking := false
var zoom_hold := 0
var motion_axes := Vector4.ZERO
var scroll_axis := 0.0
var scroll_timer := 0.0
var click_sources: Dictionary = {}

class Pointer extends Control:
	func _draw() -> void:
		draw_circle(Vector2.ZERO,8,Color(0.1,0.1,0.1,0.8))
		draw_circle(Vector2.ZERO,5,Color("f3d181"))
		draw_line(Vector2(-12,0),Vector2(12,0),Color.WHITE,1.5)
		draw_line(Vector2(0,-12),Vector2(0,12),Color.WHITE,1.5)

func setup(owner_game: Node) -> void:
	game = owner_game
	pointer = get_viewport().get_visible_rect().size*0.5
	last_mouse = get_viewport().get_mouse_position()
	var overlay := CanvasLayer.new();overlay.layer=80;add_child(overlay)
	cursor = Pointer.new();cursor.mouse_filter=Control.MOUSE_FILTER_IGNORE;cursor.hide();overlay.add_child(cursor)
	hint = Label.new();hint.mouse_filter=Control.MOUSE_FILTER_IGNORE;hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_color_override("font_color",Color("f3d181"));hint.hide();overlay.add_child(hint)
	Input.joy_connection_changed.connect(_connection)

func _connection(id: int, connected: bool) -> void:
	if id == device and not connected:
		_release_click();motion_axes=Vector4.ZERO;scroll_axis=0;zoom_hold=0
		controller_active=false;cursor.hide();hint.hide();device=-1

func _activate(id: int) -> void:
	if not controller_active:
		pointer = get_viewport().get_mouse_position()
		if pointer == Vector2.ZERO:pointer = get_viewport().get_visible_rect().size*0.5
	controller_active=true;device=id;cursor.show();hint.show()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		if controller_active:_release_click()
		controller_active=false;cursor.hide();hint.hide()
		return
	if event is InputEventScreenTouch:
		if controller_active:_release_click()
		controller_active=false;cursor.hide();hint.hide();return
	if event is InputEventJoypadMotion:
		if absf(event.axis_value)>DEADZONE:_activate(event.device)
		match event.axis:
			JOY_AXIS_LEFT_X:motion_axes.x=event.axis_value
			JOY_AXIS_LEFT_Y:motion_axes.y=event.axis_value
			JOY_AXIS_RIGHT_X:motion_axes.z=event.axis_value
			JOY_AXIS_RIGHT_Y:motion_axes.w=event.axis_value
			JOY_AXIS_TRIGGER_RIGHT:
				if event.axis_value>0.5:_activate(event.device)
				_set_click_source("trigger",event.axis_value>0.5)
		return
	if not event is InputEventJoypadButton:return
	_activate(event.device)
	if event.button_index == JOY_BUTTON_A:_set_click_source("a",event.pressed);return
	if event.button_index in [JOY_BUTTON_DPAD_UP,JOY_BUTTON_DPAD_DOWN]:
		zoom_hold=(-1 if event.button_index==JOY_BUTTON_DPAD_UP else 1) if event.pressed else 0
		return
	if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:
		scroll_axis=(-1.0 if event.button_index==JOY_BUTTON_DPAD_LEFT else 1.0) if event.pressed else 0.0
		return
	if not event.pressed:return
	match event.button_index:
		JOY_BUTTON_B:
			_release_click();game._select_build("");game.hud.close_panels()
			game.save_dialog.hide();game.load_dialog.hide()
		JOY_BUTTON_X:game.hud._toggle_drawer("build")
		JOY_BUTTON_Y:game.hud._toggle_drawer("training")
		JOY_BUTTON_START:game.hud._toggle_menu()
		JOY_BUTTON_BACK:game._command("pause",{})
		JOY_BUTTON_LEFT_SHOULDER:game._camera_command("orbit_left")
		JOY_BUTTON_RIGHT_SHOULDER:game._camera_command("orbit_right")
		JOY_BUTTON_LEFT_STICK:game._camera_command("focus")
		JOY_BUTTON_RIGHT_STICK:game.hud._choose_road()

func _axis(value: float) -> float:
	return 0.0 if absf(value)<=DEADZONE else signf(value)*(absf(value)-DEADZONE)/(1.0-DEADZONE)

func _process(delta: float) -> void:
	if game==null or not controller_active:return
	var size := get_viewport().get_visible_rect().size
	var move := Vector2(_axis(motion_axes.z),_axis(motion_axes.w))*650.0*minf(delta,0.1)
	pointer = (pointer+move).clamp(Vector2.ONE,size-Vector2.ONE)
	cursor.position=pointer
	if move.length_squared()>0:
		var event := InputEventMouseMotion.new();event.device=InputEvent.DEVICE_ID_EMULATION
		event.position=pointer;event.global_position=pointer;event.relative=move
		event.button_mask=MOUSE_BUTTON_MASK_LEFT if clicking else 0
		get_viewport().push_input(event)
	var pan := Vector2(_axis(motion_axes.x),_axis(motion_axes.y))
	if pan.length_squared()>0:game.world.pan_by(-pan*450.0*minf(delta,0.1))
	if zoom_hold!=0:game.world.zoom_by(float(zoom_hold)*14.0*minf(delta,0.1))
	scroll_timer = maxf(0,scroll_timer-delta)
	if scroll_axis!=0 and scroll_timer<=0:
		scroll_timer=0.1
		var wheel := InputEventMouseButton.new();wheel.device=InputEvent.DEVICE_ID_EMULATION
		wheel.position=pointer;wheel.global_position=pointer;wheel.pressed=true
		wheel.button_index=MOUSE_BUTTON_WHEEL_UP if scroll_axis<0 else MOUSE_BUTTON_WHEEL_DOWN
		get_viewport().push_input(wheel)
	hint.text=tr("A / R2 select · B cancel · X build · Y train · R3 roads · Menu settings")
	hint.position=Vector2(12,maxf(0,size.y-96))
	hint.size=Vector2(maxf(1,size.x-24),30);hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func _click(down: bool) -> void:
	if clicking==down:return
	clicking=down
	var event := InputEventMouseButton.new();event.device=InputEvent.DEVICE_ID_EMULATION
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;event.position=pointer;event.global_position=pointer
	get_viewport().push_input(event)

func _set_click_source(source: String, down: bool) -> void:
	if down:click_sources[source]=true
	else:click_sources.erase(source)
	_click(not click_sources.is_empty())

func _release_click() -> void:
	click_sources.clear()
	if clicking:_click(false)
