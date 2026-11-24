extends RefCounted
## District-authored teaching copy, available with or without the owning chunk.
const LESSONS := {
	"Z1L1": {
		"melting": {"title": "First thaw · Thermal", "paragraphs": [
			"Solid ice gains heat and becomes liquid water. It is still water.",
			"Tap Thermal in the lower-left device slot. Face the first ice barrier and move close until its target cue appears. Hold Fire to melt it. Release to stop.",
			"Jump the marked low log. Fuel and repair the separate fan heater; align all three mirrors later. Thermal cannot replace those machines. Guides and demonstrations are free.",
		]},
	},
	"Z1L2": {
		"resonance": {"title": "Bell yard · low, middle, high", "paragraphs": [
			"Ring the three bells in pitch order. Their vibration fractures the bridge ice; this is mechanical breaking, not melting.",
			"After C1, select Thermal, aim at each water-ice casing and hold Fire for four cumulative seconds. Release or lose the hit to stop heating. Metal parts stay solid. Carry each released part to its matching tray.",
		]},
		"melting": {"title": "Thaw & Sort · Thermal", "paragraphs": [
			"Select Thermal. Face each water-ice casing with a clear muzzle path; hold Fire for four cumulative valid seconds. Release or lose aim to stop heating.",
			"Ice gains heat and becomes liquid water. The gear, crank and brake shoe remain solid metal. Lift each released part and place it in its matching tray. Wrong placement keeps the part in your hands.",
			"Completed thaws and placements survive Continue and death. New unfinished heat resets on reload/death. Help and replay are free.",
		]},
		"balance": {"title": "Freight lift", "paragraphs": [
			"Heavy winch adds three units. Light winch cycles zero through three. Balance the five-unit load.",
			"Jump the marked maintenance gap empty-handed, lower the return bridge, then carry the brake pin back to its housing. Installed brake pin secures the exit. The observation question is optional.",
		]},
	},
	"Z1L3": {
		"freezing": {"title": "Stillwater Crossing · remove heat", "paragraphs": [
			"I am Professor Scaldwell. Freezing changes liquid water into solid ice when water loses heat. Cryo removes heat; it does not make water or cold material. The first shallow tray already contains water.",
			"After this lesson, select Cryo, face the filled tray, and hold Fire for three valid seconds. Wait for SOLID / SECURED before crossing. Later empty trays must receive real meltwater first.",
			"Use learned Thermal to melt the two-unit supply, then open its fixed supply valve. Both bridge trays fill through the pipe. Disconnect their heater before Cryo can freeze them. Freeze both, then operate the mechanical latch. Jump the small gap only after SECURED.",
		]},
		"melting": {"title": "Reuse Thermal · supply liquid water", "paragraphs": [
			"Thermal adds heat to the supply ice. It becomes liquid water; the substance stays water. Melt this finite two-unit supply, then open its valve. One unit fills each empty bridge tray.",
			"Cryo on an empty tray cannot create water or ice. A connected heater prevents freezing. Disconnect it, remove heat, confirm both SOLID indicators, and operate the latch. Secured ice cannot thaw under your feet.",
		]},
	},
	"Z1L4": {
		"canal": {"title": "Two-State Canal · separate the branches", "paragraphs": [
			"Thaw the blocked inlet with Thermal. Divert the water to fill the side branch, then close its divider so liquid can still turn the main wheel.",
			"Freeze the isolated side branch before crossing. Thaw the misaligned bridge lock, carry it to its socket, refreeze it with Cryo, then secure the mechanical latch.",
		]},
	},
	"Z1L5": {
		"workshop": {"title": "Snowbound Workshop · fit and release", "paragraphs": [
			"Align both mirrors so the receiver heats the storage latch. Open it when the ice thaws, then fill the jig with water and open the walking return.",
			"Freeze the filled jig with Cryo, fit the plank, then use Thermal to release it. Drain the meltwater and stow the sample before recording the blueprint.",
		]},
	},
	"Z1L6": {
		"freezing": {"title": "Frozen Dock · free help", "paragraphs": [
			"Lower the cargo ramp, then thaw the three plank casings with Thermal. Carry each bundle to the nearby rack.",
			"Fill the service walkway, use Cryo, then latch the frozen frame. Carry the rope and sailcloth back across to their rack. Divert heat away from the crossing before using Thermal on the rudder chest.",
			"Fill and freeze the assembly jig. Open its recipe and fit all six staged parts. Use Thermal to release the hull, test it in liquid water, then talk to Finn. After Finn passes you, board at the dock exit.",
		]},
		"melting": {"title": "Frozen Dock · melting", "paragraphs": [
			"Thermal adds heat to solid water. Melting the casing releases the part. Melting the temporary jig frees the wooden hull to float in liquid water.",
		]},
	},
	"Z2L1": {
		"vaporization": {"title": "Sunlit Landing · two ways to vaporize", "paragraphs": [
			"Use your Thermal mode from Zone 1. First, open the Sunny Tray canopy and shutter. Turn the reflector until it is aligned, fill the shallow tray, then heat it. Watch the surface lose water without bubbles forming throughout the liquid. Set the uncovered float latch.",
			"Next, fill the separate comparison chamber and close its guard. Its vent stays open. Heat until bubbles form throughout the water and the vapor turns the model wheel. Water vapor is invisible. The moving marks are a model.",
			"Set the wheel latch. Add heat to melt the crate ice. Fill the support tray, then remove heat with Cryo and secure the solid ice in its frame. Walk out and back with the plank, fit it to the landing, then head to the exit.",
		]},
	},
	"Z2L2": {
		"vaporization": {"title": "Drying Orchard · choose a process", "paragraphs": [
			"Spread the wet belt on the rack. Open the sunny shutter for energy and start the fan to carry moist air away. Start drying, then check the belt. Carry it to the drive socket on the walking path.",
			"At the boiler, supply water, close the inspection cover and leave the vent open. Aim Thermal at the guarded chamber until bubbles form throughout the water. Route the vapor to the turbine to raise the harvest gate.",
			"At the service plinth, choose a process for a wet cloth, then for a powered wheel. Both setups have a free reset. Release the exit latch after both tools work.",
		]},
	},
	"Z2L3": {
		"condensation": {"title": "Dewglass · where droplets come from", "paragraphs": [
			"Open the feed from the warm evaporation tray. Its humid air contains invisible water vapor. Dots on the feed are a model of that vapor.",
			"Select Cryo and hold Fire at the pane. Its regulator cools it to +6°C, below this air’s +12°C dew point. Vapor loses heat and becomes liquid droplets. The sealed glass separates the air from the coolant.",
			"Join the gutter and seat the tank. Fill the separate cartridge in the workroom and use Cryo until its liquid freezes solid. Walk it back to the jacket. The jacket holds the pane above freezing as droplets drain into the irrigation tank.",
		]},
	},
	"Z2L4": {
		"return_circuit": {"title": "Returning Stream · follow the water", "paragraphs": [
			"Find the circuit on the C1 terrace south of this station. Use Thermal to melt the inlet ice, then route the liquid to the basin. Fit the channel pieces, clamp the cover and open the shutter. Sunlight supplies heat for surface evaporation. The dots model invisible water vapor inside the covered channel.",
			"Test the warm plate first. It stays above the dew point, so the tank stays empty. Use Cryo to remove heat from the plate. The plate cools below the dew point while staying above freezing. Droplets are liquid water from the same batch.",
			"Drain and measure the returned liquid to power the lift through its water drive. Ride up and engage the mechanical lock. Walk onto the landing, then jump across the fixed gap. The heater, sunlight and cooler exchange energy with the water.",
		]},
	},
	"Z2L5": {
		"steamworks": {"title": "Steamworks Garden · follow the water and heat", "paragraphs": [
			"Melt the inlet ice with Thermal. Spread the wet belt, let sunlight warm it and start the fan. Airflow carries moisture away. The belt dries as water evaporates from its surface.",
			"Freeze the separate filled cooling pack with Cryo. Carry the dry belt to the turbine drive and the frozen pack to the condenser jacket. Feed the inlet water to the boiler, then close the guard while leaving the vent open.",
			"Apply Thermal to boil the water. Send that vapor through the turbine, then route its exhaust to the condenser. The frozen pack absorbs heat. Use Cryo at the jacket to keep removing heat until droplets form in the condenser. Its water is separate from the pack.",
			"Drain the droplets into the return reservoir. Record the blueprint at C2 and follow the trail to the exit. The turbine stops after the batch. Returned water is reusable. Another batch needs fresh external heat at the boiler and a cooled pack.",
		]},
	},
	"Z2L6": {
		"skybridge": {"title": "Skybridge Engine · fit and test the return circuit", "paragraphs": [
			"Find the shell, turbine and coil at the north parts court. Find the tank and belt at the west parts court. Carry each to its labeled delivery slot.",
			"At the supply court, use Thermal on the feedwater ice and Cryo on the separate filled pack. Fit the exact five parts at the blueprint desk. The fixed feed pipe and separate cooling loop connect the supplies to the engine.",
			"At the engine, connect the supplies and close the boiler guard. Keep the vent open. Use Thermal to boil the water, send vapor through the wheel, then route the exhaust to the condenser.",
			"Use Cryo at the condenser to remove heat. Confirm droplets, then drain two liquid measures into the return tank. The test uses a finite vapor charge. The wheel stops, and another run would need fresh heat and cooling.",
			"See Finn after the test. Answer all four questions, then board at the lift approach.",
		]},
	},
	"Z3L1": {
		"sublimation": {"title": "Vanishing Ice Lab · Sublimation", "paragraphs": [
			"Seal the chamber, set its gauge to Low and enable the heat exchanger. These controls keep the ice below freezing at a suitable low pressure. Heat enters the sample while the pressure stays in the solid–gas region.",
			"Select Vacuum and hold Fire at the observation port. The ice shrinks and the captured-gas indicator rises. Watch the liquid sensor stay at zero. The dots model invisible water vapor.",
			"Use the same prepared chamber at the sample slot. The ice plug changes directly to captured water vapor. Keep the vessel closed.",
			"At the utility bench, spread the damp seal and use Thermal to evaporate its surface moisture. Fit it to the boiler guard. Thermal boils the separate water batch, then the vapor drives the utility. Route its exhaust to the condenser and use Cryo. Drain the liquid droplets into the supply tank.",
		]},
	},
	"Z3L2": {
		"comparison": {"title": "Sample Sorting Room · Observe the path", "paragraphs": [
			"At the western bench, use Thermal to warm water ice at normal pressure. Observe the liquid sensor after the solid melts.",
			"At the middle bench, seal the chamber and set its low pressure and regulated heat. Use Vacuum. Watch for captured gas and check that the liquid tray stays at zero. The dots model invisible water vapor.",
			"At the eastern bench, use those readings to set each route lock. The closed line pumps the captured vapor into a normal-pressure receiver. Use Cryo to cool the humid gas below its dew point on an above-freezing pane. Drain the droplets into the tank.",
		]},
	},
	"Z3L3": {
		"deposition": {"title": "Frostprint Chamber · Deposition", "paragraphs": [
			"Seal the collectors and feed water vapor. Set regulated pressure and start the heat exchanger so heat leaves the vapor at the cold collector. Pressure alone cannot grow frost.",
			"Select Pressure and hold Fire at the supplied collector. Ice grows directly from water vapor while the liquid sensor stays at zero. The dots model invisible vapor.",
			"The comparison bench feeds separate vapor samples to a +8°C dew pane and a colder sealed collector. Use Cryo at the dew pane and Pressure at the frost collector. Compare the readings.",
			"Open the optical vapor inlet and use Pressure until the frost reaches the marked line. The regulator holds the sample at the target. Close the inlet to isolate it and open the observation gate. The permanent metal step supports your weight.",
		]},
	},
	"Z3L4": {
		"circuit": {"title": "Reversible Frost Circuit", "paragraphs": [
			"Seal the source. Choose low pressure and heat in, then use Vacuum to turn water ice directly into captured vapor. Send that vapor to collector A through the closed line.",
			"At A, choose regulated pressure and heat out. Pressure grows frost directly from the supplied vapor until the optical sensor detects it.",
			"Isolate A and choose low pressure and heat in. Use Vacuum again. The frost becomes captured vapor and clears A’s optical sensor. Send the same vapor to B.",
			"At B, choose regulated pressure and heat out. Use Pressure to grow the final frost, then record the working circuit. The dots model invisible water vapor.",
		]},
	},
	"Z3L5": {
		"observatory": {"title": "Six-Change Observatory", "paragraphs": [
			"Follow the service trails between the three exhibits. Decide which state each sample starts in and which state the equipment needs. Choose whether heat should enter or leave before you use the device.",
			"The water at the first bench fills the plate jig. Release the calibration plate and walk it to its stand. The label cloth and boiler at the next bench hold separate water samples. Use the boiler exhaust for the measuring cup.",
			"At the final bench, configure the sealed source and cold collector. The two vessels share one vapor line. Review the saved readings at each station sign. The blueprint desk needs all seven routes and the seated plate.",
		]},
	},
	"Z3L6": {
		"core": {"title": "Phaseworks Core · Frost cartridge", "paragraphs": [
			"Recover five local parts. Melt the water supply and freeze the jig. Dry the label seal, boil the separate supply and collect its exhaust as liquid. Clear the Frost Wing port using a sealed, heated, low-pressure chamber.",
			"Seat each part in its local labeled rack. Fit the cartridge at the blueprint bench. Sublimate its ice, route captured water vapor, and cool the regulated collector to measure direct frost.",
			"Send the tested cartridge to the scanner and insert it. After Finn’s six questions, power the sealed scanner and use Vacuum. Its absence signal is the final reading.",
		]},
	},
}

