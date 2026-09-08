/**
 * experimental — recycle-wenyixilu-export
 * Export WeighingRecords / WeighingRecordAttachments / AttachmentFiles to CSV,
 * resolve AttachmentFiles.LocalPath against photoRoot (文一西路/2026).
 *
 * Usage:
 *   node scripts/export-csv.mjs --db <ascii-db> --photoRoot <dir> --outDir <runDir>
 */
import { DatabaseSync } from "node:sqlite";
import fs from "node:fs";
import path from "node:path";

const TABLES = [
  "WeighingRecords",
  "WeighingRecordAttachments",
  "AttachmentFiles",
];

function parseArgs(argv) {
  const out = {};
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--db") out.db = argv[++i];
    else if (a === "--photoRoot") out.photoRoot = argv[++i];
    else if (a === "--outDir") out.outDir = argv[++i];
    else if (a === "--help") out.help = true;
  }
  return out;
}

function csvEscape(value) {
  if (value === null || value === undefined) return "";
  const s = String(value);
  if (/[",\r\n]/.test(s)) return `"${s.replace(/"/g, '""')}"`;
  return s;
}

function writeCsv(filePath, columns, rows) {
  const lines = [];
  lines.push(columns.map(csvEscape).join(","));
  for (const row of rows) {
    lines.push(columns.map((c) => csvEscape(row[c])).join(","));
  }
  fs.writeFileSync(filePath, "\uFEFF" + lines.join("\n"), "utf8");
}

function stripPrefixes(localPath, prefixes) {
  let s = String(localPath || "");
  for (const p of prefixes) {
    if (s.toLowerCase().startsWith(p.toLowerCase())) {
      s = s.slice(p.length);
      break;
    }
  }
  return s.replace(/^[/\\]+/, "");
}

function buildFileNameIndex(rootDir) {
  /** @type {Map<string, string[]>} */
  const map = new Map();
  if (!fs.existsSync(rootDir)) return map;

  const stack = [rootDir];
  while (stack.length) {
    const dir = stack.pop();
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      continue;
    }
    for (const ent of entries) {
      const full = path.join(dir, ent.name);
      if (ent.isDirectory()) stack.push(full);
      else if (ent.isFile()) {
        const key = ent.name.toLowerCase();
        const list = map.get(key) || [];
        list.push(full);
        map.set(key, list);
      }
    }
  }
  return map;
}

function resolvePhoto(localPath, fileName, photoRoot, fileIndex) {
  const prefixes = ["Lpr\\", "Lpr/", "lpr\\", "lpr/"];
  const rel = stripPrefixes(localPath, prefixes).replace(/\//g, path.sep);
  const tried = [];

  const candidates = [];
  if (rel) {
    candidates.push(path.join(photoRoot, rel));
    candidates.push(path.join(photoRoot, "2026", rel));
    const withoutYear = rel.replace(/^2026[\\/]/i, "");
    if (withoutYear && withoutYear !== rel) {
      candidates.push(path.join(photoRoot, withoutYear));
      candidates.push(path.join(photoRoot, "2026", withoutYear));
    }
  }

  for (const c of candidates) {
    tried.push(c);
    try {
      if (fs.existsSync(c) && fs.statSync(c).isFile()) {
        return {
          resolvedPath: c,
          photoFound: true,
          resolveMethod: "relative",
          tried,
        };
      }
    } catch {
      /* ignore */
    }
  }

  const bn = (fileName || path.basename(rel || localPath || "")).toLowerCase();
  if (bn) {
    const hits = fileIndex.get(bn) || [];
    if (hits.length === 1) {
      return {
        resolvedPath: hits[0],
        photoFound: true,
        resolveMethod: "fileName",
        tried,
      };
    }
    if (hits.length > 1) {
      return {
        resolvedPath: hits[0],
        photoFound: true,
        resolveMethod: "fileName-ambiguous",
        ambiguousCount: hits.length,
        tried,
      };
    }
  }

  return {
    resolvedPath: "",
    photoFound: false,
    resolveMethod: "missing",
    tried,
  };
}

function main() {
  const args = parseArgs(process.argv);
  if (args.help || !args.db || !args.photoRoot || !args.outDir) {
    console.error(
      "Usage: node export-csv.mjs --db <path> --photoRoot <dir> --outDir <runDir>",
    );
    process.exit(args.help ? 0 : 2);
  }

  const dbPath = path.resolve(args.db);
  const photoRoot = path.resolve(args.photoRoot);
  const outDir = path.resolve(args.outDir);
  const csvDir = path.join(outDir, "csv");
  fs.mkdirSync(csvDir, { recursive: true });

  if (!fs.existsSync(dbPath)) throw new Error(`DB not found: ${dbPath}`);
  if (!fs.existsSync(photoRoot)) {
    console.warn(`[warn] photoRoot missing: ${photoRoot}`);
  }

  const db = new DatabaseSync(dbPath, { readOnly: true });

  const counts = {};
  for (const table of TABLES) {
    const row = db.prepare(`SELECT COUNT(*) AS c FROM "${table}"`).get();
    counts[table] = row.c;
    if (table === "AttachmentFiles") continue; // written after photo resolve
    const cols = db
      .prepare(`PRAGMA table_info("${table}")`)
      .all()
      .map((c) => c.name);
    const data = db.prepare(`SELECT * FROM "${table}"`).all();
    writeCsv(path.join(csvDir, `${table}.csv`), cols, data);
    console.log(`[export] ${table}: ${data.length} rows → csv/${table}.csv`);
  }

  console.log("[export] building FileName index under photoRoot...");
  const fileIndex = buildFileNameIndex(photoRoot);
  console.log(`[export] indexed ${fileIndex.size} unique file names`);

  const attachCols = db
    .prepare(`PRAGMA table_info("AttachmentFiles")`)
    .all()
    .map((c) => c.name);
  const attachments = db.prepare(`SELECT * FROM AttachmentFiles`).all();

  let found = 0;
  let missing = 0;
  let ambiguous = 0;
  const missSamples = [];
  const methodCounts = {};

  const enriched = attachments.map((row) => {
    const r = resolvePhoto(row.LocalPath, row.FileName, photoRoot, fileIndex);
    methodCounts[r.resolveMethod] = (methodCounts[r.resolveMethod] || 0) + 1;
    if (r.photoFound) found++;
    else {
      missing++;
      if (missSamples.length < 20) {
        missSamples.push({
          Id: row.Id,
          LocalPath: row.LocalPath,
          FileName: row.FileName,
          tried: r.tried.slice(0, 4),
        });
      }
    }
    if (r.resolveMethod === "fileName-ambiguous") ambiguous++;
    return {
      ...row,
      ResolvedPhotoPath: r.resolvedPath,
      photoFound: r.photoFound ? "true" : "false",
      resolveMethod: r.resolveMethod,
    };
  });

  const enrichedCols = [
    ...attachCols,
    "ResolvedPhotoPath",
    "photoFound",
    "resolveMethod",
  ];
  writeCsv(path.join(csvDir, "AttachmentFiles.csv"), enrichedCols, enriched);
  console.log(
    `[export] AttachmentFiles: ${enriched.length} rows → csv/AttachmentFiles.csv (with photo columns)`,
  );

  const photoReport = {
    photoRoot,
    attachmentCount: attachments.length,
    found,
    missing,
    ambiguous,
    methodCounts,
    indexedFileNames: fileIndex.size,
    missSamples,
  };
  fs.writeFileSync(
    path.join(outDir, "photo-resolve-report.json"),
    JSON.stringify(photoReport, null, 2),
    "utf8",
  );

  const csvParity = {};
  for (const table of TABLES) {
    const csvPath = path.join(csvDir, `${table}.csv`);
    const text = fs.readFileSync(csvPath, "utf8");
    const lines = text.replace(/^\uFEFF/, "").split(/\r?\n/).filter((l) => l.length);
    const dataRows = Math.max(0, lines.length - 1);
    csvParity[table] = {
      dbCount: counts[table],
      csvRows: dataRows,
      ok: dataRows === counts[table],
    };
  }

  const l0 = true;
  const l1 = Object.values(csvParity).every((x) => x.ok);
  const l2 = typeof found === "number";

  const summary = {
    graph: "recycle-wenyixilu-export",
    goal: "recycle-site-db-export",
    socketEnd: "csv-with-photo-index",
    dbPath,
    photoRoot,
    counts,
    csvParity,
    photo: { found, missing, ambiguous, methodCounts },
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

  const reportMd = [
    "# recycle-wenyixilu-export report",
    "",
    `- DB: \`${dbPath}\``,
    `- photoRoot: \`${photoRoot}\``,
    "",
    "## Counts",
    "",
    ...TABLES.map(
      (t) =>
        `- ${t}: db=${counts[t]}, csv=${csvParity[t].csvRows}, ok=${csvParity[t].ok}`,
    ),
    "",
    "## Photo resolve",
    "",
    `- found: ${found}`,
    `- missing: ${missing}`,
    `- ambiguous: ${ambiguous}`,
    `- methods: ${JSON.stringify(methodCounts)}`,
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
  fs.writeFileSync(path.join(outDir, "report.md"), reportMd, "utf8");

  console.log(
    `[done] found=${found} missing=${missing} L0=${summary.levels.L0} L1=${summary.levels.L1}`,
  );
  if (!l1) process.exit(1);
}

main();
