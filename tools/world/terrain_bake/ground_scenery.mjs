// Applies the plan of ground_scenery.gd to World/CampaignWorld.tscn. Only elevations and the matching
// Visuals offsets of Scenery nodes change. Ground positions stay.
//   node tools/world/terrain_bake/ground_scenery.mjs <plan.json>
import fs from "node:fs";
const scene = "World/CampaignWorld.tscn";
const plan = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const blocks = fs.readFileSync(scene, "utf8").split(/^(?=\[)/m);
const index = new Map();
blocks.forEach((b, i) => {
  const m = /^\[node name="([^"]+)"[^\n]* parent="([^"]+)"/.exec(b);
  if (m) index.set(m[2] + "/" + m[1], i);
});
let count = 0;
const text = (v) => (Number.isInteger(v) ? v.toFixed(1) : String(v));
for (const [path, value] of Object.entries(plan)) {
  const i = index.get(path), k = index.get(path + "/Visuals");
  if (i === undefined || k === undefined) throw new Error("missing " + path);
  blocks[i] = blocks[i].replace(/^elevation = .*\r?\n/m, "");
  if (value !== 0) blocks[i] = blocks[i].replace(/^(script = .*\r?\n)/m, `$1elevation = ${text(value)}\n`);
  blocks[k] = blocks[k].replace(/^position = .*\r?\n/m, "");
  if (value !== 0) blocks[k] = blocks[k].replace(/^(\[node .*\r?\n)/, `$1position = Vector2(0, ${-value})\n`);
  count++;
}
fs.writeFileSync(scene, blocks.join(""));
console.log("GROUNDED " + count);
