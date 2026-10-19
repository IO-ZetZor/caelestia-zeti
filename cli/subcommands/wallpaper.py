import json
from argparse import Namespace

from caelestia.utils.wallpaper import get_colours_for_wall, get_wallpaper, set_random, set_wallpaper

class Command:
    args: Namespace

    def __init__(self, args: Namespace) -> None:
        self.args = args

    def run(self) -> None:
        monitor = getattr(self.args, "monitor", None)
        if self.args.print is not None:
            path = self.args.print or get_wallpaper(monitor)
            if not path:
                print("No wallpaper set")
                return
            print(json.dumps(get_colours_for_wall(path, self.args.no_smart)))
        elif self.args.file:
            set_wallpaper(self.args.file, self.args.no_smart, monitor)
        elif self.args.random:
            set_random(self.args)
        else:
            print(get_wallpaper(monitor) or "No wallpaper set")
