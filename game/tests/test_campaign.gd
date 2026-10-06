extends SceneTree
const Sim = preload("res://simulation/approved_sim.gd")
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	create_timer(600).timeout.connect(func():quit(1))
	call_deferred("run")

func expect(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text);printerr("FAIL ",text)

func advance(s: RefCounted, n: int) -> void:
	for i in range(n): s.step()

func place(s: RefCounted, kind: String, at := Vector2i(-1,-1)) -> bool:
	for attempt in range(12):
		if at.x < 0:
			for y in range(4,24):
				for x in range(3,22):
					if s.can_place(kind,Vector2i(x,y)).is_empty(): at=Vector2i(x,y);break
				if at.x >= 0: break
		if s.command("build",{"kind":kind,"cell":at}).ok:
			var cells: Array[Vector2i] = []
			for cell in s.find_path(s.HUB,s.buildings.back().entrance):
				if s.can_place_road(cell).is_empty(): cells.append(cell)
			if not cells.is_empty(): s.command("road",{"cells":cells})
			advance(s,800)
			print("CAMPAIGN_BUILD ",s.mission.id," ",kind," tick=",s.tick," stock=",s.stock.wood,"/",s.stock.stone)
			return true
		advance(s,800)
	expect(false,"legal campaign placement "+kind)
	return false

func run() -> void:
	var ids: Array = ["tsk-02","tsk-03","tsk-04"]
	if not OS.get_cmdline_user_args().is_empty(): ids=OS.get_cmdline_user_args()
	for id in ids:
		var s=Sim.new();s.setup();s.command("load_mission",{"id":id})
		place(s,"training",Vector2i(12,10))
		place(s,"quarry",Vector2i(12,19))
		expect(s.command("train",{"role":"stonecutter"}).ok,"train quarry worker "+id)
		advance(s,1600)
		place(s,"lumber",Vector2i(3,18));place(s,"sawmill",Vector2i(16,11))
		for i in range(2): s.command("train",{"role":"lumberjack"})
		advance(s,1600)
		place(s,"inn",Vector2i(4,6))
		if id=="tsk-02":
			for kind in ["farm","mill","bakery"]:place(s,kind)
			for role in ["farmer","miller","baker"]:s.command("train",{"role":role})
		elif id=="tsk-03":
			for kind in ["vineyard","winery","market"]:place(s,kind)
			for role in ["vintner","vintner","merchant"]:s.command("train",{"role":role})
		else:
			for i in range(6):place(s,"house")
			place(s,"workshop");place(s,"barracks")
			s.command("train",{"role":"lumberjack"})
			for i in range(15):s.command("train",{"role":"servant"})
		for i in range(12000):
			s.step()
			if i % 1000==0:
				print("CAMPAIGN_PROGRESS ",id," ",s.tick," ",s.mission_state())
				await process_frame
			if s.won:break
		print("CAMPAIGN_CASE ",id," tick=",s.tick," won=",s.won," state=",s.mission_state())
		expect(s.won,"campaign objectives completed legally "+id+" "+str(s.mission_state()))
		expect(s.conservation_errors().is_empty(),"campaign ledger "+id)
		var twin=Sim.new();twin.setup()
		expect(twin.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and twin.won and twin.mission.id==id,"completed lesson resumes "+id)
	print("CAMPAIGN_RESULT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
