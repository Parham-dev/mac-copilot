import { defaultPersistedChatState } from "./chatStoreTypes.js";
import { readStateFile, writeStateFile } from "./statePersistence.js";
const stateFileName = "companion-chat-state.json";
export function loadChatStoreState() {
    const parsed = readStateFile(stateFileName, defaultPersistedChatState);
    return { ...defaultPersistedChatState, ...parsed };
}
export function saveChatStoreState(state) {
    writeStateFile(stateFileName, state);
}
