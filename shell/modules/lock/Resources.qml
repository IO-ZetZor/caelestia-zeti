pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import Caelestia.I18n
import Caelestia.Services
import qs.components
import qs.components.effects
import qs.components.widgets
import qs.services
import qs.utils

StyledRect {
    id: root

    required property string screenName

    readonly property var _cn: Colours.forMonitor(screenName)
    readonly property real fontScale: {
        const diff = width / 391 - 1;
        return 1 + Math.pow(Math.abs(diff), 0.8) * Math.sign(diff);
    }

    implicitHeight: layout.implicitHeight + layout.anchors.margins * 2
    radius: Tokens.rounding.extraLarge
    color: root._cn?.m3surfaceContainer ?? Colours.tp(Tokens.screen).m3surfaceContainer

    ServiceRef {
        service: Cpu
    }

    ServiceRef {
        service: Memory
    }

    ServiceRef {
        service: Storage
    }

    RowLayout {
        id: layout

        anchors.fill: parent
        anchors.margins: Tokens.padding.large
        spacing: Tokens.spacing.large

        Resource {
            id: cpu

            icon: "memory"
            value: Strings.percentOne(Cpu.percentage)
            fillValue: Cpu.percentage
            colour: root._cn?.m3primary ?? Colours.p(Tokens.screen).m3primary
            shapeColour: root._cn?.m3primaryContainer ?? Colours.p(Tokens.screen).m3primaryContainer
            fillColour: Qt.alpha(root._cn?.m3secondary ?? Colours.p(Tokens.screen).m3secondary, 0.3)
            shape: MaterialShape.Pentagon

            MaterialShape {
                x: cpu.mShape.pointAtAngle(45).x - implicitSize / 2 + Tokens.padding.medium
                y: cpu.mShape.pointAtAngle(45).y - implicitSize / 2

                shape: Cpu.temperature > 90 ? MaterialShape.SoftBurst : MaterialShape.Circle
                color: Cpu.temperature > 90 ? (root._cn?.m3errorContainer ?? Colours.p(Tokens.screen).m3errorContainer) : (root._cn?.m3secondaryContainer ?? Colours.p(Tokens.screen).m3secondaryContainer)
                implicitSize: {
                    const size = Math.round(tempLabel.implicitHeight * 2);
                    return size % 2 === 0 ? size : size + 1;
                }

                Behavior on color {
                    CAnim {}
                }

                StyledText {
                    id: tempLabel

                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Math.round(fontInfo.pointSize * 0.04)

                    text: Units.formatSensorTemp(Cpu.temperature)
                    color: Cpu.temperature > 90 ? (root._cn?.m3onErrorContainer ?? Colours.p(Tokens.screen).m3onErrorContainer) : (root._cn?.m3secondary ?? Colours.p(Tokens.screen).m3secondary)
                    font: Tokens.font.title.builders.medium.scale(cpu.width / 112).width(50).build()
                }
            }
        }

        Resource {
            icon: "memory_alt"
            value: Strings.percentOne(Memory.percentage)
            fillValue: Memory.percentage
            colour: root._cn?.m3tertiary ?? Colours.p(Tokens.screen).m3tertiary
            shapeColour: root._cn?.m3onTertiary ?? Colours.p(Tokens.screen).m3onTertiary
            fillColour: Qt.alpha(root._cn?.m3tertiary ?? Colours.p(Tokens.screen).m3tertiary, 0.3)
            shape: MaterialShape.Slanted
        }

        Resource {
            icon: "hard_disk"
            value: Strings.percentOne(Storage.percentage)
            fillValue: Storage.percentage
            colour: root._cn?.m3secondary ?? Colours.p(Tokens.screen).m3secondary
            shapeColour: root._cn?.m3secondaryContainer ?? Colours.p(Tokens.screen).m3secondaryContainer
            fillColour: Qt.alpha(root._cn?.m3secondary ?? Colours.p(Tokens.screen).m3secondary, 0.4)
            shape: MaterialShape.Gem
        }
    }

    component Resource: Item {
        id: res

        required property string icon
        required property string value
        required property color colour
        required property color shapeColour
        property color fillColour
        property real fillValue: -1
        property alias shape: shape.shape
        readonly property alias mShape: shape

        Layout.fillWidth: true
        implicitHeight: width

        Behavior on shapeColour {
            CAnim {}
        }

        MaterialShape {
            id: shape

            implicitSize: res.width
            color: Qt.alpha(res.shapeColour, 1)
            opacity: res.shapeColour.a
            layer.enabled: true
        }

        Loader {
            id: fillLoader

            anchors.fill: shape
            active: res.fillValue >= 0
            asynchronous: true

            layer.enabled: active
            layer.effect: Mask {
                maskSource: shape
            }

            sourceComponent: Item {
                WavyTopRect {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    implicitHeight: shape.implicitSize * res.fillValue
                    color: res.fillColour
                }
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: -Tokens.spacing.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: res.icon
                color: root._cn?.m3secondary ?? Colours.p(Tokens.screen).m3secondary
                fontStyle: Tokens.font.icon.builders.medium.scale(root.fontScale).build()
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: res.value
                color: res.colour
                font: Tokens.font.headline.builders.large.scale(root.fontScale).width(50).build()
            }
        }

        Behavior on fillValue {
            Anim {}
        }
    }
}
