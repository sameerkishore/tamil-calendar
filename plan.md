# Rasi Palan — Tear‑off Desktop Calendar for macOS

A native Apple Silicon macOS app that recreates the South Indian daily tear‑off calendar
(the *Rasi Palan* / daily *Panchangam* block that hangs on the wall). The date only moves
forward when **you** tear the sheet off with the mouse.

---

## 1. The experience (what you'll see and do)

1. **The calendar pad** sits on your desktop all the time — a borderless, always‑there
   window that looks like a thick block of paper sheets hanging from a nail, with the
   current (un‑torn) date on top.
2. **Tearing**: you grab the top sheet and drag it down/sideways. The sheet bends along the
   perforation at the top, follows your mouse, and if you pull far enough it rips free with
   a paper‑tear sound. Let go too early and it snaps back.
3. **Floating sheet**: the torn sheet becomes its own little floating window you can drag
   around anywhere on the desktop. It stays there until you deal with it.
4. **Crumple**: click the floating sheet → it crumples into a paper ball (animation +
   crumpling sound).
5. **Trash can**: as soon as a ball exists, a small waste‑paper bin appears on the desktop.
   Drag/fling the ball toward it → it arcs in with a toss + "thunk" sound. Miss, and the
   ball just lands on the desktop and you can try again.
6. **Bin fills up**: the bin visibly fills (balls pile up above the rim). When it's full it
   overflows / wobbles; click it (or right‑click → *Empty*) to empty it, with an emptying sound.
7. **Templates**: a gallery (from the menu bar) lets you preview and choose different card
   layouts for the date sheet.

The date is **never** advanced automatically. If you skip three days, you tear three sheets.
(A "behind by N days" hint can optionally show as a small badge.)

**First launch:** the pad starts at the installing user's current local date, whatever day
they install it. From then on only tearing moves it.

---

## 2. What a date card shows

### Reference: your home calendar

The reference photo is saved at [docs/reference/home-calendar.jpg](docs/reference/home-calendar.jpg).
The **Classic** template follows its anatomy closely:

```
┌──────────────────────────────────────────────┐  ← red binding strip, staples, torn stubs of past sheets
│ அக்டோபர் 2026   ♛          │   பராபவ            │  English month (Tamil script) · publisher mark · Tamil year
│                             │   புரட்டாசி          │  Tamil month
│ [icon]  ███ 15 ███         │     28            │  BIG Gregorian date   │  Tamil date
│          THU                │   வியாழன்          │  English weekday       │  Tamil weekday
├──────────────────────────────────────────────┤
│ பஞ்சமி நள்ளிரவு கடந்து 3.10 வரை   கேட்டை நாள் முழுவதும் │  Tithi + end time · Nakshatram + end time
│                 சித்த யோகம்                    │  Yogam (Siddha / Amirtha / Marana)
│ temple festivals / special observances (2–3 lines)  │
│ ராகு 1.30-3  குளிகை 9-10.30  எமகண்டம் 6-7.30      │  Timings
│ birthdays / notable days ; சந்திராஷ்டமம் ; …      │  Chandrashtamam star
│ ↔ சமநோக்கு நாள்        நல்ல நேரம்: 10.30-11 1-1.30   │  Day direction (in red), good times
└──────────────────────────────────────────────┘
```

What we copy from it: the two‑column top (Gregorian left, Tamil right, vertical rule), the
heavy condensed serif numerals, crowded tiny Tamil text at the bottom, red only for accents,
**ghosts of the next sheet's numbers showing through**, and ragged stubs of torn sheets at the
binding.

What we deliberately **don't** copy: the publisher's brand name/logo (we make our own small
mark) or any real person's portrait. That photo slot becomes a small printed‑style
**icon of the day** (lamp, kolam, festival symbol).

### Card content

