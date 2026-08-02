import "center"
import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    required property var lock
    required property string screenName

    readonly property var _cn: Colours.forMonitor(screenName)

    readonly property var _lsc: typeof LockScreenConfig !== 'undefined' ? LockScreenConfig : null
    readonly property real centerScale: Math.min(1, (lock.screen?.height ?? 1440) / 1440)
    readonly property int centerWidth: Tokens.sizes.lock.centerWidth * centerScale

    Layout.preferredWidth: centerWidth
    Layout.fillWidth: false
    Layout.fillHeight: true

    spacing: Tokens.spacing.largeIncreased

    Item {
        Layout.alignment: Qt.AlignHCenter
        visible: root._lsc?.showDate ?? true

        implicitWidth: Math.max(clock.implicitWidth, dateText.implicitWidth)
        implicitHeight: clock.implicitHeight + Tokens.spacing.small + dateText.implicitHeight + Tokens.padding.large

        Clock {
            id: clock
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            centerScale: root.centerScale
        }

        StyledText {
            id: dateText
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: clock.bottom
            anchors.topMargin: Tokens.spacing.small

            text: Time.format("dddd \u2022 d MMM").toUpperCase()
            color: root._cn?.m3onSurface ?? Colours.p(Tokens.screen).m3onSurface
            font: Tokens.font.title.builders.medium.weight(Font.DemiBold).build()
        }
    }

    ProfilePic {
        Layout.alignment: Qt.AlignHCenter
        Layout.topMargin: Tokens.spacing.extraExtraLarge * root.centerScale
        Layout.bottomMargin: Tokens.spacing.extraLarge * root.centerScale
        visible: root._lsc?.showProfilePic ?? true
        centerWidth: root.centerWidth
    }

    StyledText {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: root.centerWidth

        visible: {
            const note = root._lsc?.lockNote;
            return note && note.trim().length > 0;
        }

        text: root._lsc?.lockNote ?? ""
        color: root._cn?.m3onSurfaceVariant ?? Colours.p(Tokens.screen).m3onSurfaceVariant
        font: Tokens.font.body.small
        wrapMode: Text.WordWrap
        horizontalAlignment: Text.AlignHCenter
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        Layout.fillWidth: true
        Layout.maximumWidth: root.centerWidth

        visible: {
            const cmds = root._lsc?.shellCommands;
            return Array.isArray(cmds) && cmds.length > 0;
        }

        spacing: Tokens.spacing.small

        Repeater {
            model: root._lsc?.shellCommands ?? []

            ShellOutput {
                required property var modelData

                cmdLabel: modelData?.label ?? ""
                cmdCommand: modelData?.command ?? ""
                cn: root._cn
                locked: root.lock.locked
            }
        }
    }

    PasswordInput {
        Layout.alignment: Qt.AlignHCenter
        centerScale: Math.max(0.8, root.centerScale)
        centerWidth: root.centerWidth
        lock: root.lock
    }

    StateMessage {
        Layout.fillWidth: true
        pam: root.lock.pam
    }

    component ShellOutput: Item {
        id: cmdItem

        property string cmdLabel: ""
        property string cmdCommand: ""

        property var cn

        property bool locked

        implicitWidth: parent?.width ?? 0
        implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

        property string _output: ""
        property bool _hasRun: false

        onLockedChanged: {
            if (locked && cmdCommand.length > 0) {
                _hasRun = false;
                _output = "";
                proc.running = true;
            }
        }

        Process {
            id: proc

            command: ["sh", "-c", cmdItem.cmdCommand]
            running: cmdItem.locked && cmdItem.cmdCommand.length > 0

            stdout: StdioCollector {
                onStreamFinished: {
                    cmdItem._output = text.trim();
                    cmdItem._hasRun = true;
                }
            }
        }

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.medium
            color: cmdItem.cn?.m3surfaceContainer ?? Colours.tp(Tokens.screen).m3surfaceContainer
        }

        ColumnLayout {
            id: layout

            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.extraSmall

            StyledText {
                text: cmdItem.cmdLabel
                color: cmdItem.cn?.m3primary ?? Colours.p(Tokens.screen).m3primary
                font: Tokens.font.label.small
                elide: Text.ElideRight
                visible: cmdItem.cmdLabel.length > 0
            }

            StyledText {
                Layout.fillWidth: true

                text: {
                    if (cmdItem._hasRun)
                        return cmdItem._output.length > 0 ? cmdItem._output : "—";
                    return cmdItem.cmdCommand.length > 0 ? "…" : "";
                }
                color: cmdItem._hasRun && cmdItem._output.length > 0
                    ? (cmdItem.cn?.m3onSurface ?? Colours.p(Tokens.screen).m3onSurface)
                    : (cmdItem.cn?.m3outline ?? Colours.p(Tokens.screen).m3outline)
                font: Tokens.font.mono.small
                wrapMode: Text.WordWrap
                visible: cmdItem._hasRun || cmdItem.cmdCommand.length > 0
            }
        }
    }
}
