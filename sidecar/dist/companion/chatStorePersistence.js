import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { defaultPersistedChatState } from "./chatStoreTypes.js";
export function loadChatStoreState() {
    const { stateFilePath } = resolveStateFilePath();
    if (!existsSync(stateFilePath))
        return defaultPersistedChatState;
    try {
        return { ...defaultPersistedChatState, ...JSON.parse(readFileSync(stateFilePath, "utf8")) };
    }
    catch {
        return defaultPersistedChatState;
    }
}
export function saveChatStoreState(state) {
    const { dataDir, stateFilePath } = resolveStateFilePath();
    mkdirSync(dataDir, { recursive: true });
    writeFileSync(stateFilePath, JSON.stringify(state, null, 2), "utf8");
}
function resolveStateFilePath() {
    const currentFile = fileURLToPath(import.meta.url);
    const currentDir = dirname(currentFile);
    const dataDir = join(currentDir, "..", "..", "data");
    return { dataDir, stateFilePath: join(dataDir, "companion-chat-state.json") };
}
