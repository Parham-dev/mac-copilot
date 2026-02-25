import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

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

const defaultState: CompanionPersistedState = {
  connectedDeviceId: null,
  devices: [],
};

function resolveStateFilePath() {
  const currentFile = fileURLToPath(import.meta.url);
  const currentDir = dirname(currentFile);
  const dataDir = join(currentDir, "..", "..", "data");
  return {
    dataDir,
    stateFilePath: join(dataDir, "companion-state.json"),
  };
}

export function loadCompanionState(): CompanionPersistedState {
  const { stateFilePath } = resolveStateFilePath();

  if (!existsSync(stateFilePath)) {
    return defaultState;
  }

  try {
    const raw = readFileSync(stateFilePath, "utf8");
    const parsed = JSON.parse(raw) as Partial<CompanionPersistedState>;

    const devices = Array.isArray(parsed.devices)
      ? parsed.devices.filter((item) => item && typeof item.id === "string")
      : [];

    const connectedDeviceId =
      typeof parsed.connectedDeviceId === "string" ? parsed.connectedDeviceId : null;

    return {
      connectedDeviceId,
      devices,
    };
  } catch {
    return defaultState;
  }
}

export function saveCompanionState(state: CompanionPersistedState) {
  const { dataDir, stateFilePath } = resolveStateFilePath();
  mkdirSync(dataDir, { recursive: true });

  const payload: CompanionPersistedState = {
    connectedDeviceId: state.connectedDeviceId,
    devices: state.devices,
  };

  writeFileSync(stateFilePath, JSON.stringify(payload, null, 2), "utf8");
}
