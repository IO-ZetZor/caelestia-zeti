import json
import os
import random
import subprocess
import sys
from argparse import Namespace
from pathlib import Path
from typing import cast

from materialyoucolor.hct import Hct
from materialyoucolor.utils.color_utils import argb_from_rgb
from PIL import Image

from caelestia.utils.colourfulness import get_variant
from caelestia.utils.hypr import message
from caelestia.utils.material import get_colours_for_image
from caelestia.utils.paths import (
    atomic_dump,
    atomic_write,
    compute_hash,
    get_config,
    truncate,
    wallpaper_link_path,
    wallpaper_monitor_path,
    wallpaper_monitor_scheme_path,
    wallpaper_monitors_dir,
    wallpaper_path_path,
    wallpaper_thumbnail_path,
    wallpapers_cache_dir,
)
from caelestia.utils.scheme import Scheme, get_scheme
from caelestia.utils.theme import apply_colours

IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff", ".gif"]
VIDEO_EXTENSIONS = [".mp4", ".mkv", ".webm", ".mov", ".m4v", ".avi"]

def is_valid_image(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS

def is_valid_video(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in VIDEO_EXTENSIONS

def is_valid_wallpaper(path: Path) -> bool:
    return is_valid_image(path) or is_valid_video(path)

def extract_video_frame(video: Path) -> Path:
    """Extract a representative frame from a video for thumbnail/colour generation.

    Cached per-video by content hash so it only runs once. Grabs a frame a couple
    of seconds in (past any intro fade to black) via ffmpeg.
    """
    cache = wallpapers_cache_dir / compute_hash(video)
    frame = cache / "frame.png"

    if not frame.exists():
        frame.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-ss",
                "2",
                "-i",
                str(video),
                "-frames:v",
                "1",
                "-vf",
                "scale=640:-1",
                str(frame),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if not frame.exists():
            subprocess.run(
                ["ffmpeg", "-y", "-i", str(video), "-frames:v", "1", str(frame)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                check=False,
            )

    return frame

def image_for_colours(wall: Path) -> Path:
    """Return a still image usable for palette extraction for any wallpaper type."""
    if is_valid_video(wall):
        return extract_video_frame(wall)
    if wall.suffix.lower() == ".gif":
        return convert_gif(wall)
    return wall

def check_wall(wall: Path, filter_size: tuple[int, int], threshold: float) -> bool:
    with Image.open(wall) as img:
        width, height = img.size
        return width >= filter_size[0] * threshold and height >= filter_size[1] * threshold

def get_wallpaper(monitor: str | None = None) -> str | None:
    if monitor:
        try:
            if override := wallpaper_monitor_path(monitor).read_text().strip():
                return override
        except IOError:
            pass
    try:
        return wallpaper_path_path.read_text()
    except IOError:
        return None

def clear_monitor_overrides() -> None:
    """Drop every per-monitor override so the global wallpaper applies again.

    Files are truncated rather than removed: the shell's FileView watchers are
    created once per monitor at startup and cannot re-attach to a path that has
    been unlinked, so deleting them would stop the shell from ever seeing later
    per-monitor changes.
    """
    if not wallpaper_monitors_dir.is_dir():
        return
    for f in wallpaper_monitors_dir.iterdir():
        if f.suffix == ".txt" or f.name.endswith("-scheme.json"):
            truncate(f)

def get_wallpapers(args: Namespace) -> list[Path]:
    directory = Path(args.random)
    if not directory.is_dir():
        return []

    walls = [f for f in directory.rglob("*") if is_valid_wallpaper(f)]

    if args.no_filter:
        return walls

    monitors = cast(list[dict[str, int]], message("monitors"))
    filter_size = min(m["width"] for m in monitors), min(m["height"] for m in monitors)

    return [f for f in walls if is_valid_video(f) or check_wall(f, filter_size, args.threshold)]

def get_thumb(wall: Path, cache: Path) -> Path:
    thumb = cache / "thumbnail.jpg"

    if not thumb.exists():
        with Image.open(wall) as img:
            img = img.convert("RGB")
            img.thumbnail((128, 128), Image.Resampling.NEAREST)
            thumb.parent.mkdir(parents=True, exist_ok=True)
            img.save(thumb, "JPEG")

    return thumb

def get_smart_opts(wall: Path, cache: Path) -> dict:
    opts_cache = cache / "smart.json"

    try:
        return json.loads(opts_cache.read_text())
    except (IOError, json.JSONDecodeError):
        pass

    opts = {}

    with Image.open(get_thumb(wall, cache)) as img:
        opts["variant"] = get_variant(img)
        img.thumbnail((1, 1), Image.Resampling.LANCZOS)

        pixel = cast(tuple[int, int, int], img.getpixel((0, 0)))
        hct = Hct.from_int(argb_from_rgb(*pixel))

        opts["mode"] = "light" if hct.tone > 60 else "dark"

    opts_cache.parent.mkdir(parents=True, exist_ok=True)
    with opts_cache.open("w") as f:
        json.dump(opts, f)

    return opts

def get_colours_for_wall(wall: Path | str, no_smart: bool) -> None:
    wall = Path(wall)
    scheme = get_scheme()
    cache = wallpapers_cache_dir / compute_hash(wall)

    wall = image_for_colours(wall)

    name = "dynamic"

    if not no_smart:
        smart_opts = get_smart_opts(wall, cache)
        scheme = Scheme(
            {
                "name": name,
                "flavour": scheme.flavour,
                "mode": smart_opts["mode"],
                "variant": smart_opts["variant"],
                "colours": scheme.colours,
            }
        )

    return {
        "name": name,
        "flavour": scheme.flavour,
        "mode": scheme.mode,
        "variant": scheme.variant,
        "colours": get_colours_for_image(get_thumb(wall, cache), scheme),
    }

def convert_gif(wall: Path) -> Path:
    cache = wallpapers_cache_dir / compute_hash(wall)
    output_path = cache / "first_frame.png"

    if not output_path.exists():
        output_path.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(wall) as img:
            try:
                img.seek(0)
            except EOFError:
                pass

            img = img.convert("RGB")
            img.save(output_path, "PNG")

    return output_path

def set_wallpaper(wall: Path, no_smart: bool, monitor: str | None = None) -> None:
    wall = Path(wall).resolve()

    if not is_valid_wallpaper(wall):
        raise ValueError(f'"{wall}" is not a valid image or video')

    wall_cache = image_for_colours(wall)

    if monitor:
        path = wallpaper_monitor_path(monitor)
        path.parent.mkdir(parents=True, exist_ok=True)
        atomic_write(path, str(wall))

        try:
            cache = wallpapers_cache_dir / compute_hash(wall_cache)
            thumb = get_thumb(wall_cache, cache)
            scheme = get_scheme()
            if scheme.name == "dynamic" and not no_smart:
                smart_opts = get_smart_opts(wall_cache, cache)
                scheme._mode = smart_opts["mode"]
                scheme._variant = smart_opts["variant"]

            if scheme.name == "dynamic":
                colours = get_colours_for_image(thumb, scheme)
            else:
                colours = scheme.colours

            scheme_data = {
                "wallpaper": str(wall),
                "name": scheme.name,
                "flavour": scheme.flavour,
                "mode": scheme.mode,
                "variant": scheme.variant,
                "colours": colours,
            }
            monitor_scheme = wallpaper_monitor_scheme_path(monitor)
            monitor_scheme.parent.mkdir(parents=True, exist_ok=True)
            atomic_dump(monitor_scheme, scheme_data)
            print(json.dumps(scheme_data))
        except Exception as e:
            print(f"caelestia: per-monitor colour extraction failed: {e}", file=sys.stderr)
        return

    wallpaper_path_path.parent.mkdir(parents=True, exist_ok=True)
    atomic_write(wallpaper_path_path, str(wall))
    wallpaper_link_path.parent.mkdir(parents=True, exist_ok=True)
    wallpaper_link_path.unlink(missing_ok=True)
    wallpaper_link_path.symlink_to(wall)

    clear_monitor_overrides()

    cache = wallpapers_cache_dir / compute_hash(wall_cache)

    thumb = get_thumb(wall_cache, cache)
    wallpaper_thumbnail_path.parent.mkdir(parents=True, exist_ok=True)
    wallpaper_thumbnail_path.unlink(missing_ok=True)
    wallpaper_thumbnail_path.symlink_to(thumb)

    scheme = get_scheme()

    if scheme.name == "dynamic" and not no_smart:
        smart_opts = get_smart_opts(wall_cache, cache)
        scheme.mode = smart_opts["mode"]
        scheme.variant = smart_opts["variant"]

    scheme.update_colours()
    apply_colours(scheme.colours, scheme.mode)

    cfg = get_config().get("wallpaper", {})
    if post_hook := cfg.get("postHook"):
        subprocess.run(
            post_hook,
            shell=True,
            env={
                **os.environ,
                "WALLPAPER_PATH": str(wall),
                "SCHEME_NAME": scheme.name,
                "SCHEME_FLAVOUR": scheme.flavour,
                "SCHEME_MODE": scheme.mode,
                "SCHEME_VARIANT": scheme.variant,
                "SCHEME_COLOURS": json.dumps(scheme.colours),
                "THUMBNAIL_PATH": str(thumb),
            },
            stderr=subprocess.DEVNULL,
        )

def set_random(args: Namespace) -> None:
    wallpapers = get_wallpapers(args)

    if not wallpapers:
        raise ValueError("No valid wallpapers found")

    monitor = getattr(args, "monitor", None)

    try:
        last_wall = get_wallpaper(monitor)
        if last_wall:
            wallpapers.remove(Path(last_wall))

        if not wallpapers:
            raise ValueError("Only valid wallpaper is current")
    except (FileNotFoundError, ValueError):
        pass

    set_wallpaper(random.choice(wallpapers), args.no_smart, monitor)
