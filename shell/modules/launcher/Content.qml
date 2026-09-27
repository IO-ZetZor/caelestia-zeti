pragma ComponentBehavior: Bound

import QtQuick
import Caelestia
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.launcher.services

Item {
    id: root

    required property ScreenState screenState
    required property var panels
    required property real maxHeight

    readonly property int padding: Tokens.padding.large
    readonly property int rounding: Tokens.rounding.extraLarge

    implicitWidth: listWrapper.width + padding * 2
    implicitHeight: search.height + listWrapper.height + padding + search.anchors.bottomMargin

    Item {
        id: listWrapper

        implicitWidth: list.width
        implicitHeight: list.height + root.padding

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: search.top
        anchors.bottomMargin: root.padding

        ContentList {
            id: list

            content: root
            screenState: root.screenState
            panels: root.panels
            maxHeight: root.maxHeight - search.implicitHeight - root.padding * 3
            search: search
            padding: root.padding
            rounding: root.rounding
        }
    }

    SearchBar {
        id: search

        objectName: "launcherSearch"

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        anchors.bottomMargin: CUtils.clamp(root.padding - Config.border.thickness, 0, root.padding)

        topPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)
        bottomPadding: Math.round((Tokens.padding.medium + Tokens.padding.large) / 2)

        placeholderText: Tr.tr("Type \"%1\" for commands").arg(GlobalConfig.launcher.actionPrefix)

        onAccepted: {
            const currentItem = list.currentList?.currentItem;
            if (currentItem) {
                if (list.showWallpapers) {

                    const screen = root.screenState?.modelData?.name ?? "";
                    if (Colours.scheme === "dynamic" && currentItem.modelData.path !== Wallpapers.forMonitor(screen))
                        Wallpapers.previewColourLock = true;
                    Wallpapers.setWallpaperFor(screen, currentItem.modelData.path);
                    root.screenState.launcher = false;
                } else if (text.startsWith(GlobalConfig.launcher.actionPrefix)) {
                    if (text.startsWith(`${GlobalConfig.launcher.actionPrefix}calc `))
                        currentItem.onClicked();
                    else
                        currentItem.modelData.onClicked(list.currentList);
                } else {
                    Apps.launch(currentItem.modelData);
                    root.screenState.launcher = false;
                }
            }
        }

        Keys.onUpPressed: {
            if (list.showWallpapers) {
                list.currentList?.focusPills();
                event.accepted = true;
            } else {
                list.currentList?.decrementCurrentIndex();
            }
        }
        Keys.onDownPressed: {
            if (list.showWallpapers) {
                list.currentList?.focusWallpapers();
                event.accepted = true;
            } else {
                list.currentList?.incrementCurrentIndex();
            }
        }
        Keys.onLeftPressed: {
            if (list.showWallpapers) {
                if (list.currentList?.pillsActive)
                    list.currentList?.previousFilter();
                else
                    list.currentList?.decrementCurrentIndex();
                event.accepted = true;
            }
        }
        Keys.onRightPressed: {
            if (list.showWallpapers) {
                if (list.currentList?.pillsActive)
                    list.currentList?.nextFilter();
                else
                    list.currentList?.incrementCurrentIndex();
                event.accepted = true;
            }
        }

        Keys.onEscapePressed: root.screenState.launcher = false

        Keys.onPressed: event => {
            if (!GlobalConfig.launcher.vimKeybinds)
                return;

            if (event.modifiers & Qt.ControlModifier) {
                if (event.key === Qt.Key_J || event.key === Qt.Key_N) {
                    list.currentList?.incrementCurrentIndex();
                    event.accepted = true;
                } else if (event.key === Qt.Key_K || event.key === Qt.Key_P) {
                    list.currentList?.decrementCurrentIndex();
                    event.accepted = true;
                }
            } else if (event.key === Qt.Key_Tab) {
                if (list.showWallpapers) {
                    list.currentList?.focusWallpapers();
                } else {
                    list.currentList?.incrementCurrentIndex();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
                if (list.showWallpapers) {
                    list.currentList?.focusPills();
                } else {
                    list.currentList?.decrementCurrentIndex();
                }
                event.accepted = true;
            }
        }

        Component.onCompleted: forceActiveFocus()

        Connections {
            function onLauncherChanged(): void {
                if (!root.screenState.launcher)
                    search.text = "";
            }

            function onSessionChanged(): void {
                if (!root.screenState.session)
                    search.forceActiveFocus();
            }

            target: root.screenState
        }
    }
}
