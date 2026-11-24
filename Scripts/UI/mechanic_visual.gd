extends RefCounted
const PUZZLE_EXPLANATIONS := {
	"melt_heat_routing": "Selected pipes carry heat to ice. The ice gains heat and melts into the same water as a liquid.",
	"melt_direct": "The ice gained heat and became liquid water. This change is melting. It is still water.",
	"melt_fueled_airflow": "Fuel supplies heat while the fan provides air for the fire. The ice gains heat and melts into liquid water.",
	"melt_solar_relay": "The mirrors direct light to the receiver, which supplies heat. The ice gains heat and melts into liquid water."
}
## Lesson text shared by the current Level 1 guides.
const LESSONS := {
"task_sidebar":["Task sidebar and objectives",["Your next action and objectives share one sidebar.","DO: tap the edge arrow to slide the sidebar away. Tap it again to reopen. Tap a group heading to fold or expand its tasks.","Checkboxes mark completed tasks. Progress bars combine repeated objectives, such as ice barriers and crystals."]],
"warmth":["Warmth %",["Cold drains your warmth.","DO: stand near a lit heater or campfire to recover warmth. At 0%, return to your checkpoint.","Warmth rises beside heat; keep warm while exploring."]],
"coat":["Insulated coat",["Your coat protects you in these gardens.","DO: explore with your insulated coat. Its protected warmth meter stays full in this zone.","The protected meter stays at 100%."]],
"crystals":["Collecting crystals",["Crystals are exploration rewards.","DO: approach a crystal and interact. In melting levels, stay nearby to thaw it, then interact again to collect.","Collected crystals count toward the exit requirement."]],
"fuel":["Collecting wood",["The second heater needs fuel.","DO: approach the wood pile and interact to collect it. Take the wood to the second heater.","Fuel collected. Repair airflow, then light the heater."]],
"fan_blades":["Fan blades",["The fan needs its missing blades.","DO: collect the blades, then interact with the fan housing to install them.","The repaired fan supplies air to the heater."]],
"sluice":["Sluice valves",["An empty basin needs water.","DO: OPEN the sluice to fill the basin; CLOSE it when full before switching cooling on.","Still water can freeze into a crossing."]],
"coolant":["Coolant crystals and sockets",["Later cooling circuits need power.","DO: collect the coolant crystal, carry it to its socket, then interact to install it.","The socket lights up and enables its cooling circuit."]],
"checkpoint":["Checkpoint statues",["Statues mark safe return points.","DO: approach a statue and interact to attune it and save your checkpoint.","Restarting from a checkpoint returns you to safe ground."]],
"map":["Map and fast travel",["Attuned statues become map destinations.","DO: open Map. Choose an attuned statue to travel to safe ground.","Your map shows discovered checkpoint destinations."]],
"notes":["Trail notes",["Notes explain nearby puzzles.","DO: approach the sign and interact to read its clue.","Use the clue to solve the nearby equipment."]],
"professor":["Professor Scaldwell",["The professor offers lessons and hints.","DO: approach Professor Scaldwell and interact to ask about this level's mechanics.","Choose a lesson or a hint when you need help."]],
"altar":["Knowledge altars",["Altars test what you have learned.","DO: approach the altar and interact. Answer its questions; incorrect answers explain what to try again.","Earn knowledge seals or workshop materials."]],
"exit":["Exit gates",["The exit checks your objectives.","DO: finish the required puzzles, collect the required crystals, then interact with the gate.","The next level becomes available after completion."]],
"movement":["Moving and sprinting",["Explore the trails to find equipment.","DO: use the movement stick. Hold Sprint to run; interact when close to an object.","Move close to new objects to discover more guides."]],
"melting":["Melting",["BEFORE: solid ice blocks the path.","DO: switch on heat. Orange arrows carry energy INTO the ice.","RESULT: ice shrinks into a growing puddle. Solid becomes liquid."]],
"fuel_air":["Fuel and airflow",["BEFORE: the heater has no usable fire.","DO: add wood and install the fan blades. Fuel AND air support the fire.","RESULT: the fan spins, fire grows, and heat reaches the ice."]],
"conduction":["Copper conduction",["BEFORE: a closed or wooden link carries too little heat.","DO: choose COPPER and light the heater. Follow orange heat pulses.","RESULT: heat travels through metal and melts the ice at the far end."]],
"reflection":["Mirror relay",["BEFORE: a misaligned beam misses the receiver.","DO: rotate mirrors until the beam touches the next mirror and receiver.","RESULT: a continuous beam heats the receiver and melts the gate."]],
"freezing":["Freezing",["BEFORE: liquid water cannot support a crossing.","DO: fill the basin, CLOSE the sluice, then switch cooling ON.","RESULT: heat flows OUT. Frost spreads until solid ice supports the path."]],
"condensation":["Condensation",["Water vapor is water in its gas state. When humid air cools below its dew point at the pane, some vapor becomes liquid droplets.","At Dewglass the regulated pane stays above 0°C. Water in the air supplies the droplets. The glass stays sealed.","Freezing starts with liquid water. Cryo removes more heat from the separate cartridge until its water becomes solid ice. The cartridge cools the pane through the jacket while the collected water stays liquid."]],
"sublimation":["Sublimation",["In the Vanishing Ice Lab, water ice gains heat inside a sealed chamber at suitable low pressure.","Solid water changes directly into water vapor. The gas indicator rises while the liquid sensor stays at zero.","Water vapor is invisible. Dots in the diagram are a model."]],
"deposition":["Deposition",["In the Frostprint Chamber, the sealed collector regulates pressure while the cold plate removes heat from supplied water vapor.","Solid ice grows directly from the gas while the liquid sensor stays at zero.","The frost is a sensor sample. The permanent metal step supports the player."]],
"cycle":["Melt, fill, close, freeze",["BEFORE: frozen source, empty basin, no crossing.","DO: HEAT source, OPEN sluice until full, CLOSE it, then choose COOL.","RESULT: the same water changes solid > liquid > solid. The bridge opens."]],
"pressure":["Pressure safety",["BEFORE: the exchanger's sealed hot loop shows a red pressure gauge.","DO: OPEN the pressure release before switching the exchanger to HEAT.","RESULT: vapor vents, the gauge falls into green, and heating is enabled."]],
"routing":["Water routing",["BEFORE: the selector sends water to sea or drain, so the basin stays empty.","DO: point the brass selector toward COOLING STATION, then open the sluice.","RESULT: blue water pulses reach the reservoir and its water level rises."]],
"insulation":["Insulation",["BEFORE: heat from warmer surroundings keeps entering the cold basin.","DO: apply the thermal wrap before cooling the full, closed basin.","RESULT: the wrap slows unwanted heat transfer. Frost can spread."]],
"balance":["Mass and balance",["BEFORE: the empty counterweight tray leaves the beam tilted.","DO: choose SAME MASS as the sealed water sample, not double mass.","RESULT: the beam levels. Freezing changes state, not the sample's mass."]],
"recovery":["Recover heat, raise lift",["BEFORE: the lift is down and the recovery tank is empty.","DO: freeze the full basin. Capture the heat leaving the water; then RELEASE lift.","RESULT: the recovery engine raises the platform and opens the crossing."]],
"assembly":["Build the thermal skiff",["BEFORE: an empty hull waits at the dock.","DO: solve four workshops and their questions. Bring plates, engine, runners and sail.","RESULT: install all four parts, then LAUNCH to unlock Mistfall Highlands."]]
}
