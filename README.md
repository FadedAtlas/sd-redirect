<div align="center">

# SD Redirect

Move an Android app's `Android/data` and `Android/obb` folders to your SD card, without the app noticing.

[![Build](https://img.shields.io/github/actions/workflow/status/FadedAtlas/sd-redirect/build.yml?style=for-the-badge)](https://github.com/FadedAtlas/sd-redirect/actions)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=for-the-badge)](LICENSE)
[![Android](https://img.shields.io/badge/Android-11%2B-3DDC84?style=for-the-badge&logo=android&logoColor=white)](#install)
[![Root](https://img.shields.io/badge/APatch%20%7C%20KernelSU-module-555555?style=for-the-badge)](#install)

</div>

## What is this?

An APatch / KernelSU module for Android 11+ that moves an app's `Android/data` and `Android/obb` folders to your
SD card. The app keeps working as if its files were still on internal storage. Handy for big games that don't let
you pick where their data goes.

Works with exFAT and FAT32 cards set up as portable storage (not adopted).

## Install

1. Download the zip from [Releases](https://github.com/FadedAtlas/sd-redirect/releases), or
   [build it yourself](#building).
2. Install it in your root manager and reboot. On APatch, use the **APM** tab, not KPM, and make sure
   AndroidPatch is installed first (the home screen must not say "Not installed").

## Using it

Open the WebUI from the module card in APatch or KernelSU.

To move an app, pick it from the list and choose:

- **Redirect & move data** copies the app's data to the SD card, checks the copy, deletes the internal copy and
  turns on the redirect. If anything goes wrong, the app stays on internal storage.
- **Redirect only** turns on the redirect without copying. Use this when the data is already on the card, for
  example after reinstalling the module.

A redirected app shows a toast when you launch it: `SD Redirect: <app name> runs from SD card`.

To undo it, use **Stop redirect**. You can then move the data back to internal storage, or leave it on the card
so you can redirect the app again later without copying.

Apps whose data this module put on the card get a small SD card icon in the list, even after you stop the
redirect.

The cogwheel opens Settings, where you can switch the mode, view or save the log and diagnostics, and clear all
module data.

## What it protects you from

- **Missing SD card.** Each app is tied to the card it was moved to. If that card isn't inserted, the app is
  closed on launch and you get a message. It never starts on an empty internal folder, so it can't overwrite
  your cloud saves with a fresh install.
- **File names the card can't store.** exFAT and FAT don't allow some characters (`" * : < > ? | \`), names
  ending in a dot, or two names that differ only in case. FAT32 also can't hold files of 4 GB or more. The
  module checks for all of this before moving anything.
- **Bad copies.** After copying, it compares both sides file by file before deleting anything. If they don't
  match, the copy on the card is removed and the app stays on internal storage.
- **Interruptions.** You can cancel a move at any time before the internal copy starts being deleted. If the
  phone reboots mid-move, the module cleans up on the next boot.
- **The app running during a move.** It is kept closed until the move finishes.
- **Overwriting data on the card.** If the app already has data on the SD card, you are asked before it's
  replaced. You are asked twice if the card copy is noticeably bigger than the internal one.

## Modes

| Mode | How it works | Trade-off |
|------|--------------|-----------|
| **Per-app** (`ns`, default) | Sets up the redirect each time the app starts. | Touches nothing else on the system, but there's a tiny chance the app reads its folder a few milliseconds too early. |
| **Global** | Sets it up once at boot for all apps. | No timing issue, but it's experimental. |

## New OBB files from the Play Store

In Per-app mode, when the Play Store downloads or updates a game's OBB files, they land on internal storage,
where the game can't see them. The module notices, sends a notification, and shows a **Move new OBB to SD**
button on the app's card. It moves just the new files and deletes the old versions they replace.

## Command line

You can do everything from a root shell too. The command isn't on `PATH`, so set up an alias first:

```sh
alias sd-redirect='sh /data/adb/modules/sd-redirect/bin/sd-redirect'
sd-redirect add com.example.game                   # redirect the app (pins it to the current SD card)
sd-redirect check com.example.game                 # list files the SD card can't store
sd-redirect migrate com.example.game --delete      # move the data to the SD card
sd-redirect migrate-back com.example.game          # move it back and stop the redirect
sd-redirect migrate-obb com.example.game           # move new Play Store OBB files to the SD card
sd-redirect cancel com.example.game                # cancel a running move
sd-redirect remove com.example.game                # stop redirecting (data stays on the card)
sd-redirect status                                 # what's running and what's redirected
sd-redirect set-mode global                        # switch between ns and global
sd-redirect reset                                  # undo everything and start fresh (app data stays)
sd-redirect log                                    # show the log
sd-redirect diag                                   # info for bug reports
```

Add `--replace` to `migrate` or `migrate-back` to overwrite a folder that isn't empty, and `--bg` to run it in
the background (check on it with `sd-redirect progress <pkg>`).

The config lives in `/data/adb/sd-redirect/config`. It's created from `module/config.default` on first install
and kept across updates.

## Good to know

- Only the app itself sees its files on the SD card. If another app (a file manager, say) copies files into the
  app's folder, they end up on internal storage. For OBB files the module offers to move them, as described
  above.
- Files the app creates after the move still have to follow the exFAT naming rules. If an app uses odd file
  names, those writes can fail.
- Uninstalling the app or clearing its data also wipes its folder on the SD card.
- **Stop redirect → Keep on SD card**, `remove` and `reset` leave the data on the card. Until you redirect the
  app again, it starts with an empty internal folder.
- Only the main Android user is supported.

If something breaks, run `sd-redirect diag` (or use **Save to Download** under Diagnostics in Settings) and
send me the output.

## Building

```powershell
./build.ps1      # Windows
```
```sh
bash build.sh    # Linux / macOS (needs zip or python3, and curl or wget)
```

The zip ends up in `dist/`. If a JDK is installed, the build also compiles the small helper that shows toasts.
Without one, the module falls back to notifications.

CI builds the zip on every push and pull request. Pushing a `v*` tag that matches `version=` in
`module/module.prop` publishes a GitHub release with the zip attached.

## Project structure

```
sd-redirect/
├── .github/
│   └── workflows/
│       └── build.yml            # builds the zip, publishes releases on v* tags
├── module/                      # zipped together with LICENSE and README.md
│   ├── bin/
│   │   └── sd-redirect          # the CLI that does all the work
│   ├── webroot/
│   │   └── index.html           # WebUI
│   ├── action.sh                # module action button (prints status)
│   ├── config.default           # default config, copied on first install
│   ├── customize.sh             # install script
│   ├── module.prop              # module id and version
│   └── service.sh               # starts the redirects at boot
├── toast/
│   └── SdRedirectToast.java     # launch toast helper, compiled to dex if a JDK is present
├── build.ps1
├── build.sh
├── LICENSE
└── README.md
```

## License

Copyright (C) 2026 FadedAtlas

SD Redirect is free software: you can redistribute it and/or modify it under the terms of the
[GNU General Public License v3.0](LICENSE) as published by the Free Software Foundation.

### Additional terms (GPL-3.0 section 7(b))

Modified versions, and works that include SD Redirect or parts of it, must keep the attribution
"SD Redirect by FadedAtlas". It can be shown anywhere, for example in the app, its description, the README or
the legal notices, as long as it stays with the work.
