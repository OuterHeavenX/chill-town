extends Node

const Village = preload("res://simulation/approved_sim.gd")
const World = preload("res://presentation/approved_world.gd")
const Audio = preload("res://presentation/approved_audio.gd")
const Hud = preload("res://ui/approved_hud.gd")
const Clock = preload("res://core/simulation_clock.gd")
const CIVIL_PACE := 0.4
const Controller = preload("res://presentation/controller_input.gd")
const SAVE_PATH := "user://vale-approved-save-v1.json"
var sim: RefCounted
var world: Node3D
var hud: CanvasLayer
var clock: RefCounted
var speed := 1
var build_kind := ""
var hover_cell := Vector2i(-1,-1)
var selected_id := -1
var drag_start := Vector2.ZERO
var pointer_down := false
var dragging := false
var pointer_ui := false
var pan_pointer_down := false
var pan_pointer_ui := false
var since_refresh := 0.0
var since_autosave := 0.0
var application_paused := false
var touch_points := {}
var pinch_distance := 0.0
var pinch_center := Vector2.ZERO
var pinch_angle := 0.0
var audio: Node
var event_signature := ""
var road_path: Array[Vector2i] = []
var accessible_lighting := false
var resume_on_start := true
var controller: Node
var save_dialog: FileDialog
var load_dialog: FileDialog
var web_import_callback: JavaScriptObject

func _ready() -> void:
	Locale.setup()
	_configure_display()
	get_window().size_changed.connect(_configure_display)
	sim = Village.new()
	sim.setup()
	clock = Clock.new(100000)
	world = World.new()
	add_child(world)
	world.setup(sim)
	hud = Hud.new()
	add_child(hud)
	hud.setup(sim)
	audio = Audio.new()
	add_child(audio)
	audio.setup(sim, world)
	hud.set_sound_enabled(audio.enabled)
	hud.ui_pressed.connect(func(): audio.click())
	hud.sound_toggled.connect(_toggle_sound)
	if not sim.events.is_empty():event_signature=str(sim.events.back().tick)+str(sim.events.back().text)
	hud.build_selected.connect(_select_build)
	hud.command_requested.connect(_command)
	hud.save_requested.connect(_save)
	hud.load_requested.connect(_load_save)
	hud.restart_requested.connect(_restart)
	hud.speed_selected.connect(func(value): speed = value)
	hud.focus_requested.connect(_focus_map)
	hud.entrance_highlighted.connect(_highlight_entrance)
	hud.language_changed.connect(_refresh_placement_banner)
	hud.camera_requested.connect(_camera_command)
	if DisplayServer.is_touchscreen_available():
		hud.set_touch_mode(true)
	_refresh_safe_area()
	controller = Controller.new();add_child(controller);controller.setup(self)
	_setup_save_dialogs()
	_load_preferences()
	if resume_on_start: _load_paths(_save_paths_sorted(), false)
	print("PLAYABLE_READY: Chill Town — ",ProjectSettings.get_setting("application/config/version"))

## The browser reports the notch and status-bar insets; the HUD lays itself out
## inside them so no control ends up under system chrome.
func _refresh_safe_area() -> void:
	if hud == null:
		return
	var insets := Vector4.ZERO
	if OS.has_feature("web"):
		var raw: Variant = JavaScriptBridge.eval("window.chillTownSafeArea ? window.chillTownSafeArea.join(',') : ''",true)
		if typeof(raw) == TYPE_STRING:
			var parts := str(raw).split(",",false)
			if parts.size() == 4:
				insets = Vector4(float(parts[0]),float(parts[1]),float(parts[2]),float(parts[3]))
	hud.set_safe_area(insets)


func _configure_display() -> void:
	# Web and mobile report framebuffer pixels; use the platform density so
	# the responsive HUD and pointer coordinates stay in logical screen units.
	if OS.has_feature("web") or OS.has_feature("mobile"):
		var density := maxf(1.0,DisplayServer.screen_get_scale())
		if not is_equal_approx(get_window().content_scale_factor,density):
			get_window().content_scale_factor = density
	_refresh_safe_area()

