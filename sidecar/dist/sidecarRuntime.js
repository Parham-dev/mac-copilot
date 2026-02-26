import { existsSync } from "node:fs";
import { networkInterfaces } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
export async function isHealthySidecarAlreadyRunning(portNumber) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 800);
    try {
        const response = await fetch(`http://127.0.0.1:${portNumber}/health`, {
            method: "GET",
            signal: controller.signal,
            headers: {
                "Cache-Control": "no-cache",
            },
        });
        if (!response.ok) {
            return false;
        }
        const payload = (await response.json());
        return payload?.ok === true && payload?.service === "copilotforge-sidecar";
    }
    catch {
        return false;
    }
    finally {
        clearTimeout(timeout);
    }
}
export async function buildDoctorReport() {
    const sqliteSupport = await supportsNodeSqlite();
    const sdkPath = resolveSDKPath();
    const sdkPresent = existsSync(sdkPath);
    return {
        ok: sqliteSupport && sdkPresent,
        service: "copilotforge-sidecar",
        nodeVersion: process.version,
        nodeExecPath: process.execPath,
        sqliteSupport,
        sdkPath,
        sdkPresent,
    };
}
export function resolvedStartupURLs(hostValue, portValue) {
    const normalizedHost = hostValue.trim().toLowerCase();
    if (normalizedHost !== "0.0.0.0" && normalizedHost !== "::") {
        return [`http://${hostValue}:${portValue}`];
    }
    const urls = new Set();
    urls.add(`http://127.0.0.1:${portValue}`);
    urls.add(`http://localhost:${portValue}`);
    const interfaces = networkInterfaces();
    for (const candidates of Object.values(interfaces)) {
        if (!candidates) {
            continue;
        }
        for (const candidate of candidates) {
            if (!candidate || candidate.internal) {
                continue;
            }
            if (candidate.family === "IPv4") {
                urls.add(`http://${candidate.address}:${portValue}`);
            }
        }
    }
    return Array.from(urls).sort((left, right) => left.localeCompare(right));
}
async function supportsNodeSqlite() {
    try {
        await import("node:sqlite");
        return true;
    }
    catch {
        return false;
    }
}
function resolveSDKPath() {
    const currentFile = fileURLToPath(import.meta.url);
    const currentDir = dirname(currentFile);
    const candidates = [
        join(currentDir, "node_modules", "@github", "copilot-sdk"),
        join(currentDir, "..", "node_modules", "@github", "copilot-sdk"),
    ];
    for (const candidate of candidates) {
        if (existsSync(candidate)) {
            return candidate;
        }
    }
    return candidates[0];
}
