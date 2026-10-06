extends SceneTree
const Approved=preload("res://simulation/approved_sim.gd")
const Spec=preload("res://simulation/mission_spec.gd")
var checks:=0
var failures:Array[String]=[]
func _initialize()->void:
	create_timer(180).timeout.connect(func(): quit(1))
	call_deferred("run")
func expect(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);printerr("FAIL ",message)
func fresh()->RefCounted:
	var s=Approved.new();s.setup();return s
func json_state(s:RefCounted)->Dictionary:return JSON.parse_string(JSON.stringify(s.snapshot()))
func advance(s:RefCounted,n:int)->void:
	for i in range(n):s.step()
func link(s:RefCounted,at:Vector2i)->void:
	var cells:Array[Vector2i]=[]
	for cell in s.find_path(s.HUB,at):
		if s.can_place_road(cell).is_empty():cells.append(cell)
	if not cells.is_empty():expect(s.command("road",{"cells":cells}).ok,"mission road command")
func run()->void:
	# Fast carriers must not change the weapon alternation schedule.
	var arsenal=fresh();var bench:Dictionary=arsenal._add_building("workshop",Vector2i(16,6),true)
	bench.input.wood=24;arsenal.stock.wood-=24
	var craftsperson:Dictionary={"role":"lumberjack","meal":200,"state":""}
	for cycle in range(12):
		for tick in range(121):arsenal._produce(craftsperson,bench)
		for item in ["axe","bow"]:arsenal.stock[item]+=bench.output[item];bench.output[item]=0
	expect(arsenal.produced.axe==6 and arsenal.produced.bow==6,"workshop alternates weapons under immediate delivery")
	expect(arsenal.conservation_errors().is_empty(),"alternating weapons conserve materials")
	var forestry=fresh();forestry.command("build",{"kind":"lumber","cell":Vector2i(3,18)})
	for b in forestry.buildings:link(forestry,b.entrance)
	forestry.command("train",{"role":"lumberjack"});advance(forestry,5000)
	expect(forestry.produced.trunks>=6,"woodcutter returns from successive harvested trees")
	var s=fresh()
	expect(not s.command("army",{"order":"attack","target":Vector2i(17,12)}).ok,"empty army order refused")
	advance(s,20);expect(not s.lost and s.tick==20 and s.battle==null,"refused army command leaves the village running")
	s._ensure_battle();s.battle.recruit("lancer")
	for unit in s.battle.units:
		if unit.team=="ally":unit.hp=0
	s.step();expect(not s.lost,"company casualties do not defeat civilian village")
	expect(s.battle.recruit("lancer"),"company accepts replacement")
	s.step();expect(s.tick==22 and not s.battle.defeated,"simulation resumes with replacement company")
	for id in Spec.CAMPAIGN:
		var m=fresh();expect(m.command("load_mission",{"id":id}).ok,"mission starts "+id)
		var spec=Spec.load_id(id)
		var declared_people:=0
		for group in spec.start.workers:declared_people+=int(group.n)
		expect(m.buildings.size()==spec.start.buildings.size() and m.workers.size()==declared_people,"mission applies declared buildings/people "+id)
		expect(m.profession_counts().get("instructor",0)==1,"mission has bootstrap instructor "+id)
		var state=json_state(m)
		var twin=fresh();expect(twin.restore(state),"JSON mission save loads "+id)
		expect(twin.mission!=null and twin.mission.id==id,"mission identity roundtrip "+id)
		var other=fresh();other.command("load_mission",{"id":"tsk-01" if id!="tsk-01" else "tsk-04"})
		expect(other.restore(state) and other.mission.id==id,"loaded mission replaces destination rules "+id)
		advance(m,10);advance(twin,10)
		expect(json_state(m)==json_state(twin),"mission remains deterministic after restore "+id)
	var frozen=fresh();frozen._ensure_battle();frozen.step()
	var frozen_state=json_state(frozen);frozen_state.erase("combat_enabled");frozen_state.lost=true
	var recovered=fresh();expect(recovered.restore(frozen_state) and not recovered.lost,"legacy company freeze recovers on restore")
	expect(recovered.restore(json_state(fresh())) and recovered.battle==null,"battle-free save clears an existing company")
	var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/september_11_save.json"))
	expect(fresh().restore(old),"authentic September 11 snapshot migrates")
	var state=json_state(fresh())
	for bucket in ["stock","reserved","consumed","produced","initial"]:
		for ware in ["charcoal","ore","iron","sword"]:state[bucket].erase(ware)
	for b in state.buildings:
		for bucket in ["input","output","delivered"]:
			for ware in ["charcoal","ore","iron","sword"]:b[bucket].erase(ware)
	var migrated=fresh();expect(migrated.restore(state),"pre-iron inventory fixture migrates")
	state.buildings[0].input.iron=-1;expect(not fresh().restore(state),"migration rejects corrupt quantities")
	var mission=fresh();mission.command("load_mission",{"id":"tsk-04"})
	expect(mission.restore(json_state(fresh())) and mission.mission==null,"sandbox restore clears mission")
	var peaceful=fresh();peaceful.combat_enabled=false
	expect(not peaceful.command("army",{"order":"attack","target":Vector2i(17,12)}).ok,"peaceful mode refuses army")
	expect(not peaceful.command("recruit",{"role":"lancer"}).ok,"peaceful mode refuses recruitment")
	var peace=fresh();expect(peace.restore(json_state(peaceful)) and not peace.combat_enabled,"peaceful choice persists")
	# Execute the first lesson using legal build, road and training commands.
	var lesson=fresh();lesson.command("load_mission",{"id":"tsk-01"})
	for plan in [["training",Vector2i(12,10)],["inn",Vector2i(4,6)],["lumber",Vector2i(3,18)],["quarry",Vector2i(12,19)]]:
		expect(lesson.command("build",{"kind":plan[0],"cell":plan[1]}).ok,"lesson places "+plan[0])
	for b in lesson.buildings:link(lesson,b.entrance)
	lesson.command("train",{"role":"lumberjack"});lesson.command("train",{"role":"stonecutter"})
	for i in range(12000):
		lesson.step()
		if lesson.won:break
	expect(lesson.won and lesson.profession_counts().get("lumberjack",0)>0 and lesson.profession_counts().get("stonecutter",0)>0,"first lesson completes including trained professions")
	expect(lesson.conservation_errors().is_empty(),"lesson conserves inventory")
	expect(lesson.completed_missions.has("tsk-01"),"campaign completion recorded")
	var resumed=fresh();expect(resumed.restore(json_state(lesson)) and resumed.completed_missions.has("tsk-01"),"campaign completion survives save")
	# Repeatable forestry and trade rewards have persisted ledgers.
	var town=fresh();var tree:Vector2i=town.harvest_map.tree_cells()[0];town.harvest_map.harvest(tree)
	town.tick=town.FORESTRY_REGROW_TICKS-1;town.step()
	expect(town.harvest_map.has_tree(tree),"scheduled forestry regrows a stump")
	var copy=fresh();expect(copy.restore(json_state(town)) and copy.forestry_due==town.forestry_due,"forestry schedule persists")
	var loot_only=fresh();loot_only.stock.gold+=100;loot_only.produced.gold+=100;loot_only._update_progression()
	expect(loot_only.trade_contracts==0,"loot does not count as a trade sale")
	town.stock.gold+=100;town.produced.gold+=100;town.stats.gold_earned+=100;town._update_progression()
	expect(town.trade_contracts==1 and town.produced.gold==110,"actual gold earnings pay one contract bonus")
	town._update_progression();expect(town.trade_contracts==1,"contract cannot pay twice for the same earnings")
	expect(town.conservation_errors().is_empty(),"contract rewards conserve the ledger")
	print("RELIABILITY_RESULT checks=",checks," failures=",failures)
	quit(0 if failures.is_empty() else 1)