func _process(delta: float) -> void:
	if sim == null:
		return
	clock.paused = sim.paused or application_paused
	var due: int = clock.advance_usec(roundi(minf(delta,0.25)*1000000.0*speed*CIVIL_PACE))
	for i in range(due):
		sim.step()
	world.visual_speed = float(speed)*CIVIL_PACE
	world.sync(delta)
	since_refresh += delta
	since_autosave += delta
	if since_refresh > 0.2:
		since_refresh = 0.0
		hud.refresh()
		if build_kind == "remove_road" and hover_cell.x >= 0:
			world.set_road_removal_preview(hover_cell)
		elif not build_kind.is_empty() and build_kind not in ["road","army"] and hover_cell.x >= 0:
			world.set_preview(build_kind,hover_cell,sim.can_place(build_kind,hover_cell).is_empty())
	if since_autosave >= 60.0 and not application_paused:
		since_autosave = 0.0
		_write_save("user://vale-approved-autosave-v1.json")
	if not sim.events.is_empty():
		var latest: String = str(sim.events.back().tick)+str(sim.events.back().text)
		if latest != event_signature:
			event_signature = latest
			var event: Dictionary = sim.events.back()
			var message: String = str(event.text)
			hud.show_message(message)
			audio.notice(str(event.get("tone","")))

func _select_build(kind: String) -> void:
	_reset_pointer()
	build_kind = kind
	if not kind.is_empty():
		hud._dismiss_tutorial()
	selected_id = -1
	world.set_selected(-1)
	world.clear_preview()
	world.set_deposit_highlight(kind)
	road_path.clear()
	hud.set_road_tool(kind)
	if kind == "road":
		hud.close_panels()
		_refresh_placement_banner()
		world.set_road_preview(road_path)
	elif kind == "remove_road":
		hud.close_panels()
		_refresh_placement_banner()
	elif not kind.is_empty():
		hud.close_panels()
		_refresh_placement_banner()
	else:
		hud.set_mode("")

func _command(kind: String, payload: Dictionary) -> void:
	if kind == "export_save": _export_save(); return
	if kind == "import_save": _import_save(); return
	if kind == "toggle_lighting":
		accessible_lighting = not accessible_lighting
		world.accessible_lighting = accessible_lighting
		hud._brightness_button.text = tr("Lighting: bright") if accessible_lighting else tr("Lighting: atmospheric")
		var config := ConfigFile.new();config.load("user://settings.cfg")
		config.set_value("display","bright",accessible_lighting);config.save("user://settings.cfg")
		return
	if kind in ["new_game", "load_mission"]:
		# Keep a recoverable save when changing scenarios, even without an earlier manual save.
		if not _write_save(SAVE_PATH):
			hud.show_message(tr("Could not preserve the current village. Save it before switching.")); return
		var changed: Dictionary = sim.command(kind,payload)
		if not changed.ok: hud.show_message(changed.message); return
		if kind == "new_game": sim.combat_enabled = bool(payload.get("combat_enabled",true))
		clock = Clock.new(100000)
		speed = 1
		_clear_world()
		hud.show_message(changed.message)
		return
	var result: Dictionary = sim.command(kind,payload)
	hud.show_message(result.message)
	hud.refresh()

func _world_click(point: Vector2) -> void:
	var cell: Vector2i = world.screen_to_cell(point)
	if cell.x < 0:
		return
	if build_kind == "road":
		_command("road",{"cell":cell})
		return
	if build_kind == "remove_road":
		_command("remove_road",{"cell":cell})
		world.set_road_removal_preview(cell)
		return
	if build_kind == "army":
		_command("army",{"order":"attack","target":cell})
		return
	if not build_kind.is_empty():
		var result: Dictionary = sim.command("build",{"kind":build_kind,"cell":cell})
		hud.show_message(result.message)
		if result.ok:
			_select_build("")
		return
	var b: Dictionary = world.building_at_screen(point) if world.has_method("building_at_screen") else sim.building_at(cell)
	selected_id = b.get("id",-1)
	world.set_selected(selected_id)
	if b.get("kind","") == "training" and b.get("stage","") == "complete":
		hud.open_training(b)
	else:
		hud.inspect(b)
		if b.get("kind","") == "barracks" and b.get("stage","") == "complete":
			hud.set_mode(tr("Quartel · recrute lanceiros e arqueiros"))

