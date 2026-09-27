pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property string previewScreen
    readonly property bool showPreview: previewScreen !== ""
    property string previewPath
    readonly property string current: actualCurrent
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear

    property var monitorPaths: ({})

    function monitorFileName(name: string): string {
        return name.replace(/[^a-zA-Z0-9\-_.]/g, "_");
    }

    function monitorStatePath(name: string): string {
        return `${Paths.state}/wallpaper/monitors/${monitorFileName(name)}.txt`;
    }

    function forMonitor(name: string): string {
        if (previewScreen && name === previewScreen)
            return previewPath;
        return monitorPaths[name] || actualCurrent;
    }

    function setMonitorPath(name: string, path: string): void {
        const next = Object.assign({}, monitorPaths);
        if (path)
            next[name] = path;
        else
            delete next[name];
        monitorPaths = next;
    }

    function setWallpaperFor(name: string, path: string): void {

        if (!name) {
            setWallpaper(path);
            return;
        }

        setMonitorPath(name, path);

        _setMonProc.name = name;
        _setMonProc.path = path;
        _setMonProc.running = true;
    }

    function clearMonitorWallpaper(name: string): void {
        setMonitorPath(name, "");
        Colours._clearMonitorData(name);
        _clearMonProc.name = name;
        _clearMonProc.running = true;
    }

    property string wallpaperFilter: "all"

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(monitor: string): void {

        if (!monitor) {
            for (const name of Object.keys(monitorPaths))
                clearMonitorWallpaper(name);
        }
        const cmd = ["caelestia", "wallpaper", "-r"];
        if (monitor)
            cmd.push("-m", monitor);
        if (!GlobalConfig.services.smartScheme)
            cmd.push("--no-smart");
        Quickshell.execDetached(cmd);
    }

    function setWallpaper(path: string): void {

        for (const name of Object.keys(monitorPaths))
            Colours._clearMonitorData(name);
        monitorPaths = {};
        actualCurrent = path;
        Quickshell.execDetached(["caelestia", "wallpaper", "-f", path, ...smartArg]);
    }

    function preview(screen: string, path: string): void {
        previewScreen = screen || "";
        previewPath = path;

        if (Colours.scheme === "dynamic")
            getPreviewColoursProc.running = true;
        else
            Colours.showPreview = true;
    }

    function stopPreview(): void {
        previewScreen = "";
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (!previewColourLock && pendingPreviewClear)
            Colours.showPreview = false;
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function getFor(monitor: string): string {
            return root.forMonitor(monitor);
        }

        function setFor(monitor: string, path: string): void {
            root.setWallpaperFor(monitor, path);
        }

        function clearFor(monitor: string): void {
            root.clearMonitorWallpaper(monitor);
        }

        function randomFor(monitor: string): void {
            root.setRandom(monitor);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope

            required property ShellScreen modelData

            FileView {
                id: monitorView

                path: root.monitorStatePath(monitorScope.modelData.name)
                watchChanges: true
                printErrors: false
                onFileChanged: reload()
                onLoaded: root.setMonitorPath(monitorScope.modelData.name, text().trim())
                onLoadFailed: {
                    root.setMonitorPath(monitorScope.modelData.name, "");

                    if (!monitorView.__touched) {
                        monitorView.__touched = true;
                        monitorViewTouch.running = true;
                    }
                }

                property bool __touched
            }

            // Create the file, then reload so the watcher attaches. Without the reload a
            // file created after startup (e.g. no monitors/ dir yet) is never watched.
            Process {
                id: monitorViewTouch

                command: ["sh", "-c", `mkdir -p "$(dirname "$1")" && touch "$1"`, "sh", monitorView.path]
                onExited: monitorView.reload()
            }
        }
    }

    FileView {
        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir

        filter: FileSystemModel.Files
        nameFilters: Images.validWallpaperExtensions.map(e => `*.${e}`)
    }

    Process {
        id: _setMonProc

        property string name: ""
        property string path: ""

        command: {
            if (!_setMonProc.path || !_setMonProc.name)
                return ["true"];
            return [
                "caelestia", "wallpaper",
                "-f", _setMonProc.path,
                "-m", _setMonProc.name,
                ...root.smartArg,
            ];
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (_setMonProc.name && text)
                    Colours._setMonitorData(_setMonProc.name, text);

                root.previewColourLock = false;
            }
        }
    }

    Process {
        id: _clearMonProc

        property string name: ""

        command: {
            if (!_clearMonProc.name)
                return ["true"];
            return [
                "truncate", "-s", "0",
                root.monitorStatePath(_clearMonProc.name),
                `${Paths.state}/wallpaper/monitors/${root.monitorFileName(_clearMonProc.name)}-scheme.json`,
            ];
        }
    }

    Process {
        id: getPreviewColoursProc

        command: ["caelestia", "wallpaper", "-p", root.previewPath, ...root.smartArg]
        stdout: StdioCollector {
            onStreamFinished: {

                if (!root.previewScreen)
                    return;
                Colours.load(text, true);
                Colours.showPreview = true;
            }
        }
    }
}
