import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Fonts")
    isSubPage: true

    function openPicker(role: string): void {
        FontSettings.selectingRole = role;
        root.nState.openSubPage(5); // Font picker page
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Families")
        }

        NavRow {
            first: true
            icon: "text_fields"
            text: Tr.tr("Interface")
            subtext: FontSettings.familySubtext("sans")
            onClicked: root.openPicker("sans")
        }

        NavRow {
            icon: "code"
            text: Tr.tr("Monospace")
            subtext: FontSettings.familySubtext("mono")
            onClicked: root.openPicker("mono")
        }

        NavRow {
            icon: "schedule"
            text: Tr.tr("Clock")
            subtext: FontSettings.familySubtext("clock")
            onClicked: root.openPicker("clock")
        }

        NavRow {
            last: true
            icon: "workspaces"
            text: Tr.tr("Workspaces")
            subtext: FontSettings.familySubtext("workspaces")
            onClicked: root.openPicker("workspaces")
        }

        SectionHeader {
            text: Tr.tr("Size")
        }

        SliderRow {
            first: true
            last: true
            icon: "format_size"
            label: Tr.tr("Font size")
            valueLabel: Math.round(GlobalConfig.appearance.font.scale * 100) + "%"
            value: (GlobalConfig.appearance.font.scale - 0.75) / 0.75
            onMoved: v => {
                GlobalConfig.appearance.font.scale = Math.round((0.75 + v * 0.75) * 100) / 100;
            }
        }

        SectionHeader {
            text: Tr.tr("Preview")
        }

        ConnectedRect {
            Layout.fillWidth: true
            first: true
            last: true
            implicitHeight: preview.implicitHeight + Tokens.padding.extraLarge * 2

            ColumnLayout {
                id: preview

                anchors.centerIn: parent
                width: parent.width - Tokens.padding.largeIncreased * 2
                spacing: Tokens.spacing.small

                StyledText {
                    Layout.fillWidth: true
                    text: "Aa Bb Cc Dd Ee Ff Gg Hh Ii Jj"
                    font: Tokens.font.headline.medium
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Tr.tr("The quick brown fox jumps over the lazy dog.")
                    font: Tokens.font.body.medium
                    wrapMode: Text.WordWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "0123456789 !@#$%^&*()"
                    font: Tokens.font.mono.medium
                    elide: Text.ElideRight
                }
            }
        }
    }
}
