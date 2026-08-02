pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Caelestia.Config
import qs.components
import qs.services

Item {
    id: root

    property real dialogWidth: 360

    property real scrimOpacity: 0.32

    property real edgeMargin: Tokens.padding.large

    readonly property bool opened: state === "open"

    default property Item content

    signal closed

    function open(origin: Item): void {
        const c = origin ? origin.mapToItem(root, origin.width / 2, origin.height / 2) : Qt.point(width / 2, height / 2);
        card.originX = c.x;
        card.originY = c.y;
        state = "open";
    }

    function close(): void {
        if (!opened)
            return;
        state = "";
        closed();
    }

    anchors.fill: parent
    opacity: 0
    visible: opacity > 0

    Rectangle {

        anchors.fill: parent
        color: Colours.p(Tokens.screen).m3scrim
        opacity: root.scrimOpacity

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Item {
        id: card

        property real originX
        property real originY

        readonly property real dlgW: Math.min(root.dialogWidth, root.width - root.edgeMargin * 2)
        readonly property real dlgH: (root.content?.implicitHeight ?? 0) + Tokens.padding.extraLarge * 2

        x: Math.max(root.edgeMargin, Math.min(originX - dlgW / 2, root.width - dlgW - root.edgeMargin))
        y: Math.max(root.edgeMargin, Math.min(originY - dlgH / 2, root.height - dlgH - root.edgeMargin))
        implicitWidth: dlgW
        implicitHeight: dlgH
        scale: 0.85

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.extraLarge
            color: Colours.tp(Tokens.screen).m3surfaceContainerHigh

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 24
                shadowColor: Qt.alpha(Colours.p(Tokens.screen).m3shadow, 0.6)
            }
        }

        MouseArea {

            anchors.fill: parent
        }

        Item {
            anchors.fill: parent
            anchors.margins: Tokens.padding.extraLarge
            children: root.content ? [root.content] : []
        }
    }

    states: State {
        name: "open"

        PropertyChanges {
            root.opacity: 1
            card.scale: 1
        }
    }

    transitions: Transition {
        ParallelAnimation {
            Anim {
                target: root
                property: "opacity"
                type: Anim.DefaultEffects
            }
            Anim {
                target: card
                property: "scale"
                type: Anim.FastSpatial
            }
        }
    }
}
