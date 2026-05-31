# Samajh — Visual Design System

## Identity

Samajh is a dark-mode-first product. It is not a language-learning tool, productivity tool, AI chatbot, or music player. It is an emotional understanding experience built around music, poetry, and meaning.

> The visual identity should feel like listening to a song alone at night and finally understanding what it is trying to say.

**Keywords:** intimate · reflective · cinematic · literary · warm · timeless · immersive

**Avoid:** gamification · educational aesthetics · productivity tooling · bright startup visuals · Spotify clones · AI assistant aesthetics

---

## Theme Philosophy

Dark mode is the canonical Samajh experience. All primary design decisions are made in dark mode first.

Light mode is a secondary adaptation — it should feel like reading poetry on warm paper, not a color inversion.

---

## Color Tokens

All `samajh*` colors in `DesignSystem.swift` use `UIColor(dynamicProvider:)` and adapt automatically to the system appearance.

### Backgrounds

| Token | Dark | Light |
|---|---|---|
| `samajhBackground` | `#000000` | `#F7F3EC` |
| `samajhBackgroundSecondary` | `#0E0E11` | `#F2EEE7` |
| `samajhSurfaceElevated` | `#151518` | `#EDEAD2` |
| `samajhSurfaceCard` | `#1B1B20` | `#FFFFFF` |

The app should remain predominantly dark with strong contrast and generous negative space.

### Accent Gold

| Token | Dark | Light |
|---|---|---|
| `samajhGold` | `#D6A05F` | `#B88952` |
| `samajhGoldMuted` | `#B88952` | `#A07543` |
| `samajhGoldPressed` | `#E3B16D` | `#C89960` |

The accent should feel like candlelight or warm evening light. Use sparingly.

**Allowed:** active states · selected tabs · playback progress · focused lyric lines · important actions
**Avoid:** large areas of gold · decorative fills · backgrounds

### Text

| Token | Dark | Light |
|---|---|---|
| `samajhTextPrimary` | `#F5F2EB` | `#2B2B2B` |
| `samajhTextSecondary` | `#B8B1A7` | `#5A5752` |
| `samajhTextMuted` | `#7E7A73` | `#7E7A73` |
| `samajhTextDisabled` | `#5A5752` | `#A09C98` |
| `samajhTextRoman` | `#C8C1B7` | `#6B6863` |

The interface should prioritize readability and comfortable long-form reading.

### Accent Color Asset

`AccentColor.colorset`: `#D6A05F` dark / `#B88952` light — drives system controls (buttons, toggles, links).

---

## Typography

### UI Font: Inter

Use for: navigation · controls · translations · metadata · settings · flashcards

| Constant | Weight | Usage |
|---|---|---|
| `SamajhFont.interRegular` | 400 | Body, romanization, translations |
| `SamajhFont.interMedium` | 500 | Subtitles, chips |
| `SamajhFont.interSemiBold` | 600 | Song titles, nav bar title |
| `SamajhFont.interBold` | 700 | Hero title in LyricsView header |

### Native Script Fonts

| Language | Font | Constant |
|---|---|---|
| Hindi | Noto Serif Devanagari | `SamajhFont.notoDevanagari` |
| Urdu | Noto Nastaliq Urdu | `SamajhFont.notoNastaliq` |
| Bangla | Noto Serif Bengali | `SamajhFont.notoBengali` |

Original lyrics must always feel elegant and respected. Native script text should visually dominate translation layers.

### Accent Serif: Cormorant Garamond

**Use only for:** onboarding headlines · empty states · featured lyric moments · editorial pull quotes

**Never use for:** navigation · settings · translations · flashcards · body content · long reading

**Target:** less than 10% of visible typography.

### Font Scale (LyricsView)

| Layer | Font | Size | Color |
|---|---|---|---|
| Native lyric | Noto Serif (script-matched) | 36pt | `samajhTextPrimary` |
| Romanization | Inter Regular | 19pt | `samajhGold` |
| Word-by-word | Inter Regular | 14pt | `samajhTextMuted` |
| Direct translation | Inter Regular | 20pt | `samajhTextSecondary` |
| Natural translation | Inter Regular | 22pt | `samajhTextPrimary` |

---

## Navigation Pattern

### Collapsing Header (LyricsView)

- Content header: album art (64pt) + title (Inter Bold 22pt) + artist (Inter Regular 15pt)
- Navigation bar title is **hidden** when the content header is visible
- As the user scrolls and the header exits the nav bar zone (~100pt from top of screen), the nav bar title fades in with a 220ms ease-out
- Implemented via `TitleVisibilityKey: PreferenceKey` tracking the header's global `maxY`
- `.principal` ToolbarItem drives the nav bar title; `.navigationTitle()` is retained for back-button behavior in child views

---

## Spacing

The application should feel calm and spacious.

- Generous vertical rhythm
- Large margins (24pt horizontal standard)
- Low information density
- Text should breathe
- Users should never feel rushed

### LyricsView Rhythm

- Section spacing: 40pt between lyric lines
- Internal lyric row spacing: 10pt between layers
- Native script line spacing: 8pt
- Natural translation line spacing: 4pt
- Horizontal padding: 24pt
- Bottom padding: 48pt (chip bar clearance)

---

## Motion

Motion should be subtle and nearly invisible.

| Token | Duration | Curve |
|---|---|---|
| `SamajhMotion.standard` | 280ms | easeInOut |
| `SamajhMotion.slow` | 350ms | easeInOut |
| `SamajhMotion.fade` | 220ms | easeOut |

**Use:** fades · opacity transitions · gentle movement
**Avoid:** bounce effects · exaggerated springs · flashy interactions

---

## Shape

| Token | Radius |
|---|---|
| `SamajhRadius.card` | 24pt |
| `SamajhRadius.button` | 14pt |
| `SamajhRadius.small` | 10pt |

---

## Lyrics Experience

The lyrics screen is the emotional center of the product.

**Priority order:**
1. Original lyric
2. Meaning
3. Navigation

Not controls, buttons, or features.

The currently selected lyric or meaning layer should feel gently illuminated — not aggressively highlighted.

---

## Product Feeling

> "Someone is helping me understand a song I already love."

Not: "I am completing a language exercise."

Every design decision should reinforce emotional understanding, reflection, and connection to music.
