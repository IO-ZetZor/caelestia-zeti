pragma ComponentBehavior: Bound

import "items"
import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property SearchBar search
    required property var screenState
    required property var panels
    required property var content

    property bool pillsActive: false

    function focusPills(): void { pillsActive = true; }
    function focusWallpapers(): void { pillsActive = false; }
    function nextFilter(): void { cycleFilter(1); }
    function previousFilter(): void { cycleFilter(-1); }

    readonly property int itemWidth: Tokens.sizes.launcher.wallpaperWidth * 0.8 + Tokens.padding.medium * 2

    readonly property int numItems: {
        const screen = (QsWindow.window as QsWindow)?.screen;
        if (!screen)
            return 0;

        const barMargins = Math.max(Config.border.thickness, panels.bar.implicitWidth);
        let outerMargins = 0;
        if (panels.popouts.hasCurrent && panels.popouts.currentCenter + panels.popouts.nonAnimHeight / 2 > screen.height - content.implicitHeight - Config.border.thickness * 2)
            outerMargins = panels.popouts.nonAnimWidth;
        if ((screenState.utilities || screenState.sidebar) && panels.utilities.implicitWidth > outerMargins)
            outerMargins = panels.utilities.implicitWidth;
        const maxWidth = screen.width - Config.border.rounding * 4 - (barMargins + outerMargins) * 2;

        if (maxWidth <= 0)
            return 0;

        const maxItemsOnScreen = Math.floor(maxWidth / itemWidth);
        const visible = Math.min(maxItemsOnScreen, Config.launcher.maxWallpapers, scriptModel.values.length);

        if (visible === 2)
            return 1;
        if (visible > 1 && visible % 2 === 0)
            return visible - 1;
        return visible;
    }

    readonly property Item currentItem: pathView.currentItem
    readonly property int count: pathView.count

    function decrementCurrentIndex(): void {
        pathView.currentIndex = Math.max(0, pathView.currentIndex - 1);
    }
    function incrementCurrentIndex(): void {
        pathView.currentIndex = Math.min(pathView.count - 1, pathView.currentIndex + 1);
    }

    implicitWidth: Math.min(numItems, pathView.count) * itemWidth

    readonly property list<var> filterOptions: [
        { label: qsTr("All"),    value: "all" },
        { label: qsTr("Static"), value: "static" },
        { label: qsTr("Live"),   value: "live" },
    ]

    readonly property int currentFilterIndex: {
        for (let i = 0; i < filterOptions.length; i++)
            if (filterOptions[i].value === Wallpapers.wallpaperFilter)
                return i;
        return 0;
    }

    readonly property int pillItemHeight: Math.round(Tokens.font.label.medium.pointSize * 1.4) + Tokens.padding.small * 2

    readonly property int pillsAreaHeight: pillBar.y + pillBar.height + Tokens.padding.small

    function cycleFilter(dir: int): void {
        const len = filterOptions.length;
        const idx = ((currentFilterIndex + dir) % len + len) % len;
        Wallpapers.wallpaperFilter = filterOptions[idx].value;
    }

    Row {
        id: pillBar

        anchors.horizontalCenter: parent.horizontalCenter
        y: Tokens.padding.extraSmall

        spacing: Tokens.spacing.small
        height: root.pillItemHeight

        Repeater {
            model: root.filterOptions

            Item {
                required property var modelData
                readonly property int index: model.index

                readonly property bool isActive: Wallpapers.wallpaperFilter === modelData.value
                readonly property bool isPillsFocused: root.pillsActive

                implicitWidth: label.implicitWidth + Tokens.padding.medium * 2
                implicitHeight: root.pillItemHeight

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.full
                    color: isActive ? Colours.p(Tokens.screen).m3primary : Qt.rgba(0, 0, 0, 0)

                    Behavior on color { CAnim {} }
                }

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.full
                    color: Colours.tp(Tokens.screen).m3surfaceContainer
                    opacity: isActive ? 0 : 1

                    Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                }

                StyledRect {
                    anchors.fill: parent
                    radius: Tokens.rounding.full
                    color: Qt.rgba(1, 1, 1, 0.08)
                    opacity: (stateLayer.containsMouse || stateLayer.pressed) && !isActive ? 1 : 0

                    Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: Tokens.rounding.full + 2
                    color: "transparent"
                    border.color: Colours.p(Tokens.screen).m3primary
                    border.width: Math.round(2 * Tokens.rounding.scale)
                    opacity: isPillsFocused && index === root.currentFilterIndex ? 1 : 0

                    Behavior on opacity { Anim { type: Anim.DefaultEffects } }
                }

                StyledText {
                    id: label

                    anchors.centerIn: parent

                    text: modelData.label
                    color: isActive ? Colours.p(Tokens.screen).m3onPrimary : Colours.p(Tokens.screen).m3onSurfaceVariant
                    font: Tokens.font.label.medium
                    renderType: Text.QtRendering

                    Behavior on color { CAnim {} }
                }

                StateLayer {
                    id: stateLayer

                    radius: Tokens.rounding.full
                    color: isActive ? Colours.p(Tokens.screen).m3onPrimary : Colours.p(Tokens.screen).m3primary
                    onClicked: {
                        Wallpapers.wallpaperFilter = modelData.value;
                        root.pillsActive = false;
                    }
                }
            }
        }
    }

    PathView {
        id: pathView

        anchors.top: parent.top
        anchors.topMargin: root.pillsAreaHeight
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right

        model: ScriptModel {
            id: scriptModel

            readonly property string search: root.search.text.split(" ").slice(1).join(" ")

            values: {
                let results = Wallpapers.query(search);
                if (Wallpapers.wallpaperFilter === "static")
                    results = results.filter(w => !Images.isValidVideoByName(w.path));
                else if (Wallpapers.wallpaperFilter === "live")
                    results = results.filter(w => Images.isValidVideoByName(w.path));
                return results;
            }
            onValuesChanged: pathView.currentIndex = search ? 0 : values.findIndex(w => w.path === Wallpapers.actualCurrent)
        }

        Component.onCompleted: currentIndex = Wallpapers.list.findIndex(w => w.path === Wallpapers.actualCurrent)
        Component.onDestruction: Wallpapers.stopPreview()

        onCurrentItemChanged: {
            if (currentItem)
                Wallpapers.preview(root.screenState?.modelData?.name ?? "", (currentItem as WallpaperItem).modelData.path);
        }

        pathItemCount: root.numItems
        cacheItemCount: 4

        snapMode: PathView.SnapToItem
        preferredHighlightBegin: 0.5
        preferredHighlightEnd: 0.5
        highlightRangeMode: PathView.StrictlyEnforceRange

        delegate: WallpaperItem {
            screenState: root.screenState
        }

        path: Path {
            startY: pathView.height / 2

            PathAttribute {
                name: "z"
                value: 0
            }
            PathLine {
                x: pathView.width / 2
                relativeY: 0
            }
            PathAttribute {
                name: "z"
                value: 1
            }
            PathLine {
                x: pathView.width
                relativeY: 0
            }
        }
    }

    CustomMouseArea {
        function onWheel(event: WheelEvent): void {
            if (event.angleDelta.y > 0)
                root.decrementCurrentIndex();
            else if (event.angleDelta.y < 0)
                root.incrementCurrentIndex();
        }

        anchors.fill: parent
    }
}
