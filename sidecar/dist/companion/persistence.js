import { readStateFile, writeStateFile } from "./statePersistence.js";
const stateFileName = "companion-state.json";
const defaultState = {
    connectedDeviceId: null,
    devices: [],
};
export function loadCompanionState() {
    const parsed = readStateFile(stateFileName, defaultState);
    const devices = Array.isArray(parsed.devices)
        ? parsed.devices.filter((item) => item && typeof item.id === "string")
        : [];
    const connectedDeviceId = typeof parsed.connectedDeviceId === "string" ? parsed.connectedDeviceId : null;
    return {
        connectedDeviceId,
        devices,
    };
}
export function saveCompanionState(state) {
    const payload = {
        connectedDeviceId: state.connectedDeviceId,
        devices: state.devices,
    };
    writeStateFile(stateFileName, payload);
}
