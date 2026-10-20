pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: FontSettings.roleLabel(FontSettings.selectingRole)
    isSubPage: true

    readonly property var filteredFamilies: {
        const query = search.text.trim().toLocaleLowerCase();
        const families = FontSettings.families;
        if (!query)
            return families;
        return families.filter(family => family.toLocaleLowerCase().includes(query));
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.small

        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: Tokens.padding.small
            text: FontSettings.roleDescription(FontSettings.selectingRole)
            color: Colours.p(Tokens.screen).m3outline
            font: Tokens.font.label.small
            wrapMode: Text.WordWrap
        }

        SearchBar {
            id: search

            Layout.fillWidth: true
            placeholderText: Tr.tr("Search fonts")
            onTextChanged: list.positionViewAtBeginning()
            Component.onCompleted: forceActiveFocus()
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(240, root.flickable.height - search.implicitHeight - count.implicitHeight - Tokens.spacing.small * 3 - Tokens.padding.extraLarge)

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                spacing: 0
                model: root.filteredFamilies

                StyledScrollBar.vertical: StyledScrollBar {
                    flickable: list
                }

                delegate: ConnectedRect {
                    id: fontRow

                    required property string modelData
                    required property int index

                    width: ListView.view.width
                    height: implicitHeight
                    first: index === 0
                    last: index === root.filteredFamilies.length - 1
                    implicitHeight: fontRowLayout.implicitHeight + Tokens.padding.medium * 2

                    StateLayer {
                        onClicked: {
                            FontSettings.setFamily(FontSettings.selectingRole, fontRow.modelData);
                            root.nState.closeSubPage();
                        }
                    }

                    RowLayout {
                        id: fontRowLayout

                        anchors.fill: parent
                        anchors.leftMargin: Tokens.padding.largeIncreased
                        anchors.rightMargin: Tokens.padding.largeIncreased
                        spacing: Tokens.spacing.medium

                        StyledText {
                            Layout.fillWidth: true
                            text: fontRow.modelData
                            font.family: fontRow.modelData
                            font.pointSize: Tokens.font.body.large.pointSize
                            elide: Text.ElideRight
                        }

                        MaterialIcon {
                            visible: FontSettings.familyFor(FontSettings.selectingRole) === fontRow.modelData
                            text: "check"
                            color: Colours.p(Tokens.screen).m3primary
                            fontStyle: Tokens.font.icon.medium
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: list.count === 0
                text: Tr.tr("No fonts found")
                color: Colours.p(Tokens.screen).m3outline
                font: Tokens.font.body.medium
            }
        }

        StyledText {
            id: count

            Layout.leftMargin: Tokens.padding.small
            text: Tr.tr("%1 fonts").arg(root.filteredFamilies.length)
            color: Colours.p(Tokens.screen).m3outline
            font: Tokens.font.label.small
        }
    }
}
