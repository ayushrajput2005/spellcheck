import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services
import "hunspell.js" as Hunspell

QtObject {
    id: root

    property var pluginService: null
    property string pluginId: "spellChecker"
    property string trigger: "sp:"
    property string lookupQuery: ""
    property int requestSerial: 0
    property bool lookupPending: false
    property string lookupError: ""
    property var currentResults: []
    property var lookupDebounce: Timer {
        interval: 100
        repeat: false
        onTriggered: root.startLookup(root.lookupQuery, root.requestSerial)
    }
    property var spellProcessComponent: Component {
        Process {
            id: spellProcess

            property string queryText: ""
            property int requestToken: 0
            property var outputLines: []
            property string errorOutput: ""

            command: [
                "sh",
                "-c",
                "printf '%s\\n' \"$1\" | hunspell -a",
                "spell-checker",
                queryText
            ]

            stdout: SplitParser {
                onRead: line => spellProcess.outputLines.push(line)
            }

            stderr: SplitParser {
                onRead: line => spellProcess.errorOutput += line + "\n"
            }

            onExited: exitCode => {
                root.completeLookup(queryText, requestToken, exitCode,
                                    outputLines.join("\n"), errorOutput);
                destroy();
            }
        }
    }

    signal itemsChanged

    Component.onCompleted: loadSettings()

    onPluginServiceChanged: {
        if (pluginService)
            loadSettings();
    }

    function loadSettings() {
        if (!pluginService)
            return;
        trigger = pluginService.loadPluginData(pluginId, "trigger", "sp:");
    }

    function statusItem(name, comment) {
        return {
            name: name,
            icon: "material:spellcheck",
            comment: comment,
            action: "",
            categories: ["Spell Checker"]
        };
    }

    function getItems(query) {
        const term = String(query || "").trim();
        const queryChanged = term !== lookupQuery;
        if (queryChanged) {
            lookupQuery = term;
            requestSerial++;
            currentResults = [];
            lookupError = "";
            lookupPending = false;
            lookupDebounce.stop();
        }

        if (!term)
            return [];
        if (term.length > 128)
            return [statusItem("Text is too long", "Spell Checker accepts up to 128 characters.")];
        if (/[\r\n]/.test(term))
            return [statusItem("Enter one line of text", "Newlines are not supported.")];

        if (queryChanged) {
            lookupPending = true;
            lookupDebounce.restart();
        }

        if (lookupPending)
            return [statusItem("Checking spelling…", "Using the local Hunspell dictionary.")];
        if (lookupError)
            return [statusItem("Spell check unavailable", lookupError)];
        return currentResults;
    }

    function startLookup(term, serial) {
        const process = spellProcessComponent.createObject(root, {
            queryText: term,
            requestToken: serial
        });
        if (!process)
            return;
        process.running = true;
    }

    function completeLookup(term, serial, exitCode, output, errorOutput) {
        if (serial !== requestSerial || term !== lookupQuery)
            return;

        lookupPending = false;
        if (exitCode !== 0) {
            const details = String(errorOutput || "").trim();
            lookupError = details
                ? details + " Install Hunspell and a dictionary (for example, hunspell-en-us)."
                : "Hunspell exited with status " + exitCode
                    + ". Install Hunspell and a dictionary (for example, hunspell-en-us).";
            refreshLauncher();
            return;
        }

        const parsed = Hunspell.parseOutput(output);
        if (!parsed.recognized) {
            lookupError = "Hunspell returned no usable output. Confirm that a dictionary is installed.";
            refreshLauncher();
            return;
        }

        const seen = {};
        const results = [];
        for (let i = 0; i < parsed.issues.length && results.length < 10; i++) {
            const issue = parsed.issues[i];
            for (let j = 0; j < issue.suggestions.length && results.length < 10; j++) {
                const suggestion = issue.suggestions[j];
                const key = suggestion.toLocaleLowerCase();
                if (seen[key])
                    continue;
                seen[key] = true;
                results.push({
                    name: suggestion,
                    icon: "material:spellcheck",
                    comment: "Correction for “" + issue.misspelled + "”",
                    action: "copy:" + suggestion,
                    categories: ["Spell Checker"]
                });
            }
        }

        if (results.length > 0) {
            currentResults = results;
        } else if (parsed.issues.length > 0) {
            currentResults = [statusItem(
                "No suggestions found",
                "Hunspell has no dictionary suggestions for “" + parsed.issues[0].misspelled + "”."
            )];
        } else {
            currentResults = [{
                name: term,
                icon: "material:spellcheck",
                comment: "No spelling changes suggested",
                action: "copy:" + term,
                categories: ["Spell Checker"]
            }];
        }
        refreshLauncher();
    }

    function refreshLauncher() {
        itemsChanged();
        if (pluginService)
            pluginService.requestLauncherUpdate(pluginId);
    }

    function clipboardCommand(text) {
        return [
            "sh",
            "-c",
            "if command -v dms >/dev/null 2>&1; then "
                + "printf '%s' \"$1\" | setsid dms cl copy; "
                + "elif command -v wl-copy >/dev/null 2>&1; then "
                + "printf '%s' \"$1\" | wl-copy; "
                + "else echo 'Neither dms nor wl-copy is available' >&2; exit 127; fi",
            "spell-checker",
            text
        ];
    }

    function executeItem(item) {
        if (!item?.action || !item.action.startsWith("copy:"))
            return;
        const correctedText = item.action.substring(5);
        Quickshell.execDetached(clipboardCommand(correctedText));
        ToastService?.showInfo("Copied “" + correctedText + "” to clipboard");
    }

    function getPasteText(item) {
        if (!item?.action || !item.action.startsWith("copy:"))
            return null;
        return item.action.substring(5);
    }

    function getPasteArgs(item) {
        const correctedText = getPasteText(item);
        return correctedText ? clipboardCommand(correctedText) : null;
    }

    onTriggerChanged: {
        if (!pluginService)
            return;
        pluginService.savePluginData(pluginId, "trigger", trigger);
        itemsChanged();
    }

}
