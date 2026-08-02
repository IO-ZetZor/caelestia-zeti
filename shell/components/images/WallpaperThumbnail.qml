import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Images
import qs.services
import qs.utils

Image {
    id: root

    property string path

    readonly property bool isVideo: Images.isValidVideoByName(path)
    readonly property string thumbDir: `${Paths.cache}/wallpapers/thumbs`
    readonly property string thumbPath: isVideo ? `${thumbDir}/${Qt.md5(path)}.jpg` : ""

    property int reloadTick
    property bool triedGenerate

    asynchronous: true
    fillMode: Image.PreserveAspectCrop
    retainWhileLoading: true

    cache: !isVideo

    source: {
        if (!path)
            return "";
        if (!isVideo)
            return IUtils.urlForPath(path, fillMode);
        reloadTick;
        return LiveWallpaper.fileUrl(thumbPath);
    }

    onStatusChanged: {
        if (status === Image.Error && isVideo && !triedGenerate) {
            triedGenerate = true;
            gen.running = true;
        }
    }

    onPathChanged: {
        triedGenerate = false;
    }

    Process {
        id: gen

        command: ["sh", "-c", "mkdir -p \"$1\" || exit 1\nffmpeg -y -v error -ss 2 -i \"$2\" -frames:v 1 -vf scale=640:-1 \"$3\" 2>/dev/null || ffmpeg -y -v error -i \"$2\" -frames:v 1 -vf scale=640:-1 \"$3\"", "_", root.thumbDir, root.path, root.thumbPath]

        onExited: code => {
            if (code === 0)
                root.reloadTick++;
            else
                console.warn(`WallpaperThumbnail: could not extract a frame from ${root.path}`);
        }
    }
}
