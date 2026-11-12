/**
 * Experimental. Classify a MaterialClient startup log slice.
 * Usage: pnpm exec tsx scan-load-log.ts --log <file> --out <json> --completed <text> --failed <text>
 */
import { readFileSync, writeFileSync } from "node:fs";

function arg(name: string): string {
  const index = process.argv.indexOf(name);
  const value = index >= 0 ? process.argv[index + 1] : undefined;
  if (!value) throw new Error(`Missing argument ${name}`);
  return value;
}

const text = readFileSync(arg("--log"), "utf8");
const completedText = arg("--completed");
const failedText = arg("--failed");
const lines = text.split(/\r?\n/).filter((line) => line.length > 0);
const tagged = lines.filter((line) => line.includes("[ERR]") || line.includes("[FTL]"));
const ignoredWebHost = tagged.filter((line) => /\[ERR\] Web [Hh]ost 启动(失败|错误)/.test(line));
const errors = tagged.filter((line) => !ignoredWebHost.includes(line));
const migrationCompleted = text.includes(completedText);
const migrationFailed = text.includes(failedText);
const passed = migrationCompleted && !migrationFailed && errors.length === 0;

const summary = {
  graphId: "materialclient-working-db-load",
  result: passed ? "pass" : "fail",
  migrationCompleted,
  migrationFailed,
  errorCount: errors.length,
  ignoredWebHostCount: ignoredWebHost.length,
  ignoredWebHost,
  errors,
  observed: {
    P0: true,
    P1: lines.length > 0,
    P2: passed,
    P3: false,
  },
};

writeFileSync(arg("--out"), `${JSON.stringify(summary, null, 2)}\n`, "utf8");
console.log(JSON.stringify({ result: summary.result, errorCount: summary.errorCount, migrationCompleted, migrationFailed }));
process.exitCode = passed ? 0 : 1;
