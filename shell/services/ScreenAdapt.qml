pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property int referenceShortEdge: 1080
    readonly property int referenceLongEdge: 1920

    function logicalWidth(screen: ShellScreen): real {
        return screen ? screen.width : referenceLongEdge;
    }

    function logicalHeight(screen: ShellScreen): real {
        return screen ? screen.height : referenceShortEdge;
    }

    function shortEdge(screen: ShellScreen): real {
        return Math.min(logicalWidth(screen), logicalHeight(screen));
    }

    function longEdge(screen: ShellScreen): real {
        return Math.max(logicalWidth(screen), logicalHeight(screen));
    }

    function isPortrait(screen: ShellScreen): bool {
        return logicalHeight(screen) > logicalWidth(screen);
    }

    function isUltrawide(screen: ShellScreen): bool {
        return logicalWidth(screen) / Math.max(1, logicalHeight(screen)) >= 2.1;
    }

    function sizeClass(screen: ShellScreen): string {
        const s = shortEdge(screen);
        if (s < 900)
            return "compact";
        if (s >= 1400)
            return "large";
        return "normal";
    }

    function isCompact(screen: ShellScreen): bool {
        return sizeClass(screen) === "compact";
    }

    function uiScale(screen: ShellScreen): real {
        const raw = shortEdge(screen) / referenceShortEdge;

        const eased = Math.pow(raw, 0.45);
        return Math.max(0.8, Math.min(1.35, eased));
    }

    function maxPanelWidth(screen: ShellScreen): real {
        const w = logicalWidth(screen);
        if (isUltrawide(screen))
            return Math.min(w * 0.5, 1400);
        if (isPortrait(screen))
            return w * 0.94;
        if (isCompact(screen))
            return w * 0.9;
        return w * 0.8;
    }

    function maxPanelHeight(screen: ShellScreen): real {
        const h = logicalHeight(screen);
        if (isPortrait(screen))
            return h * 0.75;
        return h * 0.88;
    }

    function barScale(screen: ShellScreen): real {
        if (isPortrait(screen))
            return 0.9;
        const s = shortEdge(screen);
        if (s < 900)
            return 0.9;
        if (s >= 1400)
            return 1.12;
        return 1;
    }

    function fitScale(screen: ShellScreen, contentWidth: real, contentHeight: real): real {
        let s = 1;
        if (contentWidth > 0)
            s = Math.min(s, maxPanelWidth(screen) / contentWidth);
        if (contentHeight > 0)
            s = Math.min(s, maxPanelHeight(screen) / contentHeight);

        return Math.max(0.5, Math.min(1, s));
    }
}
