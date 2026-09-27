# caelestia-zeti

Per-monitor wallpapers, video wallpapers and per-monitor colours for [Caelestia](https://github.com/caelestia-dots/shell), plus a lock screen settings page.

## What it does

**Each monitor gets its own wallpaper.** Set one on your left screen and your right screen keeps its own. Set a wallpaper for all monitors and they all follow it again.

**Each monitor gets its own colours.** A monitor's wallpaper decides the colours of the bar, drawers, launcher, settings and lock screen *on that monitor*. Monitors without their own wallpaper use the normal shared colours.

**The launcher only affects the screen it's open on.** Browsing wallpapers previews them on that screen only — the others stay as they are. Picking one applies it there.

**Video wallpapers.** Use a video as your wallpaper — `mp4`, `mkv`, `webm`, `mov`, `m4v` or `avi`. They appear in the wallpaper picker alongside images, and colours are pulled from them the same way. Each monitor can run a different video, or you can mix a video on one screen with a still image on another.

To keep them cheap, playback pauses while windows cover the wallpaper and while the screen is locked or off, and audio is muted. Change that in `~/.config/caelestia/live-wallpaper.json`:

```json
{
  "enabled": true,
  "muted": true,
  "pauseWhenObscured": true,
  "pauseWhenHidden": true,
  "playbackRate": 1
}
```

Set `enabled` to `false` to freeze videos on a single frame — you keep the look without the decoding cost.

**Panels fit whatever monitor they're on.** Ultrawide, portrait, small laptop screens — the bar, launcher, dashboard and lock screen size themselves to fit instead of overflowing or looking lost. On a normal 1080p screen nothing changes.

**A lock screen page** in Settings → Panels → Lock Screen. Turn parts of the lock screen on and off (clock, profile picture, weather, system info, music, resources), add a note, and add commands whose output shows while locked.

### One thing it doesn't do

Regular apps — your terminal, GTK and Qt apps, Discord, browsers — still all share one colour scheme, taken from the wallpaper you set for all monitors. Only the Caelestia shell itself goes per-monitor, because an app window can be dragged between screens and there's no sensible answer for which monitor's colours it should use.

## Requirements

- [caelestia-shell](https://github.com/caelestia-dots/shell) and [caelestia-cli](https://github.com/caelestia-dots/cli)
- `python3`
- `ffmpeg`, if you want video wallpapers

Built against caelestia-shell 2.5.0 and caelestia-cli 1.1.3.

## Install

```sh
git clone https://github.com/IO-ZetZor/caelestia-zeti
cd caelestia-zeti
./install.sh
```

Then restart the shell:

```sh
qs -c caelestia kill && caelestia shell &
```

To see what it would change without changing anything:

```sh
./install.sh --dry-run
```

Your existing setup is backed up first, to `~/.local/state/caelestia-zeti/backups/`. Running the installer twice is harmless.

If it can't find your Caelestia install, point it at the right place:

```sh
./install.sh --shell-dir /etc/xdg/quickshell/caelestia
```

## Uninstall

```sh
./install.sh --uninstall
```

This puts everything back the way it was.

## Licence

MIT.
