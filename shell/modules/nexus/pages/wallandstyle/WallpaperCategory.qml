pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: {
        const c = nState.selectedWallpaperCategory;
        return c.slice(0, 1).toUpperCase() + c.slice(1);
    }
    isSubPage: true

    GridLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth

        columns: Config.nexus.wallpapersPerRow
        rowSpacing: Tokens.spacing.medium
        columnSpacing: Tokens.spacing.large

        Repeater {
            model: {
                let walls = Wallpapers.list.filter(w => Wallpapers.getCategoryFor(w) === root.nState.selectedWallpaperCategory);
                if (Wallpapers.wallpaperFilter === "static")
                    walls = walls.filter(w => !Images.isValidVideoByName(w.path));
                else if (Wallpapers.wallpaperFilter === "live")
                    walls = walls.filter(w => Images.isValidVideoByName(w.path));
                walls.sort((a, b) => a.name.localeCompare(b.name));
                while (walls.length < Config.nexus.wallpapersPerRow)
                    walls.push(null);
                return walls;
            }

            WallItem {
                required property FileSystemEntry modelData

                opacity: modelData ? 1 : 0
                enabled: modelData

                path: String(modelData?.path ?? "")
                text: modelData?.name ?? ""
                onClicked: {
                    const screen = (QsWindow.window as QsWindow)?.screen;
                    if (screen)
                        Wallpapers.setWallpaperFor(screen.name, modelData.path);
                    else
                        Wallpapers.setWallpaper(modelData.path);
                    root.nState.closeSubPage();
                    root.nState.closeSubPage();
                }
            }
        }
    }
}
