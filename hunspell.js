.pragma library

function parseOutput(output) {
    const result = { recognized: false, issues: [] };
    const lines = String(output || "").split(/\r?\n/);
    const suggestionLine = /^[&?]\s+(\S+)\s+\d+\s+\d+:\s*(.*)$/;
    const noSuggestionsLine = /^#\s+(\S+)\s+\d+(?:\s.*)?$/;

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        if (line.startsWith("@(#)") || /^[*+-]\s+/.test(line))
            result.recognized = true;

        const match = line.match(suggestionLine);
        if (match) {
            result.recognized = true;
            const suggestions = match[2].split(",").map(value => value.trim()).filter(Boolean);
            result.issues.push({ misspelled: match[1], suggestions: suggestions });
            continue;
        }

        const unknown = line.match(noSuggestionsLine);
        if (unknown) {
            result.recognized = true;
            result.issues.push({ misspelled: unknown[1], suggestions: [] });
        }
    }

    return result;
}