func _reset_pointer() -> void:
	pointer_down = false
	pointer_ui = false
	dragging = false
	pan_pointer_down = false
	pan_pointer_ui = false
	hover_cell = Vector2i(-1,-1)
	road_path.clear()
	touch_points.clear()
	pinch_distance = 0.0

func _cancel_stroke() -> void:
	pointer_down = false
	pointer_ui = false
	dragging = false
	road_path.clear()
	if build_kind == "road":
		world.set_road_preview(road_path)
		hud.set_mode(tr("Estradas · arraste ou clique · 1 pedra por trecho · Esc termina"))
	elif build_kind == "remove_road":
		hover_cell = Vector2i(-1,-1)
		world.set_road_removal_preview(hover_cell)
		hud.set_mode(tr("Estradas · toque em um trecho para apagar · Esc termina"))

func _focus_map(cell: Vector2i) -> void:
	_cancel_stroke()
	world.focus_cell(cell)

## Camera pad buttons (touch screens): mirror the Q/E, wheel and Home shortcuts.
func _camera_command(kind: String) -> void:
	match kind:
		"zoom_in": world.zoom_by(-6.0)
		"zoom_out": world.zoom_by(6.0)
		"orbit_left":
			_cancel_stroke()
			world.orbit(-PI/6)
		"orbit_right":
			_cancel_stroke()
			world.orbit(PI/6)
		"focus": _focus_map(sim.HUB)

func _highlight_entrance(cell: Vector2i) -> void:
	selected_id = -1
	if cell.x >= 0:
		for building in sim.buildings:
			if building.entrance == cell and building.stage != "cancelled":
				selected_id = int(building.id)
				break
	world.set_selected(selected_id)

