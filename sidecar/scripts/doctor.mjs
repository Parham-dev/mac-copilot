import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = dirname(dirname(fileURLToPath(import.meta.url)));
const sdkPath = join(rootDir, "node_modules", "@github", "copilot-sdk");

const report = {
  ok: true,
  nodeVersion: process.version,
  nodeExecPath: process.execPath,
  sqliteSupport: false,
  sdkPath,
  sdkPresent: existsSync(sdkPath),
};

try {
  await import("node:sqlite");
  report.sqliteSupport = true;
} catch {
  report.sqliteSupport = false;
}

report.ok = report.sqliteSupport && report.sdkPresent;

console.log(JSON.stringify(report, null, 2));

if (!report.ok) {
  process.exit(1);
}