| Area | Content |
|---|---|
| Top‑left | English month + year (in the card language), small publisher‑style mark |
| Top‑right | Tamil year name (60‑year cycle, e.g. 2026–27 = *Parabhava* / பராபவ), Tamil month |
| Big centre | Gregorian date number + weekday │ Tamil date number + Tamil weekday |
| Panchangam | Tithi and Nakshatram with end times ("…நள்ளிரவு கடந்து 3.10 வரை"), Yogam |
| Observances | Festivals, ekadasi/amavasai/pournami, Karthigai, Sashti, etc. |
| Timings | Rahu Kalam, Kuligai, Yamagandam, Nalla Neram, Chandrashtamam, Soolam/direction |
| Rasi Palan *(optional block)* | 12 rasis with a one‑line daily prediction each (off on Classic, on in Detail) |
| Extras *(optional blocks)* | Sunrise/sunset, thought for the day, later weather, to‑dos, events |

**Panchangam style** (setting; implemented in M2):
- **Traditional (Vakyam)**, the default, matches printed Tamil Nadu calendars. Tamil months use the
  Surya Siddhanta Sun reckoned for Tamil Nadu (with a −2.3 h calibration fitted to 36 published
  month starts for 2025–27: 36/36 match). Rahu Kalam uses the fixed printed times (Thursday 1.30–3).
- **Precise (Thirukanitham / drik)** uses the true sky for the user's location. Months come from the
  modern sidereal Sun (Lahiri) and local sunset, and timings are eighths of the actual sunrise–sunset day.
- The two differ by a day at some month starts. For example, Purattasi 2026 starts on 18 Sept
  (Traditional) or 17 Sept (Precise).

