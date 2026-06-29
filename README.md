<div align="center">

<img src="docs/images/logo.png" width="128" alt="Docky logo">

# Docky · Pero122 fork

### A multi-monitor fork of [Docky](https://github.com/josejuanqm/docky), the macOS Dock replacement.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/macOS-14%2B-black?logo=apple)](#installing)
[![Fork of](https://img.shields.io/badge/fork%20of-josejuanqm%2Fdocky-purple?logo=github)](https://github.com/josejuanqm/docky)
[![Build from source](https://img.shields.io/badge/install-build%20from%20source-orange)](#installing)

</div>

> [!IMPORTANT]
> **This is a personal fork, not the official Docky.** It exists to put a dock on
> **every monitor** and to reshape the layout/drag behavior (see
> [What this fork adds](#what-this-fork-adds)). There is no notarized download and
> no Homebrew cask — you **build it from source** (or copy a build from a Mac that
> has Xcode), and **auto-update is disabled on purpose** so the fork can't replace
> itself with the upstream build.
>
> For the official, notarized, supported app, go to
> [getdocky.com](https://getdocky.com) or
> [josejuanqm/docky](https://github.com/josejuanqm/docky).

<div align="center">
  <img src="docs/images/hero.jpg" alt="Docky on macOS" width="900">
</div>

## What this fork adds

Everything upstream Docky does ([feature tour below](#inherited-features)), plus:

- **A dock on every display.** One dock per monitor (`.allDisplays` mode), with
  live re-sync when you hot-plug a screen or change preferences.
- **Per-screen magnification.** Only the dock you're hovering magnifies (upstream
  drove every dock's magnification off one screen's pointer).
- **Drag-to-resize.** Drag the dock's outer edge to resize it live, complete with
  a proper ↕ resize cursor over the otherwise-inactive dock.
- **Drag any icon into any group.** Pinned / running / trailing are now one
  generic, tag-based section model — drag a tile anywhere and the placement
  sticks across restarts.
- **Move a window to the screen you clicked.** Click a window preview and that
  window is pulled onto the display whose dock you clicked.
- **Window-count dots.** One indicator dot per open window (1–3 → dots, 4+ → a
  rounded count).
- **"Allow app folders" toggle.** Turn folders off entirely and dissolve existing
  folders back into individual app tiles.
- **Security hardening.** Removed the `.dockywidget` native-bundle loader and the
  `docky://install-widget` deep link — upstream loaded community widget bundles as
  native code with library validation off, an RCE vector.
- **Auto-update disabled.** Sparkle auto-update is forced off (the fork's appcast
  still points at upstream, so an update would silently install the official build).

## Installing

Two ways in: build it yourself, or move a prebuilt app over if the target machine
has no Xcode.

### Option A — Build from source

Requirements: **macOS 14+** and **full Xcode 16 or later** (the Command Line Tools
alone can't build the scheme).

```sh
git clone https://github.com/Pero122/docky.git
cd docky
```

Upstream signs with a team that has no public certificate, so build ad-hoc:

```sh
xcodebuild -scheme Docky -configuration Release \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=YES DEVELOPMENT_TEAM="" \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO build
```

The `ARCHS` line is optional — it builds a universal (Apple Silicon + Intel) app,
handy if you'll copy it to a different Mac. Swift Package dependencies (Sparkle)
resolve on first build. You can also just open `Docky.xcodeproj` and build the
`Docky` scheme in Xcode.

### Option B — No Xcode? Move a prebuilt app over

You can't build this without full Xcode. If the machine you want it on — say a
work Mac — has no Xcode, build it **once** on a Mac that does, then move the
finished `Docky.app` across:

- **Easiest:** publish a build as a
  [GitHub Release](https://github.com/Pero122/docky/releases) (zip `Docky.app`,
  attach it), then download it on the other machine.
- **Or copy directly:** AirDrop, `scp`, or a USB stick the built `Docky.app`.

Build universal (the `ARCHS=…` line above) if the two Macs have different CPUs.

> [!CAUTION]
> The app is ad-hoc signed (no Apple Developer ID), so on a second Mac Gatekeeper
> blocks the first launch. Clear quarantine and open it manually:
> ```sh
> xattr -dr com.apple.quarantine /Applications/Docky.app
> open /Applications/Docky.app          # or right-click → Open the first time
> ```
> A **managed/corporate Mac** may refuse unsigned apps outright via MDM/Gatekeeper
> policy — if so there's no workaround short of proper Developer-ID notarization.

### Put it in place

Install to `/Applications` and run it from there — never from `DerivedData` or a
temp folder:

```sh
cp -R "$(xcodebuild -scheme Docky -showBuildSettings | awk '/BUILT_PRODUCTS_DIR/{print $3}')/Docky.app" /Applications/
xattr -cr /Applications/Docky.app
open /Applications/Docky.app
```

> [!WARNING]
> macOS **App Translocation** runs a quarantined ad-hoc app from a random
> read-only copy, which breaks resource loading and looks like a
> SwiftUI/AttributeGraph crash. Always copy to `/Applications`, `xattr -cr`, then
> launch from there.

Tip: for stable permission grants across rebuilds, sign with a local self-signed
cert named `Docky Local Self-Signed`
(`CODE_SIGN_IDENTITY="Docky Local Self-Signed" CODE_SIGN_STYLE=Manual`) instead of
ad-hoc — it avoids re-granting Accessibility / Screen Recording on every build.
(That cert lives in your keychain, so it only helps on the build machine; use
ad-hoc for copies you'll move elsewhere.)

Docky needs **Accessibility** and **Screen Recording** permissions; it prompts on
first launch.

### Make Docky your dock

To run Docky as a full replacement, hide the built-in macOS Dock so the two don't
fight for the same screen edge:

```sh
# Hide the native Dock: push it off-screen with a very long reveal delay
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 1000
killall Dock
```

Then in **Docky → Settings** enable **"Open at login"**. Docky manages its own
login item and removes external ones on launch, so use this toggle rather than
adding Docky in System Settings.

To restore the stock Dock later:

```sh
defaults delete com.apple.dock autohide-delay
defaults write com.apple.dock autohide -bool false
killall Dock
```

### Updating / reinstalling

Auto-update is off in this fork (Sparkle would replace it with the upstream
build), so you update by hand:

1. **Quit the running Docky first** — otherwise you're copying over a live app.
2. Rebuild (Option A) or grab the new prebuilt app, re-copy to `/Applications`,
   then `xattr -cr` and `open`.
3. If a settings change (e.g. a section layout) won't stick, quit Docky before
   editing its `gt.quintero.Docky` defaults — they're cached while it runs.

## Inherited features

These come straight from upstream Docky and are unchanged in the fork.

### Tiles and layout

Add and arrange anything in one strip: apps, widgets, Smart Stacks, folders,
spacers, and dividers. Pin what you reach for, drag to reorder, and let the
layout follow your workflow.

<div align="center"><img src="docs/images/feature-layout.jpg" alt="Tiles and layout" width="820"></div>

### Window switcher, live

A global, Cmd-Tab-style window switcher with live window previews, plus per-tile
hover previews so you can see a window before you raise it.

<div align="center"><img src="docs/images/feature-window-switcher.jpg" alt="Live window switcher" width="820"></div>

### Built-in Launchpad

A fullscreen, searchable app launcher with full keyboard navigation, its own
layout, and an optional global shortcut.

<div align="center"><img src="docs/images/feature-launchpad.jpg" alt="Built-in Launchpad" width="820"></div>

### Widgets in the dock

Built-in widgets (Calendar, Reminders, Batteries, System, Weather, Now Playing,
and more) live right in the dock. Stack several into a single tile with **Smart
Stacks** and cycle through them in place.

<div align="center"><img src="docs/images/feature-widgets.jpg" alt="Widgets and Smart Stacks" width="820"></div>

### Rich app folders

Group apps into folders with nested navigation, Quick Look, and drag-and-drop.
Optionally show running apps inline so a folder doubles as a live workspace. (This
fork can also disable folders entirely — see [What this fork adds](#what-this-fork-adds).)

<div align="center"><img src="docs/images/feature-folders.jpg" alt="Rich app folders" width="820"></div>

### More

- **Custom app icons:** override the icon for any pinned, running, or
  widget-backed app.
- **Scripted actions:** catalog-backed AppleScript and menu-click automation,
  plus curated commands.
- **Themes and profiles:** themeable appearance and switchable configuration
  profiles.

> [!NOTE]
> Docky uses private SkyLight / CoreGraphics Services and Accessibility SPI (see
> `Docky/Private/`) to position windows, capture previews, and drive the system
> Dock. Because of this it **cannot be distributed on the Mac App Store** — it is
> built from source.

## Documentation

- [External widget bundles](docs/external-widgets.md): the `.dockywidget` bundle
  contract. Note this fork disables runtime loading of these bundles for security.

## Dependencies

- [Sparkle](https://github.com/sparkle-project/Sparkle): software update
  framework (BSD 3-Clause). Auto-update is disabled in this fork.

## License

[GNU General Public License v3.0](LICENSE). Copyright (C) 2026 Jose Quintero.
Fork modifications maintained by [Pero122](https://github.com/Pero122).