func _input(event: InputEvent) -> void:
	if sim == null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE:
				_select_build("")
				hud.close_panels()
			KEY_SPACE: _command("pause",{})
			KEY_1: hud._choose_speed(1)
			KEY_2: hud._choose_speed(2)
			KEY_4: hud._choose_speed(4)
			KEY_F5: _save()
			KEY_F9: _load_save()
			KEY_HOME: _focus_map(sim.HUB)
			KEY_R: _select_build("road")
			KEY_Q, KEY_E:
				_cancel_stroke()
				world.orbit(-PI/6 if event.keycode == KEY_Q else PI/6)
			KEY_M:
				_toggle_sound()
			KEY_LEFT, KEY_A, KEY_RIGHT, KEY_D, KEY_UP, KEY_W, KEY_DOWN, KEY_S:
				_cancel_stroke()
				if event.keycode in [KEY_LEFT,KEY_A]: world.pan_by(Vector2(65,0))
				elif event.keycode in [KEY_RIGHT,KEY_D]: world.pan_by(Vector2(-65,0))
				elif event.keycode in [KEY_UP,KEY_W]: world.pan_by(Vector2(0,65))
				else: world.pan_by(Vector2(0,-65))
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed and not hud.blocks_pointer(event.position):
			_cancel_stroke()
			world.zoom_by(-2.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 2.0)
		if event.button_index == MOUSE_BUTTON_MIDDLE:
			if event.pressed:
				_cancel_stroke()
				pan_pointer_ui = hud.blocks_pointer(event.position)
			pan_pointer_down = event.pressed
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if pan_pointer_down or touch_points.size() >= 2:
					return
				pointer_down = true
				dragging = false
				drag_start = event.position
				pointer_ui = hud.blocks_pointer(event.position)
				if build_kind == "road" and not pointer_ui:
					road_path.clear()
					_extend_road(world.screen_to_cell(event.position))
			else:
				if pointer_down and build_kind == "road":
					var cell: Vector2i = world.screen_to_cell(event.position)
					if not pointer_ui and not hud.blocks_pointer(event.position) and cell.x >= 0 and cell.y >= 0 and not road_path.is_empty():
						_extend_road(cell)
						_command("road",{"cells":road_path.duplicate()})
					_cancel_stroke()
				elif pointer_down and not dragging and not pointer_ui and not hud.blocks_pointer(event.position):
					if build_kind != "remove_road" or event.position.distance_to(drag_start) <= 8.0:
						_world_click(event.position)
				pointer_down = false
				dragging = false
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_select_build("")
	if event is InputEventMouseMotion:
		if touch_points.size() >= 2:
			return
		if pan_pointer_down:
			if not pan_pointer_ui and not hud.blocks_pointer(event.position):
				world.pan_by(event.relative)
			return
		if build_kind == "road":
			if not hud.blocks_pointer(event.position):
				if pointer_down and not pointer_ui:
					_extend_road(world.screen_to_cell(event.position))
				elif not pointer_down:
					var cells: Array[Vector2i] = [world.screen_to_cell(event.position)]
					world.set_road_preview(cells)
			return
		if pointer_down and not pointer_ui:
			if event.position.distance_to(drag_start) > 8.0:
				dragging = true
			if dragging and not hud.blocks_pointer(event.position):
				world.pan_by(event.relative)
		if build_kind == "remove_road":
			hover_cell = world.screen_to_cell(event.position) if not dragging and not hud.blocks_pointer(event.position) else Vector2i(-1,-1)
			world.set_road_removal_preview(hover_cell)
			return
		if not build_kind.is_empty() and build_kind != "army" and not hud.blocks_pointer(event.position):
			hover_cell = world.screen_to_cell(event.position)
			world.set_preview(build_kind,hover_cell,sim.can_place(build_kind,hover_cell).is_empty())
	if event is InputEventMagnifyGesture and not hud.blocks_pointer(event.position):
		_cancel_stroke()
		world.zoom_by((1.0-event.factor)*20.0)
	if event is InputEventPanGesture and not hud.blocks_pointer(event.position):
		_cancel_stroke()
		world.pan_by(-event.delta*12.0)
	# Touch -> mouse emulation supplies tap/drag; a second finger cancels placement.
	if event is InputEventScreenTouch:
		hud.set_touch_mode(true)
		if event.pressed:
			touch_points[event.index] = event.position
			if touch_points.size() >= 2:
				_cancel_stroke()
		else:
			touch_points.erase(event.index)
		if touch_points.size() != 2:
			pinch_distance = 0.0
			pinch_angle = 0.0
	# Two fingers: pinch to zoom, twist to rotate and drag together to pan.
	# Works while drawing roads too, so the camera never blocks a stroke.
	if event is InputEventScreenDrag:
		touch_points[event.index] = event.position
		if touch_points.size() == 2:
			# Order by finger index so the twist angle cannot flip by a half turn.
			var indices: Array = touch_points.keys()
			indices.sort()
			var first: Vector2 = touch_points[indices[0]]
			var second: Vector2 = touch_points[indices[1]]
			var span: Vector2 = second-first
			var distance: float = span.length()
			var center: Vector2 = (first+second)*0.5
			var angle: float = span.angle()
			if pinch_distance > 0.0:
				world.zoom_by((pinch_distance-distance)*0.06)
				if not hud.blocks_pointer(center):
					world.pan_by(center-pinch_center)
				# Increasing yaw turns the world clockwise on screen, which is
				# also the direction of a clockwise twist, so the signs match.
				var twist: float = wrapf(angle-pinch_angle,-PI,PI)
				if absf(twist) > 0.015:
					world.orbit(twist)
			pinch_distance = distance
			pinch_center = center
			pinch_angle = angle
			dragging = true

