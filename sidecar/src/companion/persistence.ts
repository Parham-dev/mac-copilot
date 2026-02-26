import { readStateFile, writeStateFile } from "./statePersistence.js";

interface CompanionPersistedState {
  connectedDeviceId: string | null;
  devices: Array<{
    id: string;
    name: string;
    publicKey: string;
    pairedAt: string;
    lastSeenAt: string;
  }>;
}

const stateFileName = "companion-state.json";

const defaultState: CompanionPersistedState = {
  connectedDeviceId: null,
  devices: [],
};

export function loadCompanionState(): CompanionPersistedState {
  const parsed = readStateFile<Partial<CompanionPersistedState>>(stateFileName, defaultState);

  const devices = Array.isArray(parsed.devices)
    ? parsed.devices.filter((item) => item && typeof item.id === "string")
    : [];

  const connectedDeviceId =
    typeof parsed.connectedDeviceId === "string" ? parsed.connectedDeviceId : null;

  return {
    connectedDeviceId,
    devices,
  };
}

export function saveCompanionState(state: CompanionPersistedState) {
  const payload: CompanionPersistedState = {
    connectedDeviceId: state.connectedDeviceId,
    devices: state.devices,
  };

  writeStateFile(stateFileName, payload);
}
