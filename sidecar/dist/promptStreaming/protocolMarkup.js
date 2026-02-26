export const protocolTagNames = ["function_calls", "system_notification", "invoke", "parameter"];
const openingTagPattern = new RegExp(`<\\s*(${protocolTagNames.join("|")})\\b[^>]*>`, "i");
export const protocolMarkerPattern = /<\s*\/?\s*(function_calls|system_notification|invoke|parameter)\b[^>]*>/i;
export class ProtocolMarkupFilter {
    activeTag = null;
    tail = "";
    maxTailLength = 256;
    process(chunk) {
        let text = this.tail + chunk;
        this.tail = "";
        let output = "";
        while (text.length > 0) {
            if (this.activeTag) {
                const closeMatch = findClosingTag(text, this.activeTag);
                if (!closeMatch) {
                    const keepLength = Math.min(text.length, this.maxTailLength);
                    this.tail = text.slice(-keepLength);
                    return output;
                }
                text = text.slice(closeMatch.end);
                this.activeTag = null;
                continue;
            }
            const openMatch = findOpeningTag(text);
            if (!openMatch) {
                const safeLength = Math.max(0, text.length - this.maxTailLength);
                output += text.slice(0, safeLength);
                this.tail = text.slice(safeLength);
                return sanitizeInlineProtocolTags(output);
            }
            output += text.slice(0, openMatch.start);
            text = text.slice(openMatch.end);
            this.activeTag = openMatch.tagName;
        }
        return sanitizeInlineProtocolTags(output);
    }
    flush() {
        if (this.activeTag) {
            this.activeTag = null;
            this.tail = "";
            return "";
        }
        const remaining = sanitizeInlineProtocolTags(this.tail);
        this.tail = "";
        return remaining;
    }
}
function findOpeningTag(text) {
    const match = openingTagPattern.exec(text);
    if (!match || typeof match.index !== "number") {
        return null;
    }
    return {
        start: match.index,
        end: match.index + match[0].length,
        tagName: String(match[1]).toLowerCase(),
    };
}
function findClosingTag(text, tagName) {
    const escapedTagName = tagName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    const pattern = new RegExp(`<\\s*\\/\\s*${escapedTagName}\\s*>`, "i");
    const match = pattern.exec(text);
    if (!match || typeof match.index !== "number") {
        return null;
    }
    return {
        start: match.index,
        end: match.index + match[0].length,
    };
}
function sanitizeInlineProtocolTags(text) {
    return protocolTagNames.reduce((acc, tagName) => {
        const escapedTagName = tagName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
        return acc
            .replace(new RegExp(`<\\s*${escapedTagName}\\b[^>]*>`, "gi"), "")
            .replace(new RegExp(`<\\s*\\/\\s*${escapedTagName}\\s*>`, "gi"), "");
    }, text);
}