func _parse_save_json(text: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(text) != OK: return null
	return parser.data

func _write_save(path: String) -> bool:
	var data := {"format":"vale-approved-v1","simulation":sim.snapshot(),"clock":clock.capture(),"speed":speed,"written_at":Time.get_unix_time_from_system()}
	var text := JSON.stringify(data)
	var temporary := path+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.flush()
	file.close()
	var check := FileAccess.open(temporary,FileAccess.READ)
	if check == null or not _parse_save_json(check.get_as_text()) is Dictionary:
		return false
	check.close()
	if FileAccess.file_exists(path):
		var backup := path+".bak"
		if DirAccess.copy_absolute(path,backup) != OK:
			return false
	return DirAccess.rename_absolute(temporary,path) == OK

func _save() -> void:
	hud.show_message(tr("Partida salva neste dispositivo.") if _write_save(SAVE_PATH) else tr("Não foi possível salvar. Verifique espaço e permissões locais."))

func _load_save() -> void:
	_load_paths(_save_paths_sorted())

func _save_paths_sorted() -> Array:
	var paths: Array = []
	for path in [SAVE_PATH,SAVE_PATH+".bak","user://vale-approved-autosave-v1.json","user://vale-approved-autosave-v1.json.bak"]:
		if FileAccess.file_exists(path): paths.append(path)
	paths.sort_custom(func(a,b): return _save_time(a) > _save_time(b))
	return paths

func _save_time(path: String) -> float:
	var file := FileAccess.open(path,FileAccess.READ)
	if file!=null and file.get_length()<=4000000:
		var data: Variant = _parse_save_json(file.get_as_text())
		if data is Dictionary and typeof(data.get("written_at")) in [TYPE_INT,TYPE_FLOAT]:
			return float(data.written_at)
	return float(FileAccess.get_modified_time(path))

func _load_paths(paths: Array, announce: bool = true) -> bool:
	for path in paths:
		if not FileAccess.file_exists(path):
			continue
		var file := FileAccess.open(path,FileAccess.READ)
		if file == null or file.get_length()>4000000:
			continue
		var data: Variant = _parse_save_json(file.get_as_text())
		file.close()
		if not data is Dictionary or data.get("format") != "vale-approved-v1" or not data.get("simulation") is Dictionary or not data.get("clock") is Dictionary:
			continue
		var new_clock := Clock.new(100000)
		if new_clock.restore(data.clock) != OK:
			continue
		if sim.restore(data.simulation):
			clock = new_clock
			var saved_speed: Variant = data.get("speed",1)
			speed = int(saved_speed) if typeof(saved_speed) in [TYPE_INT,TYPE_FLOAT] and saved_speed in [1,2,4] else 1
			_clear_world()
			hud._dismiss_tutorial()
			hud.show_message(tr("Partida recuperada. Nada avançou enquanto esteve fechada."))
			return true
	if announce: hud.show_message(tr("Não há uma partida salva válida neste dispositivo."))
	return false

func _clear_world() -> void:
	since_refresh = 0.0
	since_autosave = 0.0
	event_signature = str(sim.events.back().tick)+str(sim.events.back().text) if not sim.events.is_empty() else ""
	_select_build("")
	selected_id = -1
	world.queue_free()
	world = World.new()
	add_child(world)
	world.setup(sim)
	world.accessible_lighting = accessible_lighting
	audio.rebind_world(world)
	hud.close_panels()
	hud.inspect({})
	hud._choose_speed(speed)
	hud.refresh()

func _restart() -> void:
	sim.setup()
	clock = Clock.new(100000)
	speed = 1
	_clear_world()
	hud.show_message(tr("Nova partida iniciada. Seu salvamento manual anterior foi preservado."))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		application_paused = true
		if sim != null:
			_write_save("user://vale-approved-autosave-v1.json")
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		application_paused = false
	elif what == NOTIFICATION_WM_CLOSE_REQUEST and sim != null:
		_write_save("user://vale-approved-autosave-v1.json")

func _toggle_sound() -> void:
	audio.set_enabled(not audio.enabled)
	hud.set_sound_enabled(audio.enabled)
	hud.show_message(tr("Sons ativados") if audio.enabled else tr("Sons desativados"))

func _extend_road(cell:Vector2i) -> void:
	if cell.x < 1 or cell.y < 1 or cell.x >= Village.WIDTH-1 or cell.y >= Village.HEIGHT-1: return
	if road_path.is_empty():
		road_path.append(cell)
	else:
		var last:Vector2i=road_path.back()
		# Fill skipped mouse samples with an orthogonal, continuous road stroke.
		while last!=cell and road_path.size()<200:
			if absi(last.x-cell.x)>=absi(last.y-cell.y):last.x+=signi(cell.x-last.x)
			else:last.y+=signi(cell.y-last.y)
			if not road_path.has(last):road_path.append(last)
	world.set_road_preview(road_path)
	var cost:=0
	for tile in road_path:
		if sim.road_at(tile).is_empty() and sim.can_place_road(tile).is_empty():cost+=1
	hud.set_mode(tr("Estradas · {tiles} trechos · {stone} pedra · solte para construir · Esc termina").format({"tiles":road_path.size(),"stone":cost}))

func _refresh_placement_banner() -> void:
	if build_kind == "road":
		if road_path.is_empty():
			hud.set_mode(tr("Estradas · arraste para traçar · 1 pedra por trecho · Esc termina"))
		else:
			var cost:=0
			for tile in road_path:
				if sim.road_at(tile).is_empty() and sim.can_place_road(tile).is_empty():cost+=1
			hud.set_mode(tr("Estradas · {tiles} trechos · {stone} pedra · solte para construir · Esc termina").format({"tiles":road_path.size(),"stone":cost}))
	elif build_kind == "remove_road":
		hud.set_mode(tr("Estradas · toque em um trecho para apagar · Esc termina"))
	elif build_kind == "quarry":
		hud.set_mode(tr("Pedreira: toque ao lado da jazida de pedra destacada. Esc cancela."))
	elif build_kind == "army":
		hud.set_mode(tr("Exército · clique no mapa para conquistar · Esc para sair"))
	elif not build_kind.is_empty():
		hud.set_mode(tr("Construir {name}: toque no terreno. Esc cancela.").format({"name":sim.definition(build_kind).name}))
	else:
		hud.set_mode("")

func _load_preferences() -> void:
	var config := ConfigFile.new();config.load("user://settings.cfg")
	accessible_lighting = bool(config.get_value("display","bright",false))
	world.accessible_lighting = accessible_lighting
	hud._brightness_button.text = tr("Lighting: bright") if accessible_lighting else tr("Lighting: atmospheric")

func _setup_save_dialogs() -> void:
	if OS.has_feature("web"):
		web_import_callback = JavaScriptBridge.create_callback(func(args):
			if args.size() > 0: _import_save_text(str(args[0])))
		JavaScriptBridge.get_interface("window").chillTownImportSave = web_import_callback
		return
	save_dialog = FileDialog.new();save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE;save_dialog.filters = PackedStringArray(["*.json ; Chill Town save"])
	save_dialog.file_selected.connect(func(path):
		hud.show_message(tr("Save exported.") if _write_save(path) else tr("Could not export save.")))
	add_child(save_dialog)
	load_dialog = FileDialog.new();load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE;load_dialog.filters = PackedStringArray(["*.json ; Chill Town save"])
	load_dialog.file_selected.connect(func(path):
		var file := FileAccess.open(path,FileAccess.READ)
		if file != null and file.get_length() <= 4000000: _import_save_text(file.get_as_text()))
	add_child(load_dialog)

func _export_save() -> void:
	if OS.has_feature("web"):
		var data := JSON.stringify({"format":"vale-approved-v1","simulation":sim.snapshot(),"clock":clock.capture(),"speed":speed})
		var script := "(()=>{const b=new Blob([%s],{type:'application/json'});const u=URL.createObjectURL(b);const a=document.createElement('a');a.href=u;a.download='chill-town-save.json';a.click();setTimeout(()=>URL.revokeObjectURL(u),1000);})()" % JSON.stringify(data)
		JavaScriptBridge.eval(script,true)
	else:
		save_dialog.current_file = "chill-town-save.json";save_dialog.popup_centered_ratio(0.8)

func _import_save() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(()=>{const f=document.createElement('input');f.type='file';f.accept='.json,application/json';f.onchange=async()=>{const x=f.files[0];if(x&&x.size<=4000000)window.chillTownImportSave(await x.text());};f.click();})()",true)
	else: load_dialog.popup_centered_ratio(0.8)

func _import_save_text(content: String) -> bool:
	if content.length() > 4000000: return false
	var data: Variant = _parse_save_json(content)
	if not data is Dictionary or data.get("format") != "vale-approved-v1" or not data.get("simulation") is Dictionary or not data.get("clock") is Dictionary:
		hud.show_message(tr("Invalid save file.")); return false
	var next_clock := Clock.new(100000)
	if next_clock.restore(data.clock) != OK:
		hud.show_message(tr("Invalid save file.")); return false
	# Preserve the live game before importing, but validate in a separate simulation first.
	var candidate := Village.new();candidate.setup()
	if not candidate.restore(data.simulation): hud.show_message(tr("Invalid save file.")); return false
	if not _write_save(SAVE_PATH): hud.show_message(tr("Could not preserve the current village. Save it before switching.")); return false
	if not sim.restore(data.simulation): return false
	clock = next_clock
	speed = int(data.get("speed",1)) if data.get("speed",1) in [1,2,4] else 1
	_clear_world();hud.show_message(tr("Save imported."));return true