const EXPLANATIONS := {
	"Z1L2": {
		"ice_resonance": "Low, middle, then high set the bell mechanism vibrating. The bridge ice fractured and cleared. Breaking ice is a mechanical change; it is not evidence that solid water became liquid.",
		"mill_counterweight": "Three units on the heavy winch plus two on the light winch balance the five-unit load. The freight lift raises the brake pin within reach. No phase change occurred.",
	},
	"Z1L3": {
		"freeze_controlled": "The tray held liquid water. Cryo removed heat until that water became solid ice. Water particles remain water; they vibrate around fixed positions. Cryo creates neither water nor a new cold substance. A rigid frame supports this first ice step.",
		"stillwater_latch": "Both filled trays lost heat and became solid ice. You then secured their mechanical frame. The latch holds the crossing; the heater stays isolated. Occupied, secured support does not disappear.",
	},
	"Z1L4": {
		"phase_branch_isolation": "The isolated side channel froze while liquid water kept the main wheel turning. The divider kept the two supplies apart.",
		"melt_freeze_sequence": "Thawing released the lock from the wrong position. You moved it into its socket, refroze the water around it, then secured the crossing with its mechanical latch.",
	},
	"Z1L5": {
		"melt_solar_relay": "Aligned mirrors fed the receiver. The heater added heat to the solid water around the latch and released it for opening.",
		"freeze_jig_release": "The wood frame carries the workpiece. Freezing held the plank in position while you fitted it. Melting the same water released the finished sample so it could be lifted out.",
	},
	"Z1L6": {
		"melt_direct": "Thermal adds heat to the ice casing. The water changes from solid to liquid and frees the part inside.",
		"freeze_controlled": "Cryo removes heat from liquid water. The ice fills a rigid, mechanically secured frame so you can walk back with cargo.",
		"freeze_jig_release": "Ice held the boat in its wooden assembly frame. Adding heat released the hull. The hull displaces liquid water and floats on its own.",
	},
	"Z2L1": {
		"evaporate_surface": "Water molecules escaped into the air from the exposed surface. The water level fell without bubbles forming throughout the liquid. Evaporation can occur below the boiling point. The moving marks show a model of invisible water vapor.",
		"boil_volume": "The enclosed comparison chamber stayed vented. At boiling, water vapor formed bubbles throughout the liquid, and the escaping vapor turned the model wheel. Both observations changed liquid water into gas. The gas itself is invisible.",
	},
	"Z2L2": {
		"evaporate_drying": "Water escaped from the belt’s wet surface below boiling. Sunlight supplied energy. The fan carried moist air away, allowing more water to evaporate.",
		"boil_volume": "Bubbles of water vapor formed throughout the supplied water. Routing that vapor turns the model turbine.",
	},
	"Z2L3": {
		"condense_collect": "The starter cup caught liquid droplets from the air side of the sealed pane. Water vapor from the evaporation tray lost heat at +6°C and became liquid. Freezing starts with liquid water and makes solid ice.",
		"freeze_controlled": "Liquid water inside the cartridge lost heat and froze into solid ice. That sealed ice supplies cooling to the jacket. Water vapor from the tray supplies the liquid droplets on the pane.",
	},
	"Z2L4": {
		"evaporate_condense_route": "The same water traveled from inlet ice to basin liquid to invisible vapor and back to liquid in the tank. Sunlight supplied heat for evaporation. Cryo carried heat away at the plate. The water drive raises the lift and its mechanical lock holds it in place.",
	},
	"Z2L5": {
		"evaporate_drying": "Sunlight supplies heat for evaporation from the wet belt. Airflow carries away the water vapor.",
		"boiler_reservoir_return": "Thermal supplied heat to boil the inlet water. The vapor did work at the turbine, then gave up heat at the condenser and returned as liquid. The turbine has stopped. Reusing the water requires fresh boiler heat and cooling.",
	},
	"Z2L6": {
		"skybridge_return_test": "Vapor from externally heated water drove the wheel. Exhaust then gave up heat and condensed. The tank received two liquid measures. Cooling used a separate charge, and the next run would need fresh heat.",
	},
	"Z3L1": {
		"sublime_controlled": "At suitable low pressure, this water ice gained heat and changed directly into gas. The captured-gas indicator tracked the vapor while the liquid tray stayed empty. The water changed state inside the sealed chamber.",
		"boil_condense_cycle": "The boiler needed external heat to make vapor throughout its water. The utility used that vapor, and cooling its exhaust produced the liquid collected in the tank. This was a separate batch from the sublimation samples.",
	},
	"Z3L2": {
		"melt_sublime_compare": "Both pieces of ice shrank. At normal pressure, the liquid sensor detected meltwater. In the sealed low-pressure chamber, the gas sensor detected vapor while the liquid tray stayed at zero. The receiver brought that vapor to normal pressure, where cooling produced liquid water.",
	},
	"Z3L3": {
		"deposit_frost": "The sealed, regulated collector removed heat from water vapor. Solid ice grew directly on the cold plate while the liquid sensor stayed at zero. That gas-to-solid change is deposition.",
		"condense_deposit_compare": "The +8°C pane stayed above freezing but below the dew point, so it collected liquid. The colder, regulated collector grew solid ice directly. Dew forms by condensation and can freeze later if it loses more heat.",
	},
	"Z3L4": {
		"sublime_deposit_cycle": "One water sample travelled through both sealed lines as vapor. Heat entered the source and later collector A to sublimate their ice. Heat left at A and B as vapor deposited into frost. Both directions bypassed the liquid state.",
	},
}
