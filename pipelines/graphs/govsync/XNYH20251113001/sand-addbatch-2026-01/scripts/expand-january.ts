/**
 * experimental — sand-addbatch-2026-01 (XNYH20251113001)
 * Expand Jan 2026 monthly tonnage → §2.2 addBatch **pending-POST JSON** (NO HTTP).
 *
 * pnpm exec tsx expand-january.ts --outDir <runDir> --seeds <yaml> --csvDir <pool>
 *   [--addresses <yaml>] [--pointNumber <id>] [--seed <n>]
 */
import fs from "node:fs";
import path from "node:path";

type DayPart = "day" | "night";

type CaptureClock = {
  y: number;
  mo: number;
  d: number;
  hh: number;
  mm: number;
  ss: number;
  source: string;
};

type PoolEntry = {
  plate: string;
  photoPath: string;
  attachType: number;
  captureClock: CaptureClock;
  dayPart: DayPart;
  preferred: boolean;
};

type TripRecord = {
  dataNo: string;
  dataStatus: number;
  pointNumber: string;
  carNo: string;
  productName: string;
  netWeight: number;
  tareWeight: number;
  grossWeight: number;
  outTime: string;
  outPhotos: null;
  outPhotosPath: string;
  consignee: string;
  consigneeAddress: string;
  receivingTime: string;
};

function parseArgs(argv: string[]) {
  const o: Record<string, string | number | undefined> = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--outDir") o.outDir = argv[++i];
    else if (a === "--seeds") o.seeds = argv[++i];
    else if (a === "--csvDir") o.csvDir = argv[++i];
    else if (a === "--addresses") o.addresses = argv[++i];
    else if (a === "--seed") o.seed = Number(argv[++i]);
    else if (a === "--pointNumber") o.pointNumber = argv[++i];
  }
  return o;
}

/** @param {number} seed */
function mulberry32(seed: number) {
  let t = seed >>> 0;
  return () => {
    t += 0x6d2b79f5;
    let r = Math.imul(t ^ (t >>> 15), 1 | t);
    r ^= r + Math.imul(r ^ (r >>> 7), 61 | r);
    return ((r ^ (r >>> 14)) >>> 0) / 4294967296;
  };
}

function round2(n: number) {
  return Math.round(n * 100) / 100;
}

function parseSimpleYamlTotals(text: string) {
  const yearMatch = text.match(/^year:\s*(\d+)/m);
  const year = yearMatch ? Number(yearMatch[1]) : 2026;
  const productNames = ["再生细骨料", "再生粉料"];
  const rows: { consignee: string; months: Record<number, number> }[] = [];
  const blockRe =
    /-\s*consignee:\s*(.+)\r?\n\s*months:\s*\{\s*([^}]+)\}/g;
  let m: RegExpExecArray | null;
  while ((m = blockRe.exec(text))) {
    const consignee = m[1].trim();
    const months: Record<number, number> = {};
    for (const part of m[2].split(",")) {
      const kv = part.trim().match(/(\d+)\s*:\s*([0-9.]+)/);
      if (kv) months[Number(kv[1])] = Number(kv[2]);
    }
    rows.push({ consignee, months });
  }
  return { year, productNames, rows };
}

function parseConsigneeAddresses(text: string): Map<string, string> {
  const map = new Map<string, string>();
  const blockRe =
    /-\s*consignee:\s*(.+)\r?\n\s*consigneeAddress:\s*(.+)/g;
  let m: RegExpExecArray | null;
  while ((m = blockRe.exec(text))) {
    map.set(m[1].trim(), m[2].trim());
  }
  return map;
}

