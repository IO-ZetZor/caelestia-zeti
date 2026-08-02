pragma ComponentBehavior: Bound

import QtQuick
import QtMultimedia
import Quickshell
import qs.services

Item {
    id: root

    required property string path
    required property ShellScreen screen

    readonly property bool ready: hasFirstFrame
    property bool hasFirstFrame

    readonly property bool obscured: {
        if (!LiveWallpaper.pauseWhenObscured)
            return false;
        const toplevels = Hypr.monitorFor(screen)?.activeWorkspace?.toplevels?.values;
        if (!toplevels || toplevels.length === 0)
            return false;
        return !toplevels.every(t => t.lastIpcObject?.floating);
    }

    readonly property bool hidden: LiveWallpaper.pauseWhenHidden && (ShellState.locked || !(Hypr.monitorFor(screen)?.lastIpcObject?.dpmsStatus ?? true))

    readonly property bool shouldDecode: LiveWallpaper.enabled && !obscured && !hidden

    readonly property bool shouldLoad: LiveWallpaper.enabled

    readonly property bool shouldPlay: shouldLoad && (shouldDecode || !hasFirstFrame)

    anchors.fill: parent
    opacity: 0

    onShouldPlayChanged: {
        if (shouldPlay)
            player.play();
        else
            player.pause();
    }

    Component.onCompleted: {
        if (shouldPlay)
            player.play();
    }

    VideoOutput {
        id: output

        anchors.fill: parent

        fillMode: VideoOutput.PreserveAspectCrop
    }

    MediaPlayer {
        id: player

        videoOutput: output
        loops: MediaPlayer.Infinite
        playbackRate: LiveWallpaper.playbackRate
        source: root.shouldLoad ? LiveWallpaper.fileUrl(root.path) : ""

        audioOutput: AudioOutput {
            muted: LiveWallpaper.muted
            volume: LiveWallpaper.volume
        }

        onSourceChanged: root.hasFirstFrame = false

        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia && root.shouldPlay)
                play();
        }

        onPositionChanged: {
            if (!root.hasFirstFrame && position > 0)
                root.hasFirstFrame = true;
        }

        onErrorOccurred: (err, str) => {
            console.warn(`VideoWallpaper: failed to play ${root.path}: ${str}`);

            root.hasFirstFrame = true;
        }
    }

    Timer {
        running: root.shouldPlay && player.playbackState === MediaPlayer.PlayingState && !root.hasFirstFrame
        interval: 1500
        onTriggered: root.hasFirstFrame = true
    }
}
