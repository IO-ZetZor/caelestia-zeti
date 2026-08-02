pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    readonly property string configPath: `${Paths.config}/live-wallpaper.json`

    property bool enabled: true

    property bool muted: true
    property real volume: 0

    property bool pauseWhenObscured: true

    property bool pauseWhenHidden: true
    property real playbackRate: 1

    property int fadeDuration: 0

    function isVideo(path: string): bool {
        return !!path && Images.isValidVideoByName(path);
    }

    function fileUrl(path: string): string {
        if (!path)
            return "";
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function apply(data: var): void {
        if (!data || typeof data !== "object")
            return;
        if (typeof data.enabled === "boolean")
            root.enabled = data.enabled;
        if (typeof data.muted === "boolean")
            root.muted = data.muted;
        if (typeof data.volume === "number")
            root.volume = data.volume;
        if (typeof data.pauseWhenObscured === "boolean")
            root.pauseWhenObscured = data.pauseWhenObscured;
        if (typeof data.pauseWhenHidden === "boolean")
            root.pauseWhenHidden = data.pauseWhenHidden;
        if (typeof data.playbackRate === "number" && data.playbackRate > 0)
            root.playbackRate = data.playbackRate;
        if (typeof data.fadeDuration === "number" && data.fadeDuration >= 0)
            root.fadeDuration = data.fadeDuration;
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
                console.warn("LiveWallpaper: invalid live-wallpaper.json:", e);
            }
        }
    }
}
