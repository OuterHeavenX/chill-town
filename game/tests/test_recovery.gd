extends SceneTree
const Game=preload("res://presentation/approved_game.gd")
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:
	create_timer(180).timeout.connect(func():quit(1))
	call_deferred("run")
func expect(ok:bool,text:String)->void:
	checks+=1
	if not ok:failures.append(text);printerr("FAIL ",text)
func run()->void:
	var g=Game.new();g.resume_on_start=false;root.add_child(g);g.set_process(false)
	g.hud._dismiss_tutorial()
	var path:="user://recovery-regression.json"
	for i in range(21):g.sim.step()
	g.clock.advance_usec(1234500)
	var clock:Dictionary=g.clock.capture()
	expect(g._write_save(path),"first recovery fixture is saved")
	for i in range(31):g.sim.step()
	g.clock.advance_usec(1000000)
	expect(g._write_save(path) and FileAccess.file_exists(path+".bak"),"second write preserves backup")
	expect(g._save_time(path)>g._save_time(path+".bak"),"new saves retain ordering timestamp")
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string("corrupt");file.close()
	g._select_build("road")
	expect(g._load_paths([path,path+".bak"],false),"corrupt primary recovers from backup")
	expect(g.sim.tick==21 and g.clock.capture()==clock,"backup restores village and fractional clock")
	expect(g.build_kind.is_empty() and g.audio.world==g.world,"recovery clears placement and rebinds audio")
	var before:Dictionary=g.sim.snapshot()
	expect(not g._load_paths([path],false) and g.sim.snapshot()==before,"invalid recovery leaves village intact")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	g.queue_free();await process_frame;await process_frame
	print("RECOVERY_RESULT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
