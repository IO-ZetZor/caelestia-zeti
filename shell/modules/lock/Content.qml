import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import qs.components
import qs.services

RowLayout {
    id: root

    required property var lock
    required property string monitorName

    readonly property var _cn: Colours.forMonitor(monitorName)

    readonly property var _lsc: typeof LockScreenConfig !== 'undefined' ? LockScreenConfig : null

    readonly property bool isNarrow: {
        const s = lock?.screen;
        return s ? (s.width / s.height) < 1.3 : false;
    }

    spacing: Tokens.spacing.largeIncreased * 2

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium
        visible: !root.isNarrow && ((root._lsc?.showWeather ?? true) || (root._lsc?.showFetch ?? true) || (root._lsc?.showMedia ?? true))

        WeatherInfo {
            Layout.fillWidth: true
            rootHeight: root.height
            screenName: root.monitorName
            visible: root._lsc?.showWeather ?? true
        }

        Fetch {
            Layout.fillWidth: true
            rootHeight: root.height
            screenName: root.monitorName
            visible: root._lsc?.showFetch ?? true
        }

        Media {
            Layout.fillWidth: true
            Layout.fillHeight: true
            lock: root.lock
            screenName: root.monitorName
            visible: root._lsc?.showMedia ?? true
        }

        Behavior on visible {
            SequentialAnimation {
                Anim {
                    property: "opacity"
                    to: 0
                    type: Anim.DefaultEffects
                }
                PropertyAction {}
            }
        }
    }

    Center {
        Layout.alignment: Qt.AlignHCenter
        lock: root.lock
        screenName: root.monitorName
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.medium
        visible: !root.isNarrow && (root._lsc?.showResources ?? true)

        Resources {
            Layout.fillWidth: true
            screenName: root.monitorName
            visible: root._lsc?.showResources ?? true
        }

        StyledRect {
            Layout.fillWidth: true
            Layout.fillHeight: true

            bottomRightRadius: Tokens.rounding.extraLarge
            radius: Tokens.rounding.medium
            color: root._cn?.m3surfaceContainer ?? Colours.tp(Tokens.screen).m3surfaceContainer

            NotifDock {
                lock: root.lock
                screenName: root.monitorName
            }
        }

        Behavior on visible {
            SequentialAnimation {
                Anim {
                    property: "opacity"
                    to: 0
                    type: Anim.DefaultEffects
                }
                PropertyAction {}
            }
        }
    }
}
