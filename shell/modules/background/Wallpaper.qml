pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.filedialog
import qs.components.images
import qs.services
import qs.utils

Item {
    id: root

    required property ShellScreen screen

    property string source: Wallpapers.forMonitor(screen.name)
    property Item current

    property Item previous
    property bool completed
    property bool initialised

    readonly property bool currentReady: current?.ready ?? false
    readonly property int fadeDuration: LiveWallpaper.fadeDuration > 0 ? LiveWallpaper.fadeDuration : Tokens.anim.durations.expressiveSlowEffects

    function createSurface(path: string): Item {
        const comp = LiveWallpaper.isVideo(path) ? videoComp : imgComp;
        return comp.createObject(root, {
            path,
            screen: root.screen
        });
    }

    function retirePrevious(): void {
        retireTimer.stop();
        hardRetireTimer.stop();
        if (previous) {
            previous.destroy();
            previous = null;
        }
    }

    function swapTo(path: string): void {
        retirePrevious();
        previous = current;
        current = path ? createSurface(path) : null;

        if (!previous)
            return;
        if (!current)
            retirePrevious();
        else
            hardRetireTimer.restart();
    }

    onSourceChanged: {
        if (!initialised)
            return;
        swapTo(source);
        if (source)
            completed = true;
    }

    onCurrentReadyChanged: {
        if (currentReady && previous)
            retireTimer.restart();
    }

    Component.onCompleted: Qt.callLater(() => {
        initialised = true;
        if (source) {
            swapTo(source);
            completed = true;
        }
    })

    Timer {
        id: retireTimer

        interval: root.fadeDuration
        onTriggered: root.retirePrevious()
    }

    Timer {
        id: hardRetireTimer

        interval: 8000
        onTriggered: root.retirePrevious()
    }

    Loader {
        asynchronous: true
        anchors.fill: parent

        active: root.completed && !root.source

        sourceComponent: StyledRect {
            color: Colours.p(Tokens.screen).m3surfaceContainer

            Row {
                anchors.centerIn: parent
                spacing: Tokens.spacing.largeIncreased

                MaterialIcon {
                    text: "sentiment_stressed"
                    color: Colours.p(Tokens.screen).m3onSurfaceVariant
                    fontStyle: Tokens.font.icon.builders.extraLarge.scale(5).build()
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: qsTr("Wallpaper missing?")
                        color: Colours.p(Tokens.screen).m3onSurfaceVariant
                        font: Tokens.font.body.builders.large.size(28 * 2).weight(Font.Bold).build()
                    }

                    StyledRect {
                        implicitWidth: selectWallText.implicitWidth + Tokens.padding.extraLargeIncreased
                        implicitHeight: selectWallText.implicitHeight + Tokens.padding.small

                        radius: Tokens.rounding.full
                        color: Colours.p(Tokens.screen).m3primary

                        FileDialog {
                            id: dialog

                            title: qsTr("Select a wallpaper")
                            filterLabel: qsTr("Image and video files")
                            filters: Images.validWallpaperExtensions
                            onAccepted: path => Wallpapers.setWallpaper(path)
                        }

                        StateLayer {
                            radius: parent.radius
                            color: Colours.p(Tokens.screen).m3onPrimary
                            onClicked: dialog.open()
                        }

                        StyledText {
                            id: selectWallText

                            anchors.centerIn: parent

                            text: qsTr("Set it now!")
                            color: Colours.p(Tokens.screen).m3onPrimary
                            font: Tokens.font.body.large
                        }
                    }
                }
            }
        }
    }

    Component {
        id: imgComp

        CachingImage {
            id: img

            property ShellScreen screen

            readonly property bool ready: status === Image.Ready

            anchors.fill: parent

            opacity: 0

            onStatusChanged: {
                if (status === Image.Ready)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
                duration: root.fadeDuration
            }
        }
    }

    Component {
        id: videoComp

        VideoWallpaper {
            id: vid

            onReadyChanged: {
                if (ready)
                    anim.start();
            }

            Anim on opacity {
                id: anim

                type: Anim.SlowEffects
                running: false
                from: 0
                to: 1
                duration: root.fadeDuration
            }
        }
    }
}
