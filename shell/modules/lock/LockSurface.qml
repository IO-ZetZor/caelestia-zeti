pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import Caelestia.Config
import qs.components
import qs.components.images
import qs.services
import qs.utils

WlSessionLockSurface {
    id: root

    required property WlSessionLock lock
    required property Pam pam

    readonly property alias unlocking: unlockAnim.running

    readonly property string _screenName: screen?.name ?? ""
    // This monitor's own wallpaper; videos can't be drawn as a still, so they use screencopy
    readonly property string _wallpaper: Wallpapers.forMonitor(_screenName)

    contentItem.Config.screen: _screenName
    contentItem.Tokens.screen: _screenName

    color: "transparent"

    Connections {
        function onUnlock(): void {
            unlockAnim.start();
        }

        target: root.lock
    }

    SequentialAnimation {
        id: unlockAnim

        ParallelAnimation {
            Anim {
                target: lockContent
                properties: "implicitWidth,implicitHeight"
                to: lockContent.size
            }
            Anim {
                target: lockBg
                property: "radius"
                to: lockContent.radius
            }
            Anim {
                target: content
                property: "scale"
                to: 0
            }
            Anim {
                target: content
                property: "opacity"
                to: 0
                type: Anim.StandardSmall
            }
            Anim {
                target: lockIcon
                property: "opacity"
                to: 1
                type: Anim.StandardLarge
            }
            Anim {
                target: background
                property: "opacity"
                to: 0
                type: Anim.StandardLarge
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: Tokens.anim.durations.small
                }
                Anim {
                    type: Anim.Standard
                    target: lockContent
                    property: "opacity"
                    to: 0
                }
            }
        }
        PropertyAction {
            target: root.lock
            property: "locked"
            value: false
        }
    }

    ParallelAnimation {
        id: initAnim

        running: true

        Anim {
            target: background
            property: "opacity"
            to: 1
            type: Anim.StandardLarge
        }
        SequentialAnimation {
            ParallelAnimation {
                Anim {
                    target: lockContent
                    property: "scale"
                    to: 1
                    type: Anim.FastSpatial
                }
                Anim {
                    target: lockContent
                    property: "rotation"
                    to: 360
                    duration: Tokens.anim.durations.expressiveFastSpatial
                    easing: Tokens.anim.standardAccel
                }
            }
            ParallelAnimation {
                Anim {
                    target: lockIcon
                    property: "rotation"
                    to: 360
                    easing: Tokens.anim.standardDecel
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: lockIcon
                    property: "opacity"
                    to: 0
                }
                Anim {
                    type: Anim.DefaultEffects
                    target: content
                    property: "opacity"
                    to: 1
                }
                Anim {
                    target: content
                    property: "scale"
                    to: 1
                }
                Anim {
                    target: lockBg
                    property: "radius"
                    to: lockContent.Tokens.rounding.extraLarge * 1.5
                }
                Anim {
                    target: lockContent
                    property: "implicitWidth"
                    to: lockContent.finalW
                }
                Anim {
                    target: lockContent
                    property: "implicitHeight"
                    to: lockContent.finalH
                }
            }
        }
    }

    Item {
        id: background

        anchors.fill: parent
        opacity: 0

        layer.enabled: true
        layer.effect: MultiEffect {
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 64
            blurMultiplier: 1
        }

        Loader {
            anchors.fill: parent
            sourceComponent: Config.lock.useWallpaper && !Images.isValidVideoByName(root._wallpaper) ? wallpaperBackground : screencopyBackground
        }
    }

    Component {
        id: screencopyBackground

        ScreencopyView {
            captureSource: root.screen
        }
    }

    Component {
        id: wallpaperBackground

        CachingImage {
            path: root._wallpaper
        }
    }

    Item {
        id: lockContent

        readonly property int size: lockIcon.implicitHeight + Tokens.padding.large * 4
        readonly property int radius: size / 4 * Tokens.rounding.scale

        readonly property real finalW: {
            const s = root.screen;
            if (!s) return size;
            const pad = Tokens.padding.large * 2;
            const fromH = s.height * Tokens.sizes.lock.heightMult * Tokens.sizes.lock.ratio;

            const maxW = s.width / (s.width / s.height > 2.0 ? 1.8 : 1) - pad;
            return Math.min(maxW, fromH, s.width - pad);
        }
        readonly property real finalH: {
            const s = root.screen;
            if (!s) return size;
            const pad = Tokens.padding.large * 2;
            return Math.min(s.height - pad, s.height * Tokens.sizes.lock.heightMult);
        }

        anchors.centerIn: parent
        implicitWidth: size
        implicitHeight: size

        visible: Config.lock.enabled
        rotation: 180
        scale: 0

        StyledRect {
            id: lockBg

            anchors.fill: parent
            color: Colours.p(root._screenName).m3surface
            radius: parent.radius
            opacity: Colours.transparency.enabled ? Colours.transparency.base : 1

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                blurMax: 15
                shadowColor: Qt.alpha(Colours.p(root._screenName).m3shadow, 0.7)
            }
        }

        MaterialIcon {
            id: lockIcon

            anchors.centerIn: parent
            text: "lock"
            fontStyle: Tokens.font.icon.builders.extraLarge.scale(4).weight(Font.Bold).build()
            rotation: 180
        }

        Content {
            id: content

            // Fixed size (not anchors.fill): the unlock animation shrinks lockContent
            // to icon size, and squeezing the layouts down with it spins forever.
            anchors.centerIn: parent
            width: lockContent.finalW - Tokens.padding.extraLargeIncreased
            height: lockContent.finalH - Tokens.padding.extraLargeIncreased

            lock: root
            monitorName: root._screenName
            opacity: 0
            scale: 0
        }
    }
}
