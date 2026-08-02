pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Components
import Caelestia.Config
import Caelestia.Models
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Wallpapers")
    isSubPage: true

    property string targetMonitor: ""

    readonly property bool _isGlobal: root.targetMonitor === ""

    function _apply(path: string): void {
        if (root._isGlobal)
            Wallpapers.setWallpaper(path);
        else
            Wallpapers.setWallpaperFor(root.targetMonitor, path);
        root.nState.closeSubPage();
    }

    function _applyRandom(): void {
        Wallpapers.setRandom(root.targetMonitor);
        root.nState.closeSubPage();
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small

            IconTextButton {
                id: browseBtn
                icon: "photo_library"
                text: qsTr("Browse")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                onClicked: browseDialog.open()

                FileDialog {
                    id: browseDialog
                    title: qsTr("Select a wallpaper")
                    filterLabel: qsTr("Image and video files")
                    filters: Images.validWallpaperExtensions
                    onAccepted: path => root._apply(path)
                }
            }

            IconTextButton {
                id: randomBtn
                icon: "shuffle"
                text: qsTr("Random")
                font: Tokens.font.body.large
                isRound: true
                shapeMorph: true
                horizontalPadding: Tokens.padding.extraLarge
                verticalPadding: Tokens.padding.medium
                type: IconTextButton.Tonal
                onClicked: root._applyRandom()
            }

            Item { Layout.fillWidth: true }

            Row {
                id: monitorPills
                spacing: Tokens.spacing.extraSmall
                Layout.alignment: Qt.AlignVCenter

                MonitorPill {
                    label: qsTr("All")
                    active: root._isGlobal
                    onClicked: root.targetMonitor = ""
                }

                Repeater {
                    model: Quickshell.screens

                    MonitorPill {
                        id: pill
                        required property ShellScreen modelData

                        label: pill.modelData.name
                        active: root.targetMonitor === pill.modelData.name
                        onClicked: root.targetMonitor = pill.modelData.name
                    }
                }
            }
        }

        WallItem {
            id: featuredWall

            readonly property string featuredPath: Quickshell.shellPath("assets/wallpaper.webp")

            imgHeight: Math.round(width * 0.3)
            radius: Tokens.rounding.extraLarge
            path: featuredPath
            text: qsTr("Featured wallpaper")
            fillLabel: false
            onClicked: root._apply(featuredWall.featuredPath)
        }

        Row {
            Layout.topMargin: Tokens.spacing.medium
            Layout.alignment: Qt.AlignHCenter
            spacing: Tokens.spacing.small

            Repeater {
                model: [
                    { label: qsTr("All"),    value: "all" },
                    { label: qsTr("Static"), value: "static" },
                    { label: qsTr("Live"),   value: "live" },
                ]

                Item {
                    id: pill

                    required property var modelData

                    readonly property bool isActive: Wallpapers.wallpaperFilter === pill.modelData.value

                    implicitWidth: pillLabel.implicitWidth + Tokens.padding.medium * 2
                    implicitHeight: pillLabel.implicitHeight + Tokens.padding.small * 2

                    StyledRect {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        color: pill.isActive ? Colours.p(Tokens.screen).m3primary : Colours.tp(Tokens.screen).m3surfaceContainer
                        Behavior on color { CAnim {} }
                    }

                    StyledText {
                        id: pillLabel
                        anchors.centerIn: parent
                        text: pill.modelData.label
                        color: pill.isActive ? Colours.p(Tokens.screen).m3onPrimary : Colours.p(Tokens.screen).m3onSurfaceVariant
                        font: Tokens.font.label.medium
                        renderType: Text.QtRendering
                        Behavior on color { CAnim {} }
                    }

                    StateLayer {
                        radius: Tokens.rounding.full
                        color: pill.isActive ? Colours.p(Tokens.screen).m3onPrimary : Colours.p(Tokens.screen).m3primary
                        onClicked: Wallpapers.wallpaperFilter = pill.modelData.value
                    }
                }
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.large
            text: qsTr("Local wallpapers")
            font: Tokens.font.title.small
        }

        GridLayout {
            id: wallGrid
            Layout.fillWidth: true
            visible: localWalls.count > 0

            columns: Config.nexus.wallpapersPerRow
            rowSpacing: Tokens.spacing.medium
            columnSpacing: Tokens.spacing.large

            Repeater {
                id: localWalls

                model: {
                    let walls = Wallpapers.list;
                    if (Wallpapers.wallpaperFilter === "static")
                        walls = walls.filter(w => !Images.isValidVideoByName(w.path));
                    else if (Wallpapers.wallpaperFilter === "live")
                        walls = walls.filter(w => Images.isValidVideoByName(w.path));

                    const baseDir = Paths.wallsdir;
                    const categories = {};
                    const list = [];
                    for (const w of walls) {
                        if (w.parentDir !== baseDir) {
                            const category = Wallpapers.getCategoryFor(w);
                            if (category && (!(category in categories) || categories[category].name.localeCompare(w.name) > 0))
                                categories[category] = w;
                        } else {
                            list.push(w);
                        }
                    }
                    list.push(...Object.values(categories));
                    list.sort((a, b) => ((a.parentDir === baseDir) - (b.parentDir === baseDir)) || a.name.localeCompare(b.name));
                    while (list.length < Config.nexus.wallpapersPerRow)
                        list.push(null);
                    return list;
                }

                WallItem {
                    id: wallItem
                    required property FileSystemEntry modelData

                    opacity: modelData ? 1 : 0
                    enabled: modelData

                    path: String(modelData?.path ?? "")
                    text: {
                        if (!modelData)
                            return "";
                        if (modelData.parentDir !== Paths.wallsdir) {
                            const category = Wallpapers.getCategoryFor(modelData);
                            return category.slice(0, 1).toUpperCase() + category.slice(1);
                        }
                        return modelData.name;
                    }
                    onClicked: {
                        if (modelData.parentDir !== Paths.wallsdir) {
                            root.nState.selectedWallpaperCategory = Wallpapers.getCategoryFor(modelData);
                            root.nState.openSubPage(2);
                        } else {
                            root._apply(modelData.path);
                        }
                    }
                }
            }
        }

        Loader {
            Layout.fillWidth: true
            asynchronous: true
            active: localWalls.count === 0
            visible: active

            sourceComponent: StyledRect {
                color: Colours.tp(Tokens.screen).m3surfaceContainer
                radius: Tokens.rounding.extraLarge
                implicitHeight: noWallsLayout.implicitHeight + Tokens.padding.extraExtraLarge * 2

                ColumnLayout {
                    id: noWallsLayout
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.extraSmall

                    MaterialIcon {
                        Layout.alignment: Qt.AlignHCenter
                        text: "hide_image"
                        color: Colours.p(Tokens.screen).m3outline
                        fontStyle: Tokens.font.icon.extraLarge
                    }

                    StyledText {
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("No local wallpapers found")
                        color: Colours.p(Tokens.screen).m3outline
                        font: Tokens.font.title.small
                    }
                }
            }
        }
    }

    component MonitorPill: Item {
        property string label: ""
        property bool active: false

        signal clicked

        implicitWidth: pillLabel.implicitWidth + Tokens.padding.medium * 2
        implicitHeight: pillLabel.implicitHeight + Tokens.padding.small * 2

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.full
            color: active ? Colours.p(Tokens.screen).m3primary : Colours.tp(Tokens.screen).m3surfaceContainer
            Behavior on color { CAnim {} }
        }

        StyledText {
            id: pillLabel
            anchors.centerIn: parent
            text: label
            color: active ? Colours.p(Tokens.screen).m3onPrimary : Colours.p(Tokens.screen).m3onSurfaceVariant
            font: Tokens.font.label.medium
            Behavior on color { CAnim {} }
        }

        StateLayer {
            radius: Tokens.rounding.full
            color: active ? Colours.p(Tokens.screen).m3onPrimary : Colours.p(Tokens.screen).m3primary
            onClicked: parent.clicked()
        }
    }
}
