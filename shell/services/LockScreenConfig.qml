pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    readonly property string configPath: `${Paths.config}/lock-screen.json`

    property bool showWeather: true
    property bool showMedia: true
    property bool showFetch: true
    property bool showResources: true
    property bool showProfilePic: true
    property bool showDate: true

    property var shellCommands: []

    property string lockNote: ""

    function apply(data: var): void {
        if (!data || typeof data !== "object")
            return;

        if (typeof data.showWeather === "boolean")
            root.showWeather = data.showWeather;
        if (typeof data.showMedia === "boolean")
            root.showMedia = data.showMedia;
        if (typeof data.showFetch === "boolean")
            root.showFetch = data.showFetch;
        if (typeof data.showResources === "boolean")
            root.showResources = data.showResources;
        if (typeof data.showProfilePic === "boolean")
            root.showProfilePic = data.showProfilePic;
        if (typeof data.showDate === "boolean")
            root.showDate = data.showDate;

        if (Array.isArray(data.shellCommands))
            root.shellCommands = data.shellCommands.filter(c => c && typeof c === "object").map(c => ({
                        label: typeof c.label === "string" ? c.label : "",
                        command: typeof c.command === "string" ? c.command : ""
                    }));
        if (typeof data.lockNote === "string")
            root.lockNote = data.lockNote;
    }

    function save(): void {
        const data = {
            showWeather: root.showWeather,
            showMedia: root.showMedia,
            showFetch: root.showFetch,
            showResources: root.showResources,
            showProfilePic: root.showProfilePic,
            showDate: root.showDate,
            shellCommands: root.shellCommands,
            lockNote: root.lockNote
        };
        const json = JSON.stringify(data, null, 2);
        const tmp = `${root.configPath}.tmp.${Date.now()}`;

        Quickshell.execDetached([
            "sh", "-c",
            `mkdir -p "$(dirname "$3")" && printf '%s' "$1" > "$2" && mv "$2" "$3"`,
            "sh", json, tmp, root.configPath
        ]);
    }

    FileView {
        path: root.configPath
        watchChanges: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: {
            try {
                root.apply(JSON.parse(text()));
            } catch (e) {
                console.warn("LockScreenConfig: invalid lock-screen.json:", e);
            }
        }
    }
}
