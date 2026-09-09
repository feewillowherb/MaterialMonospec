import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const siteRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const out = path.join(siteRoot, "preserved", "2026-01-posted-old-q5");
const statePath = path.join(
  siteRoot,
  "sand-addbatch-submit",
  "state",
  "2026-01",
  "submit-state.jsonl",
);
const jsonDir = path.join(
  siteRoot,
  "sand-addbatch-submit",
  "seeds",
  "2026-01",
  "source-run",
  "2026-09-09T152356",
  "json",
);

fs.mkdirSync(path.join(out, "json"), { recursive: true });
fs.mkdirSync(path.join(out, "state"), { recursive: true });

const keep = new Map();
const stateRows = [];
for (const line of fs.readFileSync(statePath, "utf8").split(/\r?\n/)) {
  if (!line.trim()) continue;
  const o = JSON.parse(line);
  if (o.status === "posted" || o.status === "smoke-posted") {
    keep.set(o.dataNo, o);
    stateRows.push(o);
  }
}

function shortConsignee(name) {
  if (name.includes("腾满")) return "tengman";
  if (name.includes("三野")) return "sanye";
  if (name.includes("永武")) return "yongwu";
  if (name.includes("起陆")) return "qilu";
  if (name.includes("锦秋")) return "jinqiu";
  return "co";
}

const byConsignee = new Map();
for (const f of fs.readdirSync(jsonDir).filter((x) => x.endsWith(".json"))) {
  for (const r of JSON.parse(fs.readFileSync(path.join(jsonDir, f), "utf8"))) {
    if (!keep.has(r.dataNo)) continue;
    const list = byConsignee.get(r.consignee) || [];
    list.push(r);
    byConsignee.set(r.consignee, list);
  }
}

let tripCount = 0;
let netTotal = 0;
const per = [];
for (const [consignee, trips] of byConsignee) {
  trips.sort((a, b) =>
    a.outTime < b.outTime ? -1 : a.outTime > b.outTime ? 1 : 0,
  );
  const slug = shortConsignee(consignee);
  const batchSize = 100;
  for (let i = 0; i < trips.length; i += batchSize) {
    const part = String(Math.floor(i / batchSize)).padStart(3, "0");
    const file = path.join(out, "json", `2026-01-${slug}.part${part}.json`);
    fs.writeFileSync(
      file,
      JSON.stringify(trips.slice(i, i + batchSize), null, 2),
      "utf8",
    );
  }
  const net =
    Math.round(trips.reduce((a, t) => a + t.netWeight, 0) * 100) / 100;
  tripCount += trips.length;
  netTotal = Math.round((netTotal + net) * 100) / 100;
  per.push({
    consignee,
    trips: trips.length,
    netWeight: net,
    dataNoSample: trips[0].dataNo,
  });
}

stateRows.sort((a, b) => String(a.postedAt).localeCompare(String(b.postedAt)));
fs.writeFileSync(
  path.join(out, "state", "submit-state.posted.jsonl"),
  stateRows.map((o) => JSON.stringify(o)).join("\n") + "\n",
  "utf8",
);

const manifest = {
  purpose:
    "January 2026 already-posted trips under OLD Q5 weights (net~21 / tare~13.5 / gross~35)",
  month: "2026-01",
  pointNumber: "XNYH20251113001",
  sourceRun:
    "sand-addbatch-submit/seeds/2026-01/source-run/2026-09-09T152356",
  durableState: "sand-addbatch-submit/state/2026-01/submit-state.jsonl",
  archivedAt: new Date().toISOString(),
  q5Old: { tripNet: "19-23", tare: "13-14.5", gross: "33-37" },
  tripCount,
  netTotal,
  perConsignee: per,
  note: "Do not re-POST these dataNo. Keep when regenerating pending under new Q5 (~50/20/70).",
};
fs.writeFileSync(
  path.join(out, "manifest.json"),
  JSON.stringify(manifest, null, 2),
  "utf8",
);
console.log(JSON.stringify(manifest, null, 2));
