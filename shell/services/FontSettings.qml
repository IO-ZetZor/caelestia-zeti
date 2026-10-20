pragma Singleton

import QtQuick
import Quickshell
import Caelestia.Config
import Caelestia.I18n

Singleton {
    id: root

    // All installed font families, sorted for the picker. Qt.fontFamilies() is
    // not reactive, but the set only changes when fonts are installed.
    readonly property var families: {
        const list = Qt.fontFamilies();
        list.sort((a, b) => a.localeCompare(b));
        return list;
    }

    // The font role the picker is currently editing: "sans", "mono", "clock"
    // or "workspaces".
    property string selectingRole: "sans"

    function roleLabel(role: string): string {
        switch (role) {
        case "mono":
            return Tr.tr("Monospace font");
        case "clock":
            return Tr.tr("Clock font");
        case "workspaces":
            return Tr.tr("Workspace font");
        default:
            return Tr.tr("Interface font");
        }
    }

    function roleDescription(role: string): string {
        switch (role) {
        case "mono":
            return Tr.tr("Used for code and other monospaced text");
        case "clock":
            return Tr.tr("Used for the clock on the desktop and dashboard");
        case "workspaces":
            return Tr.tr("Used for workspace labels in the bar");
        default:
            return Tr.tr("Used for most text in the shell");
        }
    }

    function _familiesFor(role: string): var {
        const font = GlobalConfig.appearance.font;
        switch (role) {
        case "mono":
            return [font.mono.family];
        case "clock":
            return [font.clock];
        case "workspaces":
            return [font.workspaces];
        default:
            return [font.headline.family, font.title.family, font.body.family, font.label.family];
        }
    }

    // The selected family, or "" when the interface styles use different
    // families (or inherit the built-in default).
    function familyFor(role: string): string {
        const families = _familiesFor(role);
        const first = families[0] ?? "";
        return families.every(f => f === first) ? first : "";
    }

    function familySubtext(role: string): string {
        const families = _familiesFor(role);
        const first = families[0] ?? "";
        if (families.every(f => f === first))
            return first || Tr.tr("Default");
        return Tr.tr("Mixed");
    }

    function setFamily(role: string, family: string): void {
        const font = GlobalConfig.appearance.font;
        switch (role) {
        case "mono":
            font.mono.family = family;
            break;
        case "clock":
            font.clock = family;
            break;
        case "workspaces":
            font.workspaces = family;
            break;
        default:
            font.headline.family = family;
            font.title.family = family;
            font.body.family = family;
            font.label.family = family;
            break;
        }
    }
}
