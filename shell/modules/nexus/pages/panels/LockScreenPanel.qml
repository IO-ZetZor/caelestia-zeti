pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.filedialog
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: qsTr("Lock Screen")
    isSubPage: true

    readonly property var _lsc: typeof LockScreenConfig !== 'undefined' ? LockScreenConfig : null

    property bool _noteEditing: false

    function _toggle(prop: string, val: bool): void {
        if (_lsc) {
            _lsc[prop] = val;
            _lsc.save();
        }
    }

    function _saveNote(note: string): void {
        if (root._lsc) {
            root._lsc.lockNote = note;
            root._lsc.save();
        }
        root._noteEditing = false;
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader { first: true; text: qsTr("Elements") }

        ToggleRow {
            first: true
            text: qsTr("Date & day")
            checked: root._lsc?.showDate ?? true
            onToggled: root._toggle("showDate", checked)
        }

        ToggleRow {
            text: qsTr("Profile picture")
            checked: root._lsc?.showProfilePic ?? true
            onToggled: root._toggle("showProfilePic", checked)
        }

        ToggleRow {
            text: qsTr("Weather")
            checked: root._lsc?.showWeather ?? true
            onToggled: root._toggle("showWeather", checked)
        }

        ToggleRow {
            text: qsTr("System info (fetch)")
            checked: root._lsc?.showFetch ?? true
            onToggled: root._toggle("showFetch", checked)
        }

        ToggleRow {
            text: qsTr("Music player")
            checked: root._lsc?.showMedia ?? true
            onToggled: root._toggle("showMedia", checked)
        }

        ToggleRow {
            last: true
            text: qsTr("Resources (CPU, RAM, storage)")
            checked: root._lsc?.showResources ?? true
            onToggled: root._toggle("showResources", checked)
        }

        SectionHeader { text: qsTr("Display") }

        ToggleRow {
            first: true
            text: qsTr("Notifications")
            subtext: qsTr("Show notifications on the lock screen")
            checked: !Config.lock.hideNotifs
            onToggled: GlobalConfig.lock.hideNotifs = !checked
        }

        ToggleRow {
            last: true
            text: qsTr("Recolour logo")
            subtext: qsTr("Tint the distro logo with the accent colour")
            checked: Config.lock.recolourLogo
            onToggled: GlobalConfig.lock.recolourLogo = checked
        }

        SectionHeader { text: qsTr("Appearance") }

        NavRow {
            first: true
            icon: "clear_night"
            label: qsTr("No-notifications image")

            status: {
                const pic = Config.paths.lockNoNotifsPic;
                return pic ? Paths.shortenHome(pic) : qsTr("Default");
            }
            onClicked: noNotifsPicDialog.open()

            FileDialog {
                id: noNotifsPicDialog
                title: qsTr("Select an image")
                filterLabel: qsTr("Image files")
                filters: Images.validImageExtensions
                onAccepted: path => GlobalConfig.paths.lockNoNotifsPic = path
            }
        }

        NavRow {
            icon: "restart_alt"
            label: qsTr("Reset image")
            status: qsTr("Use the built-in default")
            visible: !!Config.paths.lockNoNotifsPic
            onClicked: GlobalConfig.paths.lockNoNotifsPic = ""
        }

        NavRow {
            id: lockNoteRow
            last: !root._noteEditing
            icon: "edit_note"
            label: qsTr("Lock note")

            status: {
                const note = root._lsc?.lockNote ?? "";
                if (!note.trim())
                    return qsTr("Not set");
                return note.length > 40 ? `${note.slice(0, 40)}…` : note;
            }
            onClicked: root._noteEditing = !root._noteEditing
        }

        Loader {
            Layout.fillWidth: true
            active: root._noteEditing
            visible: active

            sourceComponent: ColumnLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small
                Component.onCompleted: noteField.forceActiveFocus()

                StyledTextField {
                    id: noteField
                    Layout.fillWidth: true
                    placeholderText: qsTr("Enter a note to show on the lock screen...")
                    text: root._lsc?.lockNote ?? ""
                    font: Tokens.font.body.small
                    onAccepted: root._saveNote(text)
                }

                Row {
                    Layout.alignment: Qt.AlignHCenter
                    spacing: Tokens.spacing.small

                    IconTextButton {
                        icon: "close"
                        text: qsTr("Cancel")
                        font: Tokens.font.body.large
                        isRound: true
                        shapeMorph: true
                        type: IconTextButton.Text
                        horizontalPadding: Tokens.padding.extraLarge
                        verticalPadding: Tokens.padding.small
                        onClicked: root._noteEditing = false
                    }

                    IconTextButton {
                        icon: "check"
                        text: qsTr("Save")
                        font: Tokens.font.body.large
                        isRound: true
                        shapeMorph: true
                        horizontalPadding: Tokens.padding.extraLarge
                        verticalPadding: Tokens.padding.small
                        onClicked: root._saveNote(noteField.text)
                    }
                }
            }
        }

        SectionHeader { text: qsTr("Shell commands") }

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            Layout.topMargin: Tokens.spacing.extraSmall
            text: qsTr("Add shell commands whose output is displayed on the lock screen.")
            color: Colours.p(Tokens.screen).m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root._lsc?.shellCommands ?? []

            ShellCommandRow {
                required property int index
                required property var modelData

                label: modelData?.label ?? ""
                command: modelData?.command ?? ""

                onLabelEdited: newLabel => {
                    if (!root._lsc) return;
                    const cmds = root._lsc.shellCommands.slice();
                    cmds[index] = Object.assign({}, cmds[index], {label: newLabel});
                    root._lsc.shellCommands = cmds;
                    root._lsc.save();
                }

                onCommandEdited: newCmd => {
                    if (!root._lsc) return;
                    const cmds = root._lsc.shellCommands.slice();
                    cmds[index] = Object.assign({}, cmds[index], {command: newCmd});
                    root._lsc.shellCommands = cmds;
                    root._lsc.save();
                }

                onRemove: {
                    if (!root._lsc) return;
                    const cmds = root._lsc.shellCommands.slice();
                    cmds.splice(index, 1);
                    root._lsc.shellCommands = cmds;
                    root._lsc.save();
                }
            }
        }

        IconTextButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.small
            icon: "add"
            text: qsTr("Add command")
            font: Tokens.font.body.large
            isRound: true
            shapeMorph: true
            type: IconTextButton.Tonal
            horizontalPadding: Tokens.padding.extraLarge
            verticalPadding: Tokens.padding.small
            onClicked: {
                if (!root._lsc) return;
                const cmds = root._lsc.shellCommands.slice();
                cmds.push({label: qsTr("New command"), command: "echo Hello"});
                root._lsc.shellCommands = cmds;
                root._lsc.save();
            }
        }

        SectionHeader { text: qsTr("Authentication") }

        ToggleRow {
            first: true
            text: qsTr("Fingerprint unlock")
            subtext: qsTr("Allow unlocking with a fingerprint reader")
            checked: GlobalConfig.lock.enableFprint
            onToggled: GlobalConfig.lock.enableFprint = checked
        }

        ToggleRow {
            text: qsTr("Face unlock (howdy)")
            subtext: qsTr("Allow unlocking with facial recognition")
            checked: GlobalConfig.lock.enableHowdy
            onToggled: GlobalConfig.lock.enableHowdy = checked
        }

        ToggleRow {
            last: true
            text: qsTr("Auto face unlock on wake")
            subtext: qsTr("Trigger facial recognition automatically after resume")
            checked: GlobalConfig.lock.triggerHowdyOnWake
            onToggled: GlobalConfig.lock.triggerHowdyOnWake = checked
        }
    }

    component ShellCommandRow: Item {
        property string label: ""
        property string command: ""

        signal labelEdited(newLabel: string)
        signal commandEdited(newCmd: string)
        signal remove

        implicitWidth: parent?.width ?? 0
        implicitHeight: cmdLayout.implicitHeight + Tokens.padding.medium * 2

        StyledRect {
            anchors.fill: parent
            radius: Tokens.rounding.medium
            color: Colours.tp(Tokens.screen).m3surfaceContainer
        }

        ColumnLayout {
            id: cmdLayout
            anchors.fill: parent
            anchors.margins: Tokens.padding.medium
            spacing: Tokens.spacing.medium

            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.small

                StyledTextField {
                    Layout.fillWidth: true
                    placeholderText: qsTr("Label")
                    text: label

                    onEditingFinished: {
                        if (text !== label)
                            labelEdited(text);
                    }
                    font: Tokens.font.body.small
                }

                IconButton {
                    icon: "close"
                    isRound: true
                    font: Tokens.font.icon.small
                    implicitWidth: 32
                    implicitHeight: 32
                    type: IconButton.Text
                    onClicked: remove()
                }
            }

            StyledTextField {
                Layout.fillWidth: true
                placeholderText: qsTr("Command (e.g. echo Hello)")
                text: command
                onEditingFinished: {
                    if (text !== command)
                        commandEdited(text);
                }
                font: Tokens.font.mono.small
            }
        }
    }
}
