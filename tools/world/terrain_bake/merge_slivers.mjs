// Applies the plan of merge_slivers.gd to World/CampaignWorld.tscn. Only Floors nodes change.
//   node tools/world/terrain_bake/merge_slivers.mjs <plan.json>
import fs from "node:fs";
const scene = "World/CampaignWorld.tscn";
const plan = JSON.parse(fs.readFileSync(process.argv[2], "utf8"));
const text = fs.readFileSync(scene, "utf8");
const blocks = text.split(/^(?=\[)/m);
const at = new Map();
blocks.forEach((b, i) => {
  const m = /^\[node name="([^"]+)" type="Polygon2D" parent="([^"]+\/Layout\/Floors)"/.exec(b);
  if (m) at.set(m[2] + "/" + m[1], i);
});
let kept = 0, gone = 0;
for (const p of plan) {
  const i = at.get(p.parent + "/" + p.keep);
  if (i === undefined) throw new Error("missing " + p.parent + "/" + p.keep);
  const next = blocks[i].replace(/^polygon = PackedVector2Array\([^)]*\)/m, "polygon = " + p.polygon);
  if (next === blocks[i]) throw new Error("no polygon in " + p.keep);
  blocks[i] = next;
  kept++;
  for (const name of p.remove) {
    const k = at.get(p.parent + "/" + name);
    if (k === undefined) throw new Error("missing " + name);
    blocks[k] = "";
    gone++;
  }
}
fs.writeFileSync(scene, blocks.join(""));
console.log(`MERGED ${gone} floors into ${kept}`);
