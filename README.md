# Tamil Calendar

A tear-off South Indian daily calendar for the macOS desktop. The date only changes when you
tear the sheet off. Torn sheets lie on the desktop; click one to crumple it, then toss it in the bin.

## Run

```bash
./scripts/run.sh        # debug build, launches from build/
./scripts/install.sh    # release build into /Applications (use this for Open at Login)
./scripts/make_dmg.sh   # universal release build packaged as build/Tamil Calendar.dmg for sharing
```

Requires Xcode, its Metal toolchain, and XcodeGen (`brew install xcodegen`). The Xcode project is
generated from `project.yml`; run `xcodegen generate` to open it in Xcode.

## Layout

| Path | What |
|---|---|
| `Packages/RasiCore` | Calendar maths: Tamil calendar, sunrise/sunset, panchangam, festivals (`swift test`) |
| `RasiPalan/Cards` | Sheet rendering: blocks, JSON layouts, boards, theme |
| `RasiPalan/Effects/Newsprint.metal` | Print, paper, crumple and board shaders |
| `RasiPalan/Interaction` | Tearing and its settings |
| `RasiPalan/Personal` | Reminders, Calendar events (EventKit) and Open-Meteo weather for printed blocks |
| `RasiPalan/Windows` | Pad, floating sheets, paper balls, bin, settings and gallery windows |
| `RasiPalan/Resources/Layouts` | Templates as JSON |
| `scripts/make_sounds.swift` | Synthesises the paper sounds |
| `scripts/make_icon.swift` | Draws the app icon |

Debug builds accept `-snapshot out.png` (plus `-snapshotTemplates 1`, `-snapshotBoard temple`, …)
to render offscreen; see `RasiPalan/App/Snapshot.swift`.

## Credits

© 2026 Sameer Kishore. All rights reserved.

Made with ❤️ by Sameer (and Claude).