function parseCsv(text: string) {
  const lines: string[][] = [];
  let i = 0;
  const s = text.replace(/^\uFEFF/, "");
  while (i < s.length) {
    const row: string[] = [];
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
  if (!lines.length) return [] as Record<string, string>[];
  const header = lines[0];
  return lines.slice(1).map((cols) => {
    const obj: Record<string, string> = {};
    for (let c = 0; c < header.length; c++) obj[header[c]] = cols[c] ?? "";
    return obj;
  });
}

function daysInMonth(year: number, month: number) {
  return new Date(year, month, 0).getDate();
}

function pad2(n: number) {
  return String(n).padStart(2, "0");
}

/** Q10: receivingTime = outTime + Uniform[1.5h, 2.5h] (90–150 minutes inclusive). */
function addReceivingTime(outTime: string, rand: () => number): string {
  const m = outTime.match(
    /^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/,
  );
  if (!m) throw new Error(`Bad outTime for receivingTime: ${outTime}`);
  const dt = new Date(
    Number(m[1]),
    Number(m[2]) - 1,
    Number(m[3]),
    Number(m[4]),
    Number(m[5]),
    Number(m[6]),
  );
  const deltaMin = 90 + Math.floor(rand() * 61); // 90..150 inclusive
  dt.setMinutes(dt.getMinutes() + deltaMin);
  return `${dt.getFullYear()}-${pad2(dt.getMonth() + 1)}-${pad2(dt.getDate())} ${pad2(dt.getHours())}:${pad2(dt.getMinutes())}:${pad2(dt.getSeconds())}`;
}

function receivingOffsetHours(outTime: string, receivingTime: string): number {
  const parse = (s: string) => {
    const m = s.match(/^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$/);
    if (!m) return NaN;
    return new Date(
      Number(m[1]),
      Number(m[2]) - 1,
      Number(m[3]),
      Number(m[4]),
      Number(m[5]),
      Number(m[6]),
    ).getTime();
  };
  return (parse(receivingTime) - parse(outTime)) / 3_600_000;
}

function dayPartFromHm(h: number, m: number): DayPart {
  const mins = h * 60 + m;
  if (mins >= 6 * 60 && mins < 18 * 60) return "day";
  return "night";
}

function captureClockFromFileName(
  fileName: string,
  fallbackDateStr: string | undefined,
): CaptureClock | null {
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

function loadPool(csvDir: string) {
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
  const pool: PoolEntry[] = [];

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
    const entry: PoolEntry = {
      plate,
      photoPath: file.ResolvedPhotoPath,
      attachType: Number(file.AttachType || 0),
      captureClock: clock,
      dayPart: dayPartFromHm(clock.hh, clock.mm),
      preferred: prefer.has(String(file.AttachType)),
    };
    pool.push(entry);
  }

  const byPart: Record<DayPart, PoolEntry[]> = { day: [], night: [] };
  for (const e of pool) byPart[e.dayPart].push(e);
  for (const k of Object.keys(byPart) as DayPart[]) {
    byPart[k].sort((a, b) => Number(b.preferred) - Number(a.preferred));
  }
  return { pool, byPart, stats: { total: pool.length, day: byPart.day.length, night: byPart.night.length } };
}

function sampleTripWeights(rand: () => number, cfg: Record<string, number>) {
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

function splitDayTons(T: number, days: number[], rand: () => number, jitter: number) {
  const raw = days.map(() => 1 + (rand() * 2 - 1) * jitter);
  const sum = raw.reduce((a, b) => a + b, 0);
  const tons = raw.map((r) => round2((T * r) / sum));
  const drift = round2(T - tons.reduce((a, b) => a + b, 0));
  tons[tons.length - 1] = round2(tons[tons.length - 1] + drift);
  return tons;
}

function emitTripsForDayTon(t_d: number, rand: () => number, cfg: Record<string, number>) {
  const trips: { net: number; tare: number; gross: number }[] = [];
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

function pickOutTime(
  year: number,
  month: number,
  day: number,
  rand: () => number,
  cfg: Record<string, number>,
  forceDayPart?: DayPart,
) {
  const outOfWindow = rand() < cfg.outOfWindowRate;
  let hh: number;
  let mm: number;
  let ss: number;

  if (outOfWindow) {
    if (rand() < 0.5) {
      hh = 5;
      mm = 45 + Math.floor(rand() * 15);
    } else {
      hh = 17;
      mm = 31 + Math.floor(rand() * 15);
    }
    ss = Math.floor(rand() * 60);
  } else {
    const hours = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17];
    hh = hours[Math.floor(rand() * hours.length)];
    if (hh === 17) mm = Math.floor(rand() * 31);
    else mm = Math.floor(rand() * 60);
    ss = Math.floor(rand() * 60);
  }

  let part = dayPartFromHm(hh, mm);
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

function pickPoolEntry(
  byPart: Record<DayPart, PoolEntry[]>,
  dayPart: DayPart,
  hh: number,
  rand: () => number,
  proximityHours: number,
) {
  const list = byPart[dayPart] || [];
  if (!list.length) return null;
  const near = list.filter(
    (e) => Math.abs(e.captureClock.hh - hh) <= proximityHours,
  );
  const cand = near.length ? near : list;
  return cand[Math.floor(rand() * cand.length)];
}

function shortConsignee(name: string) {
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
      "Usage: pnpm exec tsx expand-january.ts --outDir <dir> --seeds <yaml> --csvDir <dir> [--addresses <yaml>] [--pointNumber <id>]",
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
    seed: Number(args.seed) || 20260909,
    pointNumber: String(args.pointNumber || "XNYH20251113001"),
    productNames: ["再生细骨料", "再生粉料"],
  };
  const pointSlug = String(cfg.pointNumber).toLowerCase();

  const outDir = path.resolve(String(args.outDir));
  const jsonDir = path.join(outDir, "json");
  const ledgerDir = path.join(outDir, "ledgers");
  const prepareDir = path.join(outDir, "prepare");
  fs.mkdirSync(jsonDir, { recursive: true });
  fs.mkdirSync(ledgerDir, { recursive: true });
  fs.mkdirSync(prepareDir, { recursive: true });

  // HARD: this transform Graph never submits.
  const submitEnabled = false;

  const seeds = parseSimpleYamlTotals(fs.readFileSync(String(args.seeds), "utf8"));
  cfg.productNames = seeds.productNames || cfg.productNames;
  cfg.year = seeds.year || cfg.year;

  const addressesPath =
    (args.addresses && String(args.addresses)) ||
    path.join(path.dirname(String(args.seeds)), "consignee-addresses.yaml");
  if (!fs.existsSync(addressesPath)) {
    throw new Error(`Missing consignee addresses: ${addressesPath}`);
  }
  const addressByConsignee = parseConsigneeAddresses(
    fs.readFileSync(addressesPath, "utf8"),
  );
  if (addressByConsignee.size < 5) {
    throw new Error(
      `Expected ≥5 consignee addresses, got ${addressByConsignee.size} from ${addressesPath}`,
    );
  }

  console.log("[pool] loading...");
  const { byPart, stats: poolStats } = loadPool(String(args.csvDir));
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

  const allRecords: TripRecord[] = [];
  const ledgerLines: string[] = [];
  const manifestLines: string[] = [];
  const perConsignee: {
    consignee: string;
    target: number;
    sumNet: number;
    delta: number;
    ok: boolean;
    tripCount: number;
    productCounts: Record<string, number>;
    productTons: Record<string, number>;
    productRatioOk: boolean;
  }[] = [];
  let dayPartMismatch = 0;
  let poolReuse = 0;

  for (const row of seeds.rows) {
    const T = row.months[cfg.month];
    if (T == null) throw new Error(`Missing month ${cfg.month} for ${row.consignee}`);
    const consigneeAddress = addressByConsignee.get(row.consignee);
    if (!consigneeAddress) {
      throw new Error(`No consigneeAddress for consignee: ${row.consignee}`);
    }

    const dayTons = splitDayTons(T, days, rand, cfg.dayWeightJitter);
    const trips: {
      consignee: string;
      net: number;
      tare: number;
      gross: number;
      outTime: string;
      hh: number;
      dayPart: DayPart;
      plate: string;
      photoPath: string;
      captureClock: CaptureClock;
      poolDayPart: DayPart;
    }[] = [];

    for (let di = 0; di < days.length; di++) {
      const day = days[di];
      const dayTripWeights = emitTripsForDayTon(dayTons[di], rand, cfg);
      for (const w of dayTripWeights) {
        let ot = pickOutTime(cfg.year, cfg.month, day, rand, cfg, "day");
        let entry = pickPoolEntry(
          byPart,
          ot.dayPart,
          ot.hh,
          rand,
          cfg.hourProximityHours,
        );
        if (!entry) {
          entry =
            pickPoolEntry(byPart, "day", ot.hh, rand, 24) ||
            byPart.day[0] ||
            byPart.night[0];
          poolReuse++;
        }
        if (!entry) throw new Error("Pool exhausted unexpectedly");

        if (entry.dayPart !== ot.dayPart) {
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

    trips.sort((a, b) => (a.outTime < b.outTime ? -1 : a.outTime > b.outTime ? 1 : 0));
    const daySeq = new Map<string, number>();
    const records: TripRecord[] = [];
    const productCounts: Record<string, number> = { 再生细骨料: 0, 再生粉料: 0 };
    const productTons: Record<string, number> = { 再生细骨料: 0, 再生粉料: 0 };
    for (let ti = 0; ti < trips.length; ti++) {
      const t = trips[ti];
      const productName = cfg.productNames[ti % cfg.productNames.length];
      productCounts[productName] = (productCounts[productName] || 0) + 1;
      productTons[productName] = round2((productTons[productName] || 0) + t.net);

      const dayKey = t.outTime.slice(0, 10);
      const seq = (daySeq.get(dayKey) || 0) + 1;
      daySeq.set(dayKey, seq);
      const stamp = t.outTime.replace(/[-: ]/g, "").slice(0, 14);
      const dataNo = `fl-${pointSlug}-${stamp}-${String(seq).padStart(4, "0")}`;
      const receivingTime = addReceivingTime(t.outTime, rand);

      const rec: TripRecord = {
        dataNo,
        dataStatus: 0,
        pointNumber: cfg.pointNumber,
        carNo: t.plate,
        productName,
        netWeight: t.net,
        tareWeight: t.tare,
        grossWeight: t.gross,
        outTime: t.outTime,
        // Pending-POST review JSON: path for acceptance; embed base64 only in a submit Graph
        outPhotos: null,
        outPhotosPath: t.photoPath,
        consignee: t.consignee,
        consigneeAddress,
        receivingTime,
      };
      records.push(rec);
      ledgerLines.push(
        JSON.stringify({
          dataNo,
          consignee: t.consignee,
          consigneeAddress,
          outTime: t.outTime,
          receivingTime,
          productName,
          netWeight: t.net,
          carNo: t.plate,
          submitStatus: "pending-post",
        }),
      );
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
    const slug = shortConsignee(row.consignee);
    for (let i = 0; i < records.length; i += cfg.batchSize) {
      const chunk = records.slice(i, i + cfg.batchSize);
      const part = String(Math.floor(i / cfg.batchSize)).padStart(3, "0");
      const file = path.join(
        jsonDir,
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
    path.join(ledgerDir, "dataNo-ledger.jsonl"),
    ledgerLines.join("\n") + "\n",
    "utf8",
  );
  fs.writeFileSync(
    path.join(outDir, "photo-manifest.jsonl"),
    manifestLines.join("\n") + "\n",
    "utf8",
  );

  const submitMeta = {
    submitEnabled: false,
    note: "This Graph only writes pending-POST JSON + dataNo ledger. Do not POST from here.",
    method: "POST",
    baseUrl:
      "https://gzt.cgw.hangzhou.gov.cn/muckmanage/addmtd0p1q/api/zhztc-module-exapi",
    path: "/dataCenter/resourcePlace/productTransportRecord/v1/addBatch",
    pointNumber: cfg.pointNumber,
    dataNoPattern: `fl-${pointSlug}-{yyyyMMddHHmmss}-{seq:D4}`,
    productNames: cfg.productNames,
    year: cfg.year,
    month: cfg.month,
    tripCount: allRecords.length,
    ledger: "ledgers/dataNo-ledger.jsonl",
    outPhotos: "null in pending JSON; use outPhotosPath; embed base64 only in submit Graph",
    receivingTime: "Q10: outTime + Uniform[1.5h, 2.5h]",
    hmacHeaders: [
      "X-AKZTJG-HMAC-ACCESS-KEY",
      "X-AKZTJG-HMAC-ALGORITHM",
      "X-AKZTJG-HMAC-SIGNATURE",
      "X-AKZTJG-HMAC-DATE",
    ],
  };
  fs.writeFileSync(
    path.join(outDir, "submit-meta.json"),
    JSON.stringify(submitMeta, null, 2),
    "utf8",
  );

  const monthTarget = round2(perConsignee.reduce((a, x) => a + x.target, 0));
  const monthSum = round2(perConsignee.reduce((a, x) => a + x.sumNet, 0));
  const aligned = manifestLines.filter((l) => JSON.parse(l).dayPartAligned).length;
  const dataNoRe = new RegExp(
    `^fl-${pointSlug.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}-\\d{14}-\\d{4}$`,
  );
  const l0 =
    poolStats.total > 0 &&
    seeds.rows.length === 5 &&
    addressByConsignee.size >= 5;
  const l1 = perConsignee.every((x) => x.ok) && Math.abs(monthSum - monthTarget) <= cfg.epsilon;
  const allowed = new Set(cfg.productNames);
  const l2 =
    allRecords.every((r) => {
      const offsetH = receivingOffsetHours(r.outTime, r.receivingTime);
      return (
        allowed.has(r.productName) &&
        dataNoRe.test(r.dataNo) &&
        r.outPhotos === null &&
        !!r.outPhotosPath &&
        !!r.consigneeAddress &&
        addressByConsignee.get(r.consignee) === r.consigneeAddress &&
        !!r.receivingTime &&
        offsetH >= 1.5 - 1e-9 &&
        offsetH <= 2.5 + 1e-9
      );
    }) &&
    perConsignee.every((x) => x.productRatioOk) &&
    aligned === manifestLines.length &&
    ledgerLines.length === allRecords.length &&
    submitEnabled === false;

  const summary = {
    graph: "sand-addbatch-2026-01",
    goal: "gov-sand-product-addbatch-2026-01",
    site: "XNYH20251113001",
    year: cfg.year,
    month: cfg.month,
    submitEnabled: false,
    outputFormat: "json",
    socketEnd: "submit-params-json-ready",
    seed: cfg.seed,
    dataNoPattern: submitMeta.dataNoPattern,
    poolStats,
    perConsignee,
    monthTarget,
    monthSum,
    tripCount: allRecords.length,
    ledgerCount: ledgerLines.length,
    dayPartAligned: aligned,
    dayPartTotal: manifestLines.length,
    dayPartMismatch,
    poolReuse,
    levels: {
      L0: l0 ? "pass" : "fail",
      L1: l1 ? "pass" : "fail",
      L2: l2 ? "pass" : "fail",
      L3: "pending-user-params-review",
    },
    message: "等待用户验收待 POST JSON 参数，尚未通过。本图禁止 POST。",
  };
  fs.writeFileSync(
    path.join(outDir, "summary.json"),
    JSON.stringify(summary, null, 2),
    "utf8",
  );

  const report = [
    "# sand-addbatch-2026-01 report",
    "",
    `- submitEnabled: **false** (no POST)`,
    `- month: ${cfg.year}-${pad2(cfg.month)}`,
    `- pointNumber: ${cfg.pointNumber}`,
    `- dataNo: \`${submitMeta.dataNoPattern}\``,
    `- trips: ${allRecords.length}`,
    `- ledger: ${ledgerLines.length} rows`,
    `- monthSum: ${monthSum} / target ${monthTarget}`,
    `- pool: ${poolStats.total} (day=${poolStats.day}, night=${poolStats.night})`,
    `- dayPart aligned: ${aligned}/${manifestLines.length}`,
    `- output: json/ + ledgers/dataNo-ledger.jsonl + submit-meta.json`,
    "",
    "## Per consignee",
    "",
    ...perConsignee.map(
      (x) =>
        `- ${x.consignee}: sum=${x.sumNet} target=${x.target} delta=${x.delta} trips=${x.tripCount} ok=${x.ok} products=${JSON.stringify(x.productCounts)}`,
    ),
    "",
    "## Levels",
    "",
    `- L0: ${summary.levels.L0}`,
    `- L1: ${summary.levels.L1}`,
    `- L2: ${summary.levels.L2}`,
    `- L3: ${summary.levels.L3}`,
    "",
    "等待用户验收待 POST JSON 参数，尚未通过。本图禁止 POST。",
    "",
  ].join("\n");
  fs.writeFileSync(path.join(outDir, "report.md"), report, "utf8");

  console.log(
    `[done] submitEnabled=false trips=${allRecords.length} ledger=${ledgerLines.length} L0=${summary.levels.L0} L1=${summary.levels.L1} L2=${summary.levels.L2}`,
  );
  if (!l0 || !l1 || !l2) process.exit(1);
}

main();
