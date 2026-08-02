pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.services
import qs.utils

Singleton {
    id: root

    property bool showPreview
    property string scheme
    property string flavour
    readonly property bool light: showPreview ? previewLight : currentLight
    property bool currentLight
    property bool previewLight
    readonly property M3Palette palette: showPreview ? preview : current
    readonly property M3TPalette tPalette: M3TPalette {}
    readonly property M3Palette current: M3Palette {}
    readonly property M3Palette preview: M3Palette {}
    readonly property Transparency transparency: Transparency {}
    readonly property alias wallLuminance: analyser.luminance

    property bool cooldownPending
    property real lastBaseTransparency

    function getLuminance(c: color): real {
        if (c.r == 0 && c.g == 0 && c.b == 0)
            return 0;
        return Math.sqrt(0.299 * (c.r ** 2) + 0.587 * (c.g ** 2) + 0.114 * (c.b ** 2));
    }

    function baseFor(isLight: bool): real {
        return Math.max(0, Math.min(1, Tokens.transparency.base - (isLight ? 0.1 : 0)));
    }

    function alterColourFor(c: color, a: real, layer: int, isLight: bool, lum: real): color {
        const luminance = getLuminance(c);

        const offset = (!isLight || layer == 1 ? 1 : -layer / 2) * (isLight ? 0.2 : 0.3) * (1 - baseFor(isLight)) * (1 + lum * (isLight ? (layer == 1 ? 3 : 1) : 2.5));
        const scale = (luminance + offset) / luminance;
        const r = Math.max(0, Math.min(1, c.r * scale));
        const g = Math.max(0, Math.min(1, c.g * scale));
        const b = Math.max(0, Math.min(1, c.b * scale));

        return Qt.rgba(r, g, b, a);
    }

    function layerFor(c: color, layer: var, isLight: bool, lum: real): color {
        if (!transparency.enabled)
            return c;

        return layer === 0 ? Qt.alpha(c, baseFor(isLight)) : alterColourFor(c, transparency.layers, layer ?? 1, isLight, lum);
    }

    function alterColour(c: color, a: real, layer: int): color {
        return alterColourFor(c, a, layer, light, wallLuminance);
    }

    function layer(c: color, layer: var): color {
        return layerFor(c, layer, light, wallLuminance);
    }

    function on(c: color): color {
        if (c.hslLightness < 0.5)
            return Qt.hsla(c.hslHue, c.hslSaturation, 0.9, 1);
        return Qt.hsla(c.hslHue, c.hslSaturation, 0.1, 1);
    }

    function load(data: string, isPreview: bool): void {
        const colours = isPreview ? preview : current;
        const scheme = JSON.parse(data);

        if (!isPreview) {
            root.scheme = scheme.name;
            flavour = scheme.flavour;
            currentLight = scheme.mode === "light";
        } else {
            previewLight = scheme.mode === "light";
        }

        for (const [name, colour] of Object.entries(scheme.colours)) {
            const propName = name.startsWith("term") ? name : `m3${name}`;
            if (colours.hasOwnProperty(propName))
                colours[propName] = `#${colour}`;
        }
    }

    function setMode(mode: string): void {
        Quickshell.execDetached(["caelestia", "scheme", "set", "--notify", "-m", mode]);
    }

    function reloadHyprRules(): void {
        let rule, trEnabled;
        if (Hypr.usingLua) {
            rule = `eval hl.layer_rule({ match = { namespace = "caelestia-drawers" }, %1 = %2 })`;
            trEnabled = transparency.enabled;
        } else {
            rule = "keyword layerrule %1 %2, match:namespace caelestia-drawers";
            trEnabled = transparency.enabled ? 1 : 0;
        }
        Hypr.extras.batchMessage([rule.arg("blur").arg(trEnabled), rule.arg("ignore_alpha").arg(Math.max(0, transparency.base - 0.03))]);
    }

    function requestReloadHyprRules(): void {
        if (cooldownTimer.running) {
            root.cooldownPending = true;
        } else {
            root.reloadHyprRules();
            cooldownTimer.restart();
        }
    }

    Component.onCompleted: root.requestReloadHyprRules()

    Connections {
        function onConfigReloaded(): void {
            root.reloadHyprRules();
        }

        target: Hypr
    }

    property var _monitorColourData: ({})

    property var _monitorColourCache: ({})

    property var _screenColours: ({})

    function p(screen: string): var {

        return _screenColours[screen]?.palette ?? current;
    }

    function tp(screen: string): var {
        return _screenColours[screen]?.tPalette ?? tPalette;
    }

    function isLight(screen: string): bool {
        const sc = _screenColours[screen];
        return sc ? sc.isLight : currentLight;
    }

    function layerOn(screen: string, c: color, lay: var): color {
        const sc = _screenColours[screen];
        if (!sc)
            return layer(c, lay);
        return layerFor(c, lay, sc.isLight, sc.lum);
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: scColoursScope

            required property ShellScreen modelData

            ScreenColours {
                id: screenColours

                screen: scColoursScope.modelData.name

                Component.onCompleted: {
                    const next = Object.assign({}, root._screenColours);
                    next[screenColours.screen] = screenColours;
                    root._screenColours = next;
                }
                Component.onDestruction: {
                    const next = Object.assign({}, root._screenColours);
                    delete next[screenColours.screen];
                    root._screenColours = next;
                }
            }
        }
    }

    function forMonitor(name: string): var {
        if (!name)
            return null;

        const cached = _monitorColourCache[name];
        if (cached)
            return cached;

        const data = _monitorColourData[name];
        if (!data?.colours)
            return null;

        const pal = {};
        for (const [k, v] of Object.entries(data.colours))
            pal[k.startsWith("term") ? k : `m3${k}`] = `#${v}`;

        const cacheNext = Object.assign({}, _monitorColourCache);
        cacheNext[name] = pal;
        _monitorColourCache = cacheNext;
        return pal;
    }

    function _setMonitorData(name: string, json: string): void {

        if (!json || !json.trim()) {
            _clearMonitorData(name);
            return;
        }
        try {
            const parsed = JSON.parse(json);

            const next = Object.assign({}, _monitorColourData);
            if (parsed?.colours)
                next[name] = parsed;
            else
                delete next[name];
            _monitorColourData = next;

            const cacheNext = Object.assign({}, _monitorColourCache);
            delete cacheNext[name];
            _monitorColourCache = cacheNext;
        } catch (e) {
            console.warn("Colours: invalid per-monitor scheme for", name);
        }
    }

    function _clearMonitorData(name: string): void {
        const next = Object.assign({}, _monitorColourData);
        delete next[name];
        _monitorColourData = next;

        const cacheNext = Object.assign({}, _monitorColourCache);
        delete cacheNext[name];
        _monitorColourCache = cacheNext;
    }

    Variants {
        model: Quickshell.screens

        Scope {
            required property ShellScreen modelData

            FileView {
                id: schemeView

                path: `${Paths.state}/wallpaper/monitors/${Wallpapers.monitorFileName(modelData.name)}-scheme.json`
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: root._setMonitorData(modelData.name, text())
                onLoadFailed: {
                    root._clearMonitorData(modelData.name);
                    if (!schemeView.__touched) {
                        schemeView.__touched = true;
                        Quickshell.execDetached(["sh", "-c", `mkdir -p "$(dirname "$1")" && touch "$1"`, "sh", schemeView.path]);
                    }
                }

                property bool __touched
            }
        }
    }

    FileView {
        path: `${Paths.state}/scheme.json`
        watchChanges: true
        onFileChanged: reload()
        onLoaded: root.load(text(), false)
    }

    ImageAnalyser {
        id: analyser

        source: Wallpapers.current
    }

    Timer {
        id: cooldownTimer

        interval: 30
        onTriggered: {
            if (root.cooldownPending) {
                root.cooldownPending = false;
                root.reloadHyprRules();
                restart();
            }
        }
    }

    Timer {
        id: cAnimCompleteTimer

        interval: Tokens.anim.durations.expressiveSlowEffects
        onTriggered: root.requestReloadHyprRules()
    }

    component ScreenColours: QtObject {
        id: sc

        required property string screen

        readonly property var data: root._monitorColourData[screen] ?? null

        readonly property bool isPreview: root.showPreview && screen === Wallpapers.previewScreen

        readonly property bool hasOwn: !!data?.colours

        readonly property M3Palette palette: isPreview ? root.preview : hasOwn ? own : root.current
        readonly property bool isLight: isPreview ? root.previewLight : hasOwn ? data.mode === "light" : root.currentLight

        readonly property real lum: analyser.luminance

        readonly property ImageAnalyser analyser: ImageAnalyser {
            source: Wallpapers.forMonitor(sc.screen)
        }

        readonly property M3Palette own: M3Palette {}

        readonly property M3TPalette tPalette: M3TPalette {
            src: sc.palette
            isLight: sc.isLight
            lum: sc.lum
        }

        function _sync(): void {
            if (!hasOwn)
                return;
            for (const [name, colour] of Object.entries(data.colours)) {
                const prop = name.startsWith("term") ? name : `m3${name}`;
                if (own.hasOwnProperty(prop))
                    own[prop] = `#${colour}`;
            }
        }

        onDataChanged: _sync()
        Component.onCompleted: _sync()
    }

    component Transparency: QtObject {
        readonly property bool enabled: Tokens.transparency.enabled
        readonly property real base: Math.max(0, Math.min(1, Tokens.transparency.base - (root.light ? 0.1 : 0)))
        readonly property real layers: Math.max(0, Math.min(1, Tokens.transparency.layers))

        onEnabledChanged: {
            if (enabled)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
        }
        onBaseChanged: {
            if (root.lastBaseTransparency > base)
                root.requestReloadHyprRules();
            else
                cAnimCompleteTimer.start();
            root.lastBaseTransparency = base;
        }
    }

    component M3TPalette: QtObject {

        property M3Palette src: root.palette
        property bool isLight: root.light
        property real lum: root.wallLuminance

        readonly property color m3primary_paletteKeyColor: root.layerFor(src.m3primary_paletteKeyColor, 1, isLight, lum)
        readonly property color m3secondary_paletteKeyColor: root.layerFor(src.m3secondary_paletteKeyColor, 1, isLight, lum)
        readonly property color m3tertiary_paletteKeyColor: root.layerFor(src.m3tertiary_paletteKeyColor, 1, isLight, lum)
        readonly property color m3neutral_paletteKeyColor: root.layerFor(src.m3neutral_paletteKeyColor, 1, isLight, lum)
        readonly property color m3neutral_variant_paletteKeyColor: root.layerFor(src.m3neutral_variant_paletteKeyColor, 1, isLight, lum)
        readonly property color m3background: root.layerFor(src.m3background, 0, isLight, lum)
        readonly property color m3onBackground: root.layerFor(src.m3onBackground, 1, isLight, lum)
        readonly property color m3surface: root.layerFor(src.m3surface, 0, isLight, lum)
        readonly property color m3surfaceDim: root.layerFor(src.m3surfaceDim, 0, isLight, lum)
        readonly property color m3surfaceBright: root.layerFor(src.m3surfaceBright, 0, isLight, lum)
        readonly property color m3surfaceContainerLowest: root.layerFor(src.m3surfaceContainerLowest, 1, isLight, lum)
        readonly property color m3surfaceContainerLow: root.layerFor(src.m3surfaceContainerLow, 1, isLight, lum)
        readonly property color m3surfaceContainer: root.layerFor(src.m3surfaceContainer, 1, isLight, lum)
        readonly property color m3surfaceContainerHigh: root.layerFor(src.m3surfaceContainerHigh, 1, isLight, lum)
        readonly property color m3surfaceContainerHighest: root.layerFor(src.m3surfaceContainerHighest, 1, isLight, lum)
        readonly property color m3onSurface: root.layerFor(src.m3onSurface, 1, isLight, lum)
        readonly property color m3surfaceVariant: root.layerFor(src.m3surfaceVariant, 0, isLight, lum)
        readonly property color m3onSurfaceVariant: root.layerFor(src.m3onSurfaceVariant, 1, isLight, lum)
        readonly property color m3inverseSurface: root.layerFor(src.m3inverseSurface, 0, isLight, lum)
        readonly property color m3inverseOnSurface: root.layerFor(src.m3inverseOnSurface, 1, isLight, lum)
        readonly property color m3outline: root.layerFor(src.m3outline, 1, isLight, lum)
        readonly property color m3outlineVariant: root.layerFor(src.m3outlineVariant, 1, isLight, lum)
        readonly property color m3shadow: root.layerFor(src.m3shadow, 1, isLight, lum)
        readonly property color m3scrim: root.layerFor(src.m3scrim, 1, isLight, lum)
        readonly property color m3surfaceTint: root.layerFor(src.m3surfaceTint, 1, isLight, lum)
        readonly property color m3primary: root.layerFor(src.m3primary, 1, isLight, lum)
        readonly property color m3onPrimary: root.layerFor(src.m3onPrimary, 1, isLight, lum)
        readonly property color m3primaryContainer: root.layerFor(src.m3primaryContainer, 1, isLight, lum)
        readonly property color m3onPrimaryContainer: root.layerFor(src.m3onPrimaryContainer, 1, isLight, lum)
        readonly property color m3inversePrimary: root.layerFor(src.m3inversePrimary, 1, isLight, lum)
        readonly property color m3secondary: root.layerFor(src.m3secondary, 1, isLight, lum)
        readonly property color m3onSecondary: root.layerFor(src.m3onSecondary, 1, isLight, lum)
        readonly property color m3secondaryContainer: root.layerFor(src.m3secondaryContainer, 1, isLight, lum)
        readonly property color m3onSecondaryContainer: root.layerFor(src.m3onSecondaryContainer, 1, isLight, lum)
        readonly property color m3tertiary: root.layerFor(src.m3tertiary, 1, isLight, lum)
        readonly property color m3onTertiary: root.layerFor(src.m3onTertiary, 1, isLight, lum)
        readonly property color m3tertiaryContainer: root.layerFor(src.m3tertiaryContainer, 1, isLight, lum)
        readonly property color m3onTertiaryContainer: root.layerFor(src.m3onTertiaryContainer, 1, isLight, lum)
        readonly property color m3error: root.layerFor(src.m3error, 1, isLight, lum)
        readonly property color m3onError: root.layerFor(src.m3onError, 1, isLight, lum)
        readonly property color m3errorContainer: root.layerFor(src.m3errorContainer, 1, isLight, lum)
        readonly property color m3onErrorContainer: root.layerFor(src.m3onErrorContainer, 1, isLight, lum)
        readonly property color m3success: root.layerFor(src.m3success, 1, isLight, lum)
        readonly property color m3onSuccess: root.layerFor(src.m3onSuccess, 1, isLight, lum)
        readonly property color m3successContainer: root.layerFor(src.m3successContainer, 1, isLight, lum)
        readonly property color m3onSuccessContainer: root.layerFor(src.m3onSuccessContainer, 1, isLight, lum)
        readonly property color m3primaryFixed: root.layerFor(src.m3primaryFixed, 1, isLight, lum)
        readonly property color m3primaryFixedDim: root.layerFor(src.m3primaryFixedDim, 1, isLight, lum)
        readonly property color m3onPrimaryFixed: root.layerFor(src.m3onPrimaryFixed, 1, isLight, lum)
        readonly property color m3onPrimaryFixedVariant: root.layerFor(src.m3onPrimaryFixedVariant, 1, isLight, lum)
        readonly property color m3secondaryFixed: root.layerFor(src.m3secondaryFixed, 1, isLight, lum)
        readonly property color m3secondaryFixedDim: root.layerFor(src.m3secondaryFixedDim, 1, isLight, lum)
        readonly property color m3onSecondaryFixed: root.layerFor(src.m3onSecondaryFixed, 1, isLight, lum)
        readonly property color m3onSecondaryFixedVariant: root.layerFor(src.m3onSecondaryFixedVariant, 1, isLight, lum)
        readonly property color m3tertiaryFixed: root.layerFor(src.m3tertiaryFixed, 1, isLight, lum)
        readonly property color m3tertiaryFixedDim: root.layerFor(src.m3tertiaryFixedDim, 1, isLight, lum)
        readonly property color m3onTertiaryFixed: root.layerFor(src.m3onTertiaryFixed, 1, isLight, lum)
        readonly property color m3onTertiaryFixedVariant: root.layerFor(src.m3onTertiaryFixedVariant, 1, isLight, lum)
    }

    component M3Palette: QtObject {
        property color m3primary_paletteKeyColor: "#a8627b"
        property color m3secondary_paletteKeyColor: "#8e6f78"
        property color m3tertiary_paletteKeyColor: "#986e4c"
        property color m3neutral_paletteKeyColor: "#807477"
        property color m3neutral_variant_paletteKeyColor: "#837377"
        property color m3background: "#191114"
        property color m3onBackground: "#efdfe2"
        property color m3surface: "#191114"
        property color m3surfaceDim: "#191114"
        property color m3surfaceBright: "#403739"
        property color m3surfaceContainerLowest: "#130c0e"
        property color m3surfaceContainerLow: "#22191c"
        property color m3surfaceContainer: "#261d20"
        property color m3surfaceContainerHigh: "#31282a"
        property color m3surfaceContainerHighest: "#3c3235"
        property color m3onSurface: "#efdfe2"
        property color m3surfaceVariant: "#514347"
        property color m3onSurfaceVariant: "#d5c2c6"
        property color m3inverseSurface: "#efdfe2"
        property color m3inverseOnSurface: "#372e30"
        property color m3outline: "#9e8c91"
        property color m3outlineVariant: "#514347"
        property color m3shadow: "#000000"
        property color m3scrim: "#000000"
        property color m3surfaceTint: "#ffb0ca"
        property color m3primary: "#ffb0ca"
        property color m3onPrimary: "#541d34"
        property color m3primaryContainer: "#6f334a"
        property color m3onPrimaryContainer: "#ffd9e3"
        property color m3inversePrimary: "#8b4a62"
        property color m3secondary: "#e2bdc7"
        property color m3onSecondary: "#422932"
        property color m3secondaryContainer: "#5a3f48"
        property color m3onSecondaryContainer: "#ffd9e3"
        property color m3tertiary: "#f0bc95"
        property color m3onTertiary: "#48290c"
        property color m3tertiaryContainer: "#b58763"
        property color m3onTertiaryContainer: "#000000"
        property color m3error: "#ffb4ab"
        property color m3onError: "#690005"
        property color m3errorContainer: "#93000a"
        property color m3onErrorContainer: "#ffdad6"
        property color m3success: "#B5CCBA"
        property color m3onSuccess: "#213528"
        property color m3successContainer: "#374B3E"
        property color m3onSuccessContainer: "#D1E9D6"
        property color m3primaryFixed: "#ffd9e3"
        property color m3primaryFixedDim: "#ffb0ca"
        property color m3onPrimaryFixed: "#39071f"
        property color m3onPrimaryFixedVariant: "#6f334a"
        property color m3secondaryFixed: "#ffd9e3"
        property color m3secondaryFixedDim: "#e2bdc7"
        property color m3onSecondaryFixed: "#2b151d"
        property color m3onSecondaryFixedVariant: "#5a3f48"
        property color m3tertiaryFixed: "#ffdcc3"
        property color m3tertiaryFixedDim: "#f0bc95"
        property color m3onTertiaryFixed: "#2f1500"
        property color m3onTertiaryFixedVariant: "#623f21"
        property color term0: "#353434"
        property color term1: "#ff4c8a"
        property color term2: "#ffbbb7"
        property color term3: "#ffdedf"
        property color term4: "#b3a2d5"
        property color term5: "#e98fb0"
        property color term6: "#ffba93"
        property color term7: "#eed1d2"
        property color term8: "#b39e9e"
        property color term9: "#ff80a3"
        property color term10: "#ffd3d0"
        property color term11: "#fff1f0"
        property color term12: "#dcbc93"
        property color term13: "#f9a8c2"
        property color term14: "#ffd1c0"
        property color term15: "#ffffff"
    }
}
