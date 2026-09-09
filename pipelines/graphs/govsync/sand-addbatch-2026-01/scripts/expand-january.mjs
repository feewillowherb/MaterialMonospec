/**
 * experimental — sand-addbatch-2026-01
 * Expand Jan 2026 monthly sand tonnage → §2.2 addBatch JSON (dryRun).
 *
 * node expand-january.mjs --outDir <runDir> --seeds <yaml> --csvDir <pool> [--embedPhotos]
 */
import fs from "node:fs";
import path from "node:path";

function parseArgs(argv) {
  const o = { embedPhotos: false };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--outDir") o.outDir = argv[++i];
    else if (a === "--seeds") o.seeds = argv[++i];
    else if (a === "--csvDir") o.csvDir = argv[++i];
    else if (a === "--embedPhotos") o.embedPhotos = true;
    else if (a === "--seed") o.seed = Number(argv[++i]);
    else if (a === "--pointNumber") o.pointNumber = argv[++i];
  }
  return o;
}

/** @param {number} seed */
function mulberry32(seed) {
  let t = seed >>> 0;
  return () => {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

function round2(n) {
  return Math.round(n * 100) / 100;
}

function parseSimpleYamlTotals(text) {
  const yearMatch = text.match(/(?m)^year:\s*(\d+)/);
  const year = yearMatch ? Number(yearMatch[1]) : 2026;
  const productNames = ["再生细骨料", "再生粉料"];
  const rows = [];
  const blockRe =
    /-\s*consignee:\s*(.+)\r?\n\s*months:\s*\{\s*([^}]+)\}/g;
  let m;
  while ((m = blockRe.exec(text))) {
    const consignee = m[1].trim();
    const months = {};
    for (const part of m[2].split(",")) {
      const kv = part.trim().match(/(\d+)\s*:\s*([0-9.]+)/);
      if (kv) months[Number(kv[1])] = Number(kv[2]);
    }
    rows.push({ consignee, months });
  }
  return { year, productNames, rows };
}

function parseCsv(text) {
  const lines = [];
  let i = 0;
  const s = text.replace(/^\uFEFF/, "");
  while (i < s.length) {
    const row = [];
    while (i < s.length) {
      if (s[i] === '"') {
        i++;
        let cell = "";
        while (i < s.length) {
          if (s[i] === '"' && s[i + 1] === '"') {
            cell += '"';
            i += 2;
            continue;
          }
          if (s[i] === '"') {
            i++;
            break;
          }
          cell += s[i++];
        }
        row.push(cell);
      } else {
        let cell = "";
        while (i < s.length && s[i] !== "," && s[i] !== "\n" && s[i] !== "\r") {
          cell += s[i++];
        }
        row.push(cell);
      }
      if (s[i] === ",") {
        i++;
        continue;
      }
      if (s[i] === "\r") i++;
      if (s[i] === "\n") {
        i++;
        break;
      }
      break;
    }
    if (row.length > 1 || (row.length === 1 && row[0] !== "")) lines.push(row);
  }
  if (!lines.length) return [];
  const header = lines[0];
  return lines.slice(1).map((cols) => {
    const obj = {};
    for (let c = 0; c < header.length; c++) obj[header[c]] = cols[c] ?? "";
    return obj;
  });
}

function daysInMonth(year, month) {
  return new Date(year, month, 0).getDate();
}

function pad2(n) {
  return String(n).padStart(2, "0");
}

function dayPartFromHm(h, m) {
  const mins = h * 60 + m;
  // day: 06:00–18:00
  if (mins >= 6 * 60 && mins < 18 * 60) return "day";
  return "night";
}

function captureClockFromFileName(fileName, fallbackDateStr) {
  const m = String(fileName || "").match(/_(\d{8})_(\d{6})_/);
  if (m) {
    const y = Number(m[1].slice(0, 4));
    const mo = Number(m[1].slice(4, 6));
    const d = Number(m[1].slice(6, 8));
    const hh = Number(m[2].slice(0, 2));
    const mm = Number(m[2].slice(2, 4));
    const ss = Number(m[2].slice(4, 6));
    return { y, mo, d, hh, mm, ss, source: "fileName" };
  }
  if (fallbackDateStr) {
    const d = new Date(fallbackDateStr);
    if (!Number.isNaN(d.getTime())) {
      return {
        y: d.getFullYear(),
        mo: d.getMonth() + 1,
        d: d.getDate(),
        hh: d.getHours(),
        mm: d.getMinutes(),
        ss: d.getSeconds(),
        source: "AddDate",
      };
    }
  }
  return null;
}

function loadPool(csvDir) {
  const wr = parseCsv(
    fs.readFileSync(path.join(csvDir, "WeighingRecords.csv"), "utf8"),
  );
  const links = parseCsv(
    fs.readFileSync(path.join(csvDir, "WeighingRecordAttachments.csv"), "utf8"),
  );
  const files = parseCsv(
    fs.readFileSync(path.join(csvDir, "AttachmentFiles.csv"), "utf8"),
  );

  const fileById = new Map(files.map((f) => [String(f.Id), f]));
  const wrById = new Map(wr.map((r) => [String(r.Id), r]));
  const prefer = new Set(["2", "5"]);
  const pool = [];

  for (const link of links) {
    const file = fileById.get(String(link.AttachmentFileId));
    const rec = wrById.get(String(link.WeighingRecordId));
    if (!file || !rec) continue;
    if (String(file.photoFound).toLowerCase() !== "true") continue;
    if (!file.ResolvedPhotoPath) continue;
    const plate = (rec.PlateNumber || "").trim();
    if (!plate) continue;
    const clock = captureClockFromFileName(file.FileName, file.AddDate || rec.AddDate);
    if (!clock) continue;
    const entry = {
      plate,
      photoPath: file.ResolvedPhotoPath,
      attachType: Number(file.AttachType || 0),
      captureClock: clock,
      dayPart: dayPartFromHm(clock.hh, clock.mm),
      preferred: prefer.has(String(file.AttachType)),
    };
    pool.push(entry);
  }

  const byPart = { day: [], night: [] };
  for (const e of pool) byPart[e.dayPart].push(e);
  // preferred first
  for (const k of Object.keys(byPart)) {
    byPart[k].sort((a, b) => Number(b.preferred) - Number(a.preferred));
  }
  return { pool, byPart, stats: { total: pool.length, day: byPart.day.length, night: byPart.night.length } };
}

function sampleTripWeights(rand, cfg) {
  for (let attempt = 0; attempt < 80; attempt++) {
    const net = round2(cfg.tripNetMin + rand() * (cfg.tripNetMax - cfg.tripNetMin));
    const tare = round2(cfg.tareMin + rand() * (cfg.tareMax - cfg.tareMin));
    const gross = round2(net + tare);
    if (gross >= cfg.grossMin && gross <= cfg.grossMax) {
      return { net, tare, gross };
    }
  }
  const net = round2((cfg.tripNetMin + cfg.tripNetMax) / 2);
  const tare = round2((cfg.tareMin + cfg.tareMax) / 2);
  return { net, tare, gross: round2(net + tare) };
}

function splitDayTons(T, days, rand, jitter) {
  const raw = days.map(() => 1 + (rand() * 2 - 1) * jitter);
  const sum = raw.reduce((a, b) => a + b, 0);
  const tons = raw.map((r) => round2((T * r) / sum));
  let drift = round2(T - tons.reduce((a, b) => a + b, 0));
  tons[tons.length - 1] = round2(tons[tons.length - 1] + drift);
  return tons;
}

function emitTripsForDayTon(t_d, rand, cfg) {
  const trips = [];
  let remain = round2(t_d);
  while (remain > cfg.tripNetMax + 1e-9) {
    let { net, tare, gross } = sampleTripWeights(rand, cfg);
    if (net > remain) {
      net = remain;
      gross = round2(net + tare);
    }
    trips.push({ net, tare, gross });
    remain = round2(remain - net);
  }
  if (remain > 0) {
    const tare = round2(cfg.tareMin + rand() * (cfg.tareMax - cfg.tareMin));
    const net = remain;
    trips.push({ net, tare, gross: round2(net + tare) });
  }
  return trips;
}

/** Main window hours: 6..16 full, plus 17:00-17:30 half */
function pickOutTime(year, month, day, rand, cfg, forceDayPart) {
  const outOfWindow = rand() < cfg.outOfWindowRate;
  let hh;
  let mm;
  let ss;

  if (outOfWindow) {
    if (rand() < 0.5) {
      // early 05:45-05:59
      hh = 5;
      mm = 45 + Math.floor(rand() * 15);
    } else {
      // late 17:31-17:45
      hh = 17;
      mm = 31 + Math.floor(rand() * 15);
    }
    ss = Math.floor(rand() * 60);
  } else {
    // weight hours 6-16 and 17 (half)
    const hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17];
    hh = hours[Math.floor(rand() * hours.length)];
    if (hh === 17) mm = Math.floor(rand() * 31); // 0-30
    else mm = Math.floor(rand() * 60);
    ss = Math.floor(rand() * 60);
  }

  let part = dayPartFromHm(hh, mm);
  // If forced dayPart mismatch, nudge into window
  if (forceDayPart && part !== forceDayPart) {
    if (forceDayPart === "day") {
      hh = 6 + Math.floor(rand() * 11);
      mm = Math.floor(rand() * 60);
      ss = Math.floor(rand() * 60);
    } else {
      hh = 19 + Math.floor(rand() * 4);
      mm = Math.floor(rand() * 60);
      ss = Math.floor(rand() * 60);
    }
    part = dayPartFromHm(hh, mm);
  }

  const outTime = `${year}-${pad2(month)}-${pad2(day)} ${pad2(hh)}:${pad2(mm)}:${pad2(ss)}`;
  return { outTime, hh, mm, ss, dayPart: part };
}

