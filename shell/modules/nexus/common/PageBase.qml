pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.nexus

Item {
    id: root

    required property string title
    required property NexusState nState
    property bool isSubPage
    readonly property int cappedWidth: Math.min(Tokens.sizes.nexus.maxContentWidth, width)
    readonly property alias flickable: flickable

    default property Item contentChild

    property Item overlay: null

    implicitWidth: layout.implicitWidth
    implicitHeight: layout.implicitHeight

    ColumnLayout {
        id: layout

        anchors.fill: parent
        spacing: Tokens.spacing.extraLargeIncreased

        MouseArea {
            z: 1
            implicitWidth: header.implicitWidth
            implicitHeight: header.implicitHeight - Layout.bottomMargin
            Layout.bottomMargin: -flickable.topMargin
            onClicked: focus = true

            RowLayout {
                id: header

                spacing: Tokens.spacing.largeIncreased

                Loader {
                    visible: active
                    active: root.isSubPage
                    asynchronous: true
                    sourceComponent: IconButton {
                        icon: "arrow_back"
                        font: Tokens.font.icon.medium
                        type: IconButton.Tonal
                        isRound: true
                        inactiveColour: Colours.tp(Tokens.screen).m3surfaceContainerHigh
                        inactiveOnColour: Colours.p(Tokens.screen).m3onSurfaceVariant
                        onClicked: root.nState.closeSubPage()
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.title
                    font: Tokens.font.title.large
                    elide: Text.ElideRight
                }
            }
        }

        VerticalFadeFlickable {
            id: flickable

            Layout.fillWidth: true
            Layout.fillHeight: true

            Layout.topMargin: -topMargin
            topMargin: Tokens.padding.large
            bottomMargin: Tokens.padding.extraLarge

            contentHeight: root.contentChild?.implicitHeight ?? 0
            contentItem.children: [root.contentChild]

            TapHandler {
                onTapped: flickable.focus = true
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: root.overlay !== null
        z: 100
        children: root.overlay ? [root.overlay] : []
    }
}
