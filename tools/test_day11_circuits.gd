extends SceneTree
const Circuit=preload("res://act4/circuit.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void:call_deferred("run")
func verify(ok: bool, label_: String) -> void:
	checks+=1
	if not ok:failures.append(label_);printerr("CIRCUIT_CHECK_FAILED ",label_)
func run() -> void:
	var counts: Array=[]
	var best_total:=0
	for level in range(3):
		var answers:=Circuit.all_solutions(level)
		counts.append(answers.size())
		verify(not answers.is_empty(),"Every lock must have a solution")
		if level>0:verify(answers.size()==1,"Second and third locks must each have one solution")
		var best:=Circuit.solution(level)
		best_total+=best.coils.reduce(func(a,b):return a+b,0)
		verify(Circuit.evaluate(level,best.routes,best.coils).ok,"Hint must propose a valid solution")
		for lane in range(Circuit.count_(level)):
			for route in range(3):
				var wire:=Circuit.path(level,lane,route)
				verify(wire.size()==Circuit.length_(level,lane,route)+1,"Visible path must match travel length")
				for coil in range(Circuit.coil_limit(level)+1):
					var arrival:=Circuit.arrival(level,lane,route,coil)
					verify(is_equal_approx(Circuit.distance_at(level,lane,route,coil,arrival),wire.size()-1),"Animation must reach the endpoint at the evaluated beat")
					verify(Circuit.distance_at(level,lane,route,coil,arrival-.01)<wire.size()-1,"Animation must not visually finish before the evaluated beat")
		verify(not Circuit.evaluate(level,[],[]).ok,"Malformed arrays must fail without crashing")
		var invalid_routes: Array=best.routes.duplicate();invalid_routes[0]=3
		verify(not Circuit.evaluate(level,invalid_routes,best.coils).ok,"Unknown route must fail")
		var invalid_coils: Array=best.coils.duplicate();invalid_coils[0]=Circuit.coil_limit(level)+1
		verify(not Circuit.evaluate(level,best.routes,invalid_coils).ok,"Out-of-range coil count must fail")
	verify(counts==[10,1,1],"Exhaustive solution counts changed")
	var bridge: Dictionary=Circuit.all_solutions(1)[0]
	verify(bridge.routes==[0,2] and bridge.coils==[1,1],"Unique bridge configuration differs from its public rule")
	var bridge_result:=Circuit.evaluate(1,bridge.routes,bridge.coils)
	verify(bridge_result.gate_times==[4,7] and bridge_result.times==[7,10],"Bridge timing differs from crossing/cooldown rules")
	verify(not Circuit.evaluate(1,[0,2],[1,0]).ok,"Entering before cooldown must fail")
	verify(not Circuit.evaluate(1,[0,1],[1,0]).ok,"Simultaneous entry must not solve lock two")
	var red_path:=Circuit.path(1,0,0);var blue_path:=Circuit.path(1,1,2)
	for offset in range(3):verify(red_path[Circuit.approach_length(0,0)+offset]==blue_path[Circuit.approach_length(1,2)+offset],"Both balls must visibly share one bridge")
	var clock: Dictionary=Circuit.all_solutions(2)[0]
	verify(clock.routes==[0,2,0] and clock.coils==[0,3,0],"Unique clock configuration must use the published three-coil solution")
	verify(Circuit.evaluate(2,clock.routes,clock.coils).times==[8,10,12],"Clock windows differ from the displayed targets")
	verify(not Circuit.evaluate(2,[0,2,0],[0,2,0]).ok,"Two coils must fail for an explained timing reason")
	verify(Circuit.all_solutions(2,2).is_empty(),"No hidden two-coil solution is allowed")
	verify(Circuit.all_solutions(2,99).size()==1,"A caller must not bypass the stated coil budget")
	verify(Circuit.distance_at(2,1,2,3,9.5)<24,"Blue's final partial segment must take a whole beat")
	verify(best_total==Circuit.HIGH_SCORE_COILS,"High-score target must remain achievable")
	print("DAY11_CIRCUITS_TEST ",JSON.stringify({"checks":checks,"solution_counts":counts,"best_coils":best_total,"failures":failures}))
	quit(0 if failures.is_empty() else 1)