function pickPoolEntry(byPart, dayPart, hh, rand, proximityHours) {
  const list = byPart[dayPart] || [];
  if (!list.length) return null;
  const near = list.filter(
    (e) => Math.abs(e.captureClock.hh - hh) <= proximityHours,
  );
  const cand = near.length ? near : list;
  return cand[Math.floor(rand() * cand.length)];
}

function shortConsignee(name) {
  if (name.includes("腾满")) return "tengman";
  if (name.includes("三野")) return "sanye";
  if (name.includes("永武")) return "yongwu";
  if (name.includes("起陆")) return "qilu";
  if (name.includes("锦秋")) return "jinqiu";
  return "co";
}

function main() {
  const args = parseArgs(process.argv);
  if (!args.outDir || !args.seeds || !args.csvDir) {
    console.error(
      "Usage: node expand-january.mjs --outDir <dir> --seeds <yaml> --csvDir <dir> [--embedPhotos]",
    );
    process.exit(2);
  }

  const cfg = {
    year: 2026,
    month: 1,
    tripNetMin: 19,
    tripNetMax: 23,
    tareMin: 13,
    tareMax: 14.5,
    grossMin: 33,
    grossMax: 37,
    epsilon: 0.01,
    dayWeightJitter: 0.15,
    outOfWindowRate: 0.08,
    batchSize: 100,
    hourProximityHours: 2,
    seed: args.seed || 20260908,
    pointNumber: args.pointNumber || "",
    productNames: ["再生细骨料", "再生粉料"],
    embedPhotos: !!args.embedPhotos,
  };

  const outDir = path.resolve(args.outDir);
  const dryDir = path.join(outDir, "dry-run");
  const prepareDir = path.join(outDir, "prepare");
  fs.mkdirSync(dryDir, { recursive: true });
  fs.mkdirSync(prepareDir, { recursive: true });

  const seeds = parseSimpleYamlTotals(fs.readFileSync(args.seeds, "utf8"));
  cfg.productNames = seeds.productNames || cfg.productNames;
  cfg.year = seeds.year || cfg.year;

  console.log("[pool] loading...");
  const { byPart, stats: poolStats } = loadPool(args.csvDir);
  console.log(
    `[pool] total=${poolStats.total} day=${poolStats.day} night=${poolStats.night}`,
  );
  if (poolStats.total === 0) {
    throw new Error("Empty photo pool (photoFound=true). Run recycle-wenyixilu-export first.");
  }
  if (poolStats.day === 0) {
    throw new Error("No day-part pool entries; cannot bind business-hour trips.");
  }

  const rand = mulberry32(cfg.seed);
  const dim = daysInMonth(cfg.year, cfg.month);
  const days = Array.from({ length: dim }, (_, i) => i + 1);

  const allRecords = [];
  const manifestLines = [];
  const perConsignee = [];
  let dayPartMismatch = 0;
  let poolReuse = 0;

  for (const row of seeds.rows) {
    const T = row.months[cfg.month];
    if (T == null) throw new Error(`Missing month ${cfg.month} for ${row.consignee}`);

    const dayTons = splitDayTons(T, days, rand, cfg.dayWeightJitter);
    const trips = [];

    for (let di = 0; di < days.length; di++) {
      const day = days[di];
      const dayTripWeights = emitTripsForDayTon(dayTons[di], rand, cfg);
      for (const w of dayTripWeights) {
        // Prefer day pool (business hours)
        let ot = pickOutTime(cfg.year, cfg.month, day, rand, cfg, "day");
        let entry = pickPoolEntry(
          byPart,
          ot.dayPart,
          ot.hh,
          rand,
          cfg.hourProximityHours,
        );
        if (!entry) {
          // fallback any same dayPart then any
          entry =
            pickPoolEntry(byPart, "day", ot.hh, rand, 24) ||
            byPart.day[0] ||
            byPart.night[0];
          poolReuse++;
        }
        if (!entry) throw new Error("Pool exhausted unexpectedly");

        if (entry.dayPart !== ot.dayPart) {
          // realign outTime to entry dayPart
          ot = pickOutTime(cfg.year, cfg.month, day, rand, cfg, entry.dayPart);
          if (entry.dayPart !== ot.dayPart) dayPartMismatch++;
        }

        trips.push({
          consignee: row.consignee,
          ...w,
          outTime: ot.outTime,
          hh: ot.hh,
          dayPart: ot.dayPart,
          plate: entry.plate,
          photoPath: entry.photoPath,
          captureClock: entry.captureClock,
          poolDayPart: entry.dayPart,
        });
      }
    }

    // Assign fl- dataNo by day order; productName 1:1 alternate (Q4)
    trips.sort((a, b) => (a.outTime < b.outTime ? -1 : a.outTime > b.outTime ? 1 : 0));
    const daySeq = new Map();
    const records = [];
    const productCounts = { 再生细骨料: 0, 再生粉料: 0 };
    const productTons = { 再生细骨料: 0, 再生粉料: 0 };
    for (let ti = 0; ti < trips.length; ti++) {
      const t = trips[ti];
      const productName = cfg.productNames[ti % cfg.productNames.length];
      productCounts[productName] = (productCounts[productName] || 0) + 1;
      productTons[productName] = round2((productTons[productName] || 0) + t.net);

      const dayKey = t.outTime.slice(0, 10);
      const seq = (daySeq.get(dayKey) || 0) + 1;
      daySeq.set(dayKey, seq);
      const stamp = t.outTime.replace(/[-: ]/g, "").slice(0, 14);
      const dataNo = `fl-${stamp}-${String(seq).padStart(4, "0")}`;

      let outPhotos = "";
      if (cfg.embedPhotos) {
        try {
          outPhotos = fs.readFileSync(t.photoPath).toString("base64");
        } catch {
          outPhotos = "";
        }
      }

      const rec = {
        dataNo,
        dataStatus: 0,
        pointNumber: cfg.pointNumber || "<user-provided-after-dryRun>",
        carNo: t.plate,
        productName,
        netWeight: t.net,
        tareWeight: t.tare,
        grossWeight: t.gross,
        outTime: t.outTime,
        outPhotos,
        consignee: t.consignee,
      };
      records.push(rec);
      manifestLines.push(
        JSON.stringify({
          dataNo,
          carNo: t.plate,
          productName,
          photoPath: t.photoPath,
          captureClock: t.captureClock,
          outTime: t.outTime,
          dayPartOut: t.dayPart,
          dayPartPool: t.poolDayPart,
          dayPartAligned: t.dayPart === t.poolDayPart,
        }),
      );
    }

    const sumNet = round2(records.reduce((a, r) => a + r.netWeight, 0));
    const delta = round2(sumNet - T);
    const countA = productCounts["再生细骨料"] || 0;
    const countB = productCounts["再生粉料"] || 0;
    perConsignee.push({
      consignee: row.consignee,
      target: T,
      sumNet,
      delta,
      ok: Math.abs(delta) <= cfg.epsilon,
      tripCount: records.length,
      productCounts: { 再生细骨料: countA, 再生粉料: countB },
      productTons,
      productRatioOk: Math.abs(countA - countB) <= 1,
    });
    // write batches
    const slug = shortConsignee(row.consignee);
    for (let i = 0; i < records.length; i += cfg.batchSize) {
      const chunk = records.slice(i, i + cfg.batchSize);
      const part = String(Math.floor(i / cfg.batchSize)).padStart(3, "0");
      const file = path.join(
        dryDir,
        `${cfg.year}-${pad2(cfg.month)}-${slug}.part${part}.json`,
      );
      fs.writeFileSync(file, JSON.stringify(chunk, null, 2), "utf8");
    }

    allRecords.push(...records);
    console.log(
      `[expand] ${slug}: trips=${records.length} sumNet=${sumNet} target=${T} delta=${delta}`,
    );
  }

  fs.writeFileSync(
    path.join(outDir, "photo-manifest.jsonl"),
    manifestLines.join("\n") + "\n",
    "utf8",
  );

  const monthTarget = round2(perConsignee.reduce((a, x) => a + x.target, 0));
  const monthSum = round2(perConsignee.reduce((a, x) => a + x.sumNet, 0));
  const aligned = manifestLines.filter((l) => JSON.parse(l).dayPartAligned).length;
  const l0 = poolStats.total > 0 && seeds.rows.length === 5;
  const l1 = perConsignee.every((x) => x.ok) && Math.abs(monthSum - monthTarget) <= cfg.epsilon;
  const allowed = new Set(cfg.productNames);
  const l2 =
    allRecords.every(
      (r) => allowed.has(r.productName) && /^fl-\d{14}-\d{4}$/.test(r.dataNo),
    ) &&
    perConsignee.every((x) => x.productRatioOk) &&
    aligned === manifestLines.length;

  const summary = {
    graph: "sand-addbatch-2026-01",
    goal: "gov-sand-product-addbatch-2026-01",
    year: cfg.year,
    month: cfg.month,
    dryRun: true,
    embedPhotos: cfg.embedPhotos,
    seed: cfg.seed,
    poolStats,
    perConsignee,
    monthTarget,
    monthSum,
    tripCount: allRecords.length,
    dayPartAligned: aligned,
    dayPartTotal: manifestLines.length,
    dayPartMismatch,
    poolReuse,
    levels: {
      L0: l0 ? "pass" : "fail",
      L1: l1 ? "pass" : "fail",
      L2: l2 ? "pass" : "fail",
      L3: "pending-user",
    },
    message: "等待用户验收，尚未通过。",
  };
  fs.writeFileSync(
    path.join(outDir, "summary.json"),
    JSON.stringify(summary, null, 2),
    "utf8",
  );

  const report = [
    "# sand-addbatch-2026-01 report",
    "",
    `- month: ${cfg.year}-${pad2(cfg.month)}`,
    `- trips: ${allRecords.length}`,
    `- monthSum: ${monthSum} / target ${monthTarget}`,
    `- pool: ${poolStats.total} (day=${poolStats.day}, night=${poolStats.night})`,
    `- dayPart aligned: ${aligned}/${manifestLines.length}`,
    `- embedPhotos: ${cfg.embedPhotos}`,
    "",
    "## Per consignee",
    "",
    ...perConsignee.map(
      (x) =>
        `- ${x.consignee}: sum=${x.sumNet} target=${x.target} delta=${x.delta} trips=${x.tripCount} ok=${x.ok}`,
    ),
    "",
    "## Levels",
    "",
    `- L0: ${summary.levels.L0}`,
    `- L1: ${summary.levels.L1}`,
    `- L2: ${summary.levels.L2}`,
    `- L3: ${summary.levels.L3}`,
    "",
    "等待用户验收，尚未通过。",
    "",
  ].join("\n");
  fs.writeFileSync(path.join(outDir, "report.md"), report, "utf8");

  console.log(
    `[done] trips=${allRecords.length} L0=${summary.levels.L0} L1=${summary.levels.L1} L2=${summary.levels.L2}`,
  );
  if (!l0 || !l1 || !l2) process.exit(1);
}

main();
