pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property ShellScreen screen
    required property ScreenState screenState
    required property var panels

    readonly property bool shouldBeActive: screenState.launcher && Config.launcher.enabled

    readonly property real maxHeight: {
        let max = screen.height - Config.border.thickness * 2 + Tokens.padding.extraLarge;
        if (screenState.dashboard)
            max -= panels.dashboard.nonAnimHeight;

        return Math.min(max, ScreenAdapt.maxPanelHeight(screen));
    }

    readonly property real adaptScale: ScreenAdapt.fitScale(screen, content.implicitWidth, 0)

    property real offsetScale: shouldBeActive ? 0 : 1

    onShouldBeActiveChanged: {
        if (shouldBeActive)
            implicitHeight = Qt.binding(() => content.implicitHeight * adaptScale);
        else
            implicitHeight = implicitHeight;
    }

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitHeight: content.implicitHeight * adaptScale
    implicitWidth: (content.implicitWidth || 630) * adaptScale
    opacity: 1 - offsetScale

    Component.onCompleted: Qt.callLater(() => Apps)

    Behavior on offsetScale {
        Anim {}
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter

        active: root.shouldBeActive || root.visible

        transform: Scale {
            origin.x: content.width / 2
            xScale: root.adaptScale
            yScale: root.adaptScale
        }

        sourceComponent: Content {
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight / root.adaptScale
        }
    }
}
