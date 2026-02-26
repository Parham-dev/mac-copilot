import { defaultPersistedChatState, type PersistedChatState } from "./chatStoreTypes.js";
import { readStateFile, writeStateFile } from "./statePersistence.js";

const stateFileName = "companion-chat-state.json";

export function loadChatStoreState(): PersistedChatState {
  const parsed = readStateFile<Partial<PersistedChatState>>(stateFileName, defaultPersistedChatState);
  return { ...defaultPersistedChatState, ...parsed };
}

export function saveChatStoreState(state: PersistedChatState) {
  writeStateFile(stateFileName, state);
}
