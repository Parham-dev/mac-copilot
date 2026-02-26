import { copyFileSync, existsSync, mkdirSync, readFileSync, unlinkSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
function resolveDataDir() {
    const currentFile = fileURLToPath(import.meta.url);
    const currentDir = dirname(currentFile);
    return join(currentDir, "..", "..", "data");
}
function resolveStateFilePath(fileName) {
    const dataDir = resolveDataDir();
    return {
        dataDir,
        stateFilePath: join(dataDir, fileName),
    };
}
export function readStateFile(fileName, fallback) {
    const { stateFilePath } = resolveStateFilePath(fileName);
    if (!existsSync(stateFilePath)) {
        return fallback;
    }
    try {
        return JSON.parse(readFileSync(stateFilePath, "utf8"));
    }
    catch (error) {
        const backupPath = `${stateFilePath}.corrupt.${Date.now()}`;
        try {
            copyFileSync(stateFilePath, backupPath);
            unlinkSync(stateFilePath);
            console.error("[CopilotForge][Companion] state file was corrupt; backed up and reset", JSON.stringify({
                fileName,
                path: stateFilePath,
                backupPath,
                error: String(error),
            }));
        }
        catch (backupError) {
            console.error("[CopilotForge][Companion] failed to back up corrupt state file", JSON.stringify({
                fileName,
                path: stateFilePath,
                backupPath,
                error: String(backupError),
            }));
        }
        return fallback;
    }
}
export function writeStateFile(fileName, state) {
    const { dataDir, stateFilePath } = resolveStateFilePath(fileName);
    mkdirSync(dataDir, { recursive: true });
    writeFileSync(stateFilePath, JSON.stringify(state, null, 2), "utf8");
}
