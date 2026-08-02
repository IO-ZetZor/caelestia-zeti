pragma Singleton

import Quickshell

Singleton {
    readonly property list<string> validImageTypes: ["jpeg", "png", "webp", "tiff", "svg"]
    readonly property list<string> validImageExtensions: ["jpg", "jpeg", "png", "webp", "tif", "tiff", "svg", "gif"]

    readonly property list<string> validVideoExtensions: ["mp4", "mkv", "webm", "mov", "m4v", "avi"]

    readonly property list<string> validWallpaperExtensions: [...validImageExtensions, ...validVideoExtensions]

    function isValidImageByName(name: string): bool {
        return validImageExtensions.some(t => name.toLowerCase().endsWith(`.${t}`));
    }

    function isValidVideoByName(name: string): bool {
        return validVideoExtensions.some(t => name.toLowerCase().endsWith(`.${t}`));
    }

    function isValidWallpaperByName(name: string): bool {
        return isValidImageByName(name) || isValidVideoByName(name);
    }
}