**Data strategy (phased so we're not blocked on astronomy):**
- **Phase A** — compute what's purely arithmetic and exact: weekday, Rahu/Yama/Kuligai
  (fixed weekday slots on a sunrise–sunset day), Tamil month & solar day (from sun's
  sidereal longitude), Tamil year cycle (60‑year cycle).
- **Phase B** — compute Tithi & Nakshatram from Sun/Moon longitudes using a compact
  astronomical algorithm (Meeus‑style), with sunrise/sunset for **the user's own location**.

**Location:** everything is calculated on the device, with no web service needed.
1. Ask for Location permission once (Core Location; city‑level accuracy is enough).
   Reverse‑geocode the location to show the city name on the card.
2. If the user declines or is offline: fall back to the system time zone's main city
   (built‑in table of roughly 400 cities with lat/long), and offer a "Choose city…" search in Settings.
3. Store the coordinates and only update them when the user moves a noticeable distance.
   A sheet's timings are fixed when that sheet becomes the top of the pad.
- **Rasi Palan text** — generated locally from a curated phrase bank seeded by the date
  (deterministic, so a given day always reads the same). Clearly for fun, not real astrology.
  Optionally later: user‑supplied JSON pack.

---

## 3. Languages

Card language is a setting with a **`Localization` layer**, so text is never hard‑coded
in templates:
- **Tamil + English** (default): mixed, the way the real calendars print it
- **Tamil only**
- **English only**
- Designed so Telugu / Kannada / Malayalam / Hindi packs can be added later (the panchangam
  terms are the same; only the month system and strings differ). We'll do Tamil and English first.

Fonts are bundled: Noto Serif Tamil / Catamaran (Tamil), plus a condensed slab‑serif for
English numerals.

---

## 4. Templates & modular layout

Cards are **built from blocks, not drawn as fixed screens**. This is what makes future user
customisation possible.

```
CardLayout  =  paper style  +  ordered list of slots (regions)  +  block placed in each slot
```

- **`CardBlock` protocol**: each block is a self‑contained SwiftUI view with an `id`,
  display name, the sizes it supports (small / wide / full), and a `render(context:)`
  that gets a `DayContext` (date, panchangam, location, language, and later any user data).
- **Built‑in blocks (v1):** Header (Tamil year/month), BigDate, Weekday, PanchangamStrip,
  Timings (Rahu/Yama/Kuligai/Nalla Neram), RasiPalanTable, Festival, SunriseSunset,
  ThoughtOfTheDay, DecorativeArt.
- **Future blocks (stubbed now, built later):** Weather, To‑do list (static text),
  Today's events (static text from Calendar/EventKit), Custom note. When a sheet becomes the top
  of the pad, its content is **frozen** (snapshotted into the sheet), so it reads like printed paper.
  Yesterday's sheet never changes.
- **Layouts are data (JSON)**, not code. Each template is a JSON file listing slots and blocks.
  So a future "Customise layout" editor only has to edit JSON: drag blocks into slots,
  remove them, reorder them.
- A **`BlockRegistry`** maps block ids to implementations, so new blocks (weather etc.) plug in
  without touching templates.

**Shipped templates** (all JSON layouts using the block system), chosen in a **Template
Gallery** with live previews:
1. **Classic**: modelled on your home calendar (above). Black on thin white newsprint,
   red accents, two‑column top, dense Tamil footer.
2. **Minimal**: big number, weekday, Rahu Kalam.
3. **Panchangam Detail**: dense grid, all timings, the full 12‑rasi table.
4. **Modern Dark**: dark stock and one accent colour.

---

## 5. The "cheap printed paper" look

The goal is that it looks like a ₹40 calendar block from a Sivakasi press, not a glossy app.
These are applied as a **paper style layer** on top of any template, so every template gets them:

- **Newsprint stock**: off‑white/yellowed base, procedural paper‑fibre noise, and a faint
  uneven tint toward the edges. Sheets lower in the pad look a little more yellow.
- **Limited ink**: 2‑colour printing (red + black, sometimes one spot colour). No gradients.
- **Ink imperfections**: slight **misregistration** (the red plate offset 0.5–1 px from black),
  ink spread/bleed on large type, small dropouts/speckles, uneven ink density.
- **Halftone**: images and tints use a coarse dot screen, not smooth fills.
- **Thin paper**: faint **show‑through** of the next day's big number from behind, visible as a
  mirrored ghost.
- **Physical details**: a perforated top edge with a jagged tear line on torn sheets, the
  bound/stapled stub at the top of the pad, a pad thickness that shrinks through the year, and slight
  curl at the bottom corners.
- **Per‑sheet randomness** seeded by the date, so every day's print flaws are different but stable.

Implemented as a Metal post‑process shader over the rendered card (noise, offset, halftone,
show‑through). The card content stays crisp SwiftUI underneath.

---

## 5b. Backing board (optional)

In your photo the pad is stapled to a printed board with deity art, a temple scene and the
year in big type. This is an **optional extra** in our app:

- **Off**: just the pad with its red binding strip (a compact desktop object).
- **On**: the pad is mounted on a board, with a nail/hole at the top.
- **Board designs** (all original art I design, in the same cheap glossy‑print style with slightly
  oversaturated colours, visible print grain and rounded worn corners):
  1. Temple gopuram and tank scene, with a big year number on a coloured band
  2. Kolam and lamp (kuthu vilakku) pattern
  3. Plain coloured board with the year only
  4. **Your own image**: drop in any picture (e.g. a photo of your family deity). The app crops it to
     the board and applies the same print‑grain treatment so it matches.
- The board is a separate layer under the pad, so tearing, scaling and dragging all behave the same with it on or off.

## 5c. Scaling

The whole object can be scaled from **50% to 250%**:
- With **⌘ + scroll** or **pinch** over the pad, a resize handle on hover at the bottom‑right
  corner, or a menu slider/presets (S / M / L / XL).
- Everything is drawn as vectors plus resolution‑independent shaders, so it stays crisp at any size
  and on Retina displays. The paper grain is scaled so it keeps looking like paper, not a pixel grid.
- Torn sheets, balls and the bin use the pad's scale by default. Each torn sheet can also be
  resized on its own.
- Scale is saved per display.

---

## 6. Technical design

**Stack:** Swift 6, SwiftUI for card content, AppKit for windows and desktop behaviour,
Metal shaders for paper, curl and crumple effects, AVFoundation for sound, Core Location for
the user's location. Target: macOS 14+, Apple Silicon (arm64).

**Build:** an **Xcode project** (generated from a small `project.yml` with XcodeGen, so the
project file stays readable and easy to merge). We need full Xcode because SwiftUI's
`.layerEffect`/`.distortionEffect` shaders must be compiled into a `.metallib`, and the
`metal` compiler only ships with Xcode. Command Line Tools alone can't do it. See §9.

### Windows (all borderless, transparent, no title bar)

| Window | Level / behaviour |
|---|---|
| `PadWindow` | Desktop level (above wallpaper/icons, below normal apps), on all Spaces, remembers position |
| `SheetWindow` (one per torn sheet) | Floating, draggable, shadowed |
| `BallWindow` (one per ball) | Floating, draggable / flickable with physics |
| `TrashWindow` | Appears when first ball exists, draggable, remembers position |
| `TemplateGalleryWindow`, `SettingsWindow` | Normal windows from menu bar |

App runs as a **menu‑bar accessory** (no Dock icon). The menu has: Templates…, Language,
Location (Automatic / Choose city…), Sound on/off, Show pad, Launch at login, Quit.

### Key mechanics

- **Tear interaction**: a custom `NSView` tracks the mouse drag. A page‑curl deformation is
  pinned at the perforation (Metal distortion shader). The sheet tears off once the drag passes a
  distance‑and‑velocity threshold. The perforation then "unzips" left→right, leaving a jagged
  edge, and the sheet detaches into a `SheetWindow` at its exact screen position.
- **Crumple**: the sheet is rendered to an image and animated through a crumple shader
  (noisy displacement, shrink, crease shading). It ends as a ball sprite with that sheet's ink baked in.
- **Toss physics**: on mouse‑up the app takes the release velocity and runs a 2D projectile
  with gravity in screen space, moving the `BallWindow` each frame. The bin mouth is hit‑tested:
  a hit plays the drop‑in animation, and a miss lands and rests at the bottom of the screen.
- **Trash**: holds about 10 balls. Visual states go empty → some → full (balls above the rim) →
  overflowing (wobble). Click or right‑click → Empty plays a tip‑out animation and resets the count.
- **Persistence** (`~/Library/Application Support/RasiPalan/state.json`): the current pad date,
  pad and bin positions, floating sheets and balls (with their frozen content), bin count,
  layout/template, language and location. After quit and relaunch, everything is where you left it.
- **Sounds**: free **CC0** clips (public domain, no attribution needed). Sources:
  freesound.org (CC0 filter), Kenney.nl audio packs, Sonniss GDC bundles (royalty‑free).
  Sounds needed: tear ×3, crumple ×3, whoosh, bin thunk ×2, rim bounce, bin empty. Each play picks a
  random variant with slight pitch variation via `AVAudioEngine`. I'll keep a `CREDITS.md`
  recording the source and licence of every clip.

### Project layout

```
rasi-palan/
  project.yml                  XcodeGen spec → RasiPalan.xcodeproj
  RasiPalan/
    App/            AppDelegate, MenuBarController, AppState, Settings
    Windows/        PadWindow, SheetWindow, BallWindow, TrashWindow, Gallery, Settings
    Interaction/    TearGesture, TossPhysics, HitTesting
    Effects/        Paper.metal (newsprint/misregistration/halftone), PageCurl.metal, Crumple.metal
    Calendar/       DayContext, TamilCalendar, Panchangam, Astronomy, RasiPalanGenerator
    Location/       LocationProvider (CoreLocation + fallback city table)
    Localization/   Strings (ta, en, ta+en), number & date formatting
    Cards/
      Blocks/       CardBlock protocol, BlockRegistry, built‑in blocks (+ stubs for future ones)
      Layouts/      CardLayout model, JSON loader, renderer
    Audio/          SoundPlayer
    Persistence/    StateStore
    Resources/      Sounds/, Fonts/, Art/, Layouts/*.json, cities.json
  Tests/            calendar/panchangam tests against known published dates
  CREDITS.md        sound & font licences
```

---

## 7. Milestones (what we'll do together)

Each milestone ends with something you can run and play with. Tell me what feels off.

| # | Milestone | You'll be able to… |
|---|---|---|
| **M1** | Skeleton: Xcode project, menu‑bar app, desktop‑level pad window showing a placeholder card | See the pad on your desktop, move it, quit from the menu bar |
| **M2** | Calendar core plus location: `DayContext`, first‑launch date, persistence, Tamil month and year, weekday, sunrise/sunset and Rahu/Yama/Kuligai for your location | See correct info for your city; the date never changes on its own |
| **M3** | Block system, paper look and scaling: `CardBlock`, JSON layouts, Classic template (matched to your reference), newsprint shader, Tamil+English strings, resize 50–250% | A sheet that looks like the one on your wall, at any size |
| **M4** | Tearing: drag, curl, snap‑back, tear‑off, floating `SheetWindow`, tear sounds | Tear sheets off; the pad advances one day per tear |
| **M5** | Crumpling: click a sheet → crumple animation and sound → ball | Turn sheets into balls |
| **M6** | Trash and tossing: bin appears, flick physics, hit/miss, fill states, empty action, sounds | Play paper basketball and empty the bin |
| **M7** | Templates, languages and backing boards: 4 templates, Template Gallery, Tamil‑only and English‑only modes, optional boards + custom image | Switch the look and language, mount the pad on a board |
| **M8** | Panchangam accuracy: tithi, nakshatram, yogam, karanam, festivals; Rasi Palan phrase generator | A genuinely useful daily sheet |
| **M9** | Polish: launch at login, multiple displays and Spaces, settings, app icon, idle CPU ≈ 0 | Leave it running forever |
| *Later* | User layout editor and new blocks: weather, to‑do (static text), today's events (static text), notes | Customise your own sheet |

---

## 8. Decisions (settled)

| Topic | Decision |
|---|---|
| Card language | Tamil + English by default; Tamil‑only and English‑only as options; extensible to other languages |
| Location | User's own location via Core Location, with time‑zone city fallback and manual city search |
| Start date | The installing user's current local date on first launch |
| Sounds | Free CC0 clips, credited in `CREDITS.md` |
| Artwork | Designed by Claude (kolam/gopuram‑style decorative art in 2‑colour print style) |
| Layout | Modular blocks with JSON layouts, ready for future user customisation (weather, to‑dos, events) |
| Visual feel | Cheap Sivakasi newsprint: 2‑colour ink, misregistration, halftone, show‑through, perforations |
| Reference | User's home calendar (`docs/reference/home-calendar.jpg`); Classic template follows its anatomy, without copying brand or portraits |
| Backing board | Optional; original board designs + "use your own image" |
| Scaling | 50–250%, ⌘‑scroll / pinch / resize handle / menu; vector‑crisp |
| Panchangam style | Traditional (Vakyam, matches printed calendars) by default; Precise (Thirukanitham, true sky for your location) as option |

---

## 9. What you need to install

| # | What | How | Why |
|---|---|---|---|
| 1 | **Xcode** (latest, free) | Mac App Store → search "Xcode" → Get. About 10+ GB, so leave time. Open it once and let it install components. | Compiles the app and the Metal shaders. Right now you only have Command Line Tools, which can't compile Metal. |
| 2 | **Point the command line at Xcode** | `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` then `sudo xcodebuild -license accept` | So I can build from the terminal. These need your password, so you run them. |
| 3 | **Metal toolchain** (if not already included) | `xcodebuild -downloadComponent MetalToolchain` | Newer Xcode versions ship the Metal compiler as a separate download. |
| 4 | **XcodeGen** | `brew install xcodegen` (you already have Homebrew) | Generates the Xcode project from a readable `project.yml`. |

That's all. No accounts are needed: we'll ad‑hoc sign the app to run locally, so no paid Apple
Developer membership. Fonts and sounds are bundled in the repo, and Location permission is a
one‑time prompt when the app first runs.

Optional, any time: `git` is already there, so I'll initialise a repo so every milestone is a commit.

---

## 10. Out of scope (for now)

- Real professional astrology predictions or external horoscope APIs.
- iOS/iPad versions, widgets, iCloud sync.
- Mac App Store distribution (we'll run it locally, ad‑hoc signed).
