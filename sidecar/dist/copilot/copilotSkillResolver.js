import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, resolve } from "node:path";
export function resolveSkillSelection(args) {
    const baseSkillDirectories = normalizeList(args.baseSkillDirectories);
    const envDisabledSkills = normalizeList(args.envDisabledSkills);
    const selectedSkillNames = normalizeList(args.executionContext?.skillNames ?? null);
    if (!baseSkillDirectories) {
        return {
            skillDirectories: null,
            disabledSkills: envDisabledSkills,
            selectedSkillNames: selectedSkillNames ?? [],
            missingRequiredSkills: [],
            mode: "global",
        };
    }
    const agentID = normalizeValue(args.executionContext?.agentID ?? "");
    const scoped = agentID ? discoverScopedSkillDirectories(baseSkillDirectories, agentID) : null;
    const resolvedDirectories = scoped && scoped.length > 0 ? scoped : baseSkillDirectories;
    const mode = scoped && scoped.length > 0 ? "agent-scoped" : "global";
    if (!selectedSkillNames || selectedSkillNames.length === 0) {
        return {
            skillDirectories: resolvedDirectories,
            disabledSkills: envDisabledSkills,
            selectedSkillNames: [],
            missingRequiredSkills: [],
            mode,
        };
    }
    const discoveredSkillNames = discoverSkillNames(resolvedDirectories);
    const discoveredSet = new Set(discoveredSkillNames);
    const selectedSet = new Set(selectedSkillNames);
    const missingRequiredSkills = selectedSkillNames.filter((name) => !discoveredSet.has(name));
    const disabledByScope = discoveredSkillNames.filter((name) => !selectedSet.has(name));
    const disabledSkills = mergeLists(envDisabledSkills, disabledByScope);
    return {
        skillDirectories: resolvedDirectories,
        disabledSkills,
        selectedSkillNames,
        missingRequiredSkills,
        mode,
    };
}
function discoverScopedSkillDirectories(baseDirectories, agentID) {
    const candidates = [];
    for (const baseDirectory of baseDirectories) {
        const shared = resolve(baseDirectory, "shared");
        const scoped = resolve(baseDirectory, "agents", agentID);
        if (existsSync(shared)) {
            candidates.push(shared);
        }
        if (existsSync(scoped)) {
            candidates.push(scoped);
        }
    }
    return dedupeSorted(candidates);
}
function discoverSkillNames(skillDirectories) {
    const discovered = [];
    for (const parentDirectory of skillDirectories) {
        if (!existsSync(parentDirectory)) {
            continue;
        }
        let entries = [];
        try {
            entries = readdirSync(parentDirectory);
        }
        catch {
            continue;
        }
        for (const entryName of entries) {
            const skillDirectory = join(parentDirectory, entryName);
            const skillManifest = join(skillDirectory, "SKILL.md");
            if (!existsSync(skillManifest)) {
                continue;
            }
            discovered.push(readSkillName(skillManifest, entryName));
        }
    }
    return dedupeSorted(discovered.map((value) => normalizeValue(value)).filter((value) => value.length > 0));
}
function readSkillName(skillManifestPath, fallbackName) {
    try {
        const content = readFileSync(skillManifestPath, "utf8");
        const match = content.match(/^---\s*[\r\n]+([\s\S]*?)[\r\n]+---/);
        if (!match) {
            return fallbackName;
        }
        const frontmatter = match[1].split(/\r?\n/);
        for (const line of frontmatter) {
            const nameMatch = line.match(/^\s*name\s*:\s*(.+)\s*$/i);
            if (!nameMatch) {
                continue;
            }
            return nameMatch[1].trim().replace(/^['"]|['"]$/g, "") || fallbackName;
        }
        return fallbackName;
    }
    catch {
        return fallbackName;
    }
}
function normalizeList(value) {
    if (!Array.isArray(value)) {
        return null;
    }
    const normalized = dedupeSorted(value
        .map((entry) => normalizeValue(entry))
        .filter((entry) => entry.length > 0));
    return normalized.length > 0 ? normalized : null;
}
function mergeLists(lhs, rhs) {
    return normalizeList([...(lhs ?? []), ...(rhs ?? [])]);
}
function dedupeSorted(values) {
    return Array.from(new Set(values)).sort((lhs, rhs) => lhs.localeCompare(rhs));
}
function normalizeValue(value) {
    return String(value).trim();
}
