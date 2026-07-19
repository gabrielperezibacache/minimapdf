# Minima PDF — Design System

## Company & product context

**Minima PDF** is an ultra-lightweight, 100% offline PDF reader and library manager built for professionals and academics who want to read and organize documents without subscriptions, cloud tracking, or AI bloat. It loads large documents instantly, ships an ultra-low-glare dark mode for long reading sessions, and is sold once for a flat $1.99 lifetime license — no recurring billing, no accounts.

Slogan: **"Read, organize, focus. Once."**

This design system draws on the visual language of technical, developer-tool "agent workbench" interfaces — a professional, low-glare dark aesthetic crossed with an editorial reading feel, tuned to reduce eye strain across long sessions.

## Sources

- GitHub: [gabrielperezibacache/minimapdf](https://github.com/gabrielperezibacache/minimapdf) — at the time this system was built, the repository contained only a placeholder `README.md` (no code, components, or assets committed yet). Nothing could be read from it beyond the repo name. **If/when the real app code lands there, re-run this design system against it** — the repo is the ground-truth source and should supersede the interpretations below (colors, spacing values, exact component behavior).
- Product brief supplied directly by the user: full color tokens, typography system, and visual rules for this dark, low-glare reading aesthetic (reproduced in `tokens/` below).
- No Figma file, screenshots, or slide deck were provided.

Because the repo was empty, every token, component, and screen here is built directly from the written brand brief — not reverse-engineered from real product code. Treat the UI kit as an original interpretation of the brief, not a pixel-accurate copy of a shipped app.

## What's in this project

- `styles.css` + `tokens/` — color, typography, spacing, radius, and motion custom properties, plus the font import.
- `guidelines/` — foundation specimen cards (Colors, Type, Spacing, Brand groups) shown in the Design System tab.
- `components/` — 15 reusable UI primitives grouped by concern: `forms/` (Button, IconButton, Input, Select, Checkbox, Radio, Switch), `feedback/` (Badge, Tag, Toast, Tooltip, ProgressBar), `navigation/` (Tabs), `overlay/` (Dialog), `surfaces/` (Card). Standard set — the empty repo defines no component inventory of its own, so a conventional set was sized to the app's needs (see "Intentional additions" below).
- `ui_kits/minima-pdf-app/` — interactive click-through recreation of the app: Library grid → Reader (three-panel: sidebar / document / tool drawer) → Settings dialog.
- `assets/` — no logo file was provided anywhere in the sources; none was invented (see Iconography below). `assets/icons/` holds the substituted icon set.
- `SKILL.md` — portable skill file for use in Claude Code.

### Intentional additions
No component library was defined by any attached source, so the standard primitive set above was authored from scratch, sized to what a PDF reader/library app needs (e.g. `ProgressBar` for reading position, `Tag` for document categories). None of these should be read as "the real Minima PDF components" — they're a reasonable starting set pending real source.

## Content fundamentals

- **Voice:** direct, confident, a little defiant about privacy and simplicity. Copy reads like a product built by someone allergic to bloat — short declarative sentences, no hedging.
- **Person:** speaks to "you" the reader/professional ("Your library", "Read, organize, focus."). Never "we're excited to announce."
- **Casing:** sentence case everywhere — headers, buttons, labels. No ALL CAPS, no Title Case Buttons.
- **No filler stats or fake urgency.** The pitch leans on concrete, verifiable claims (100% offline, $1.99 lifetime, instant load) rather than vague superlatives.
- **Emoji:** none. The brand's whole personality is "serious tool, not a consumer app" — emoji would undercut that immediately.
- **Example lines used in this system:** "Read, organize, focus. Once.", "No cloud sync. No accounts. 100% offline, always.", "Lifetime license · $1.99 — owned."

## Visual foundations

- **Palette:** near-black emerald-obsidian backgrounds (`#0F1714` canvas, `#121D18` sidebar, `#16211C` surface) with a single warm bronze/gold accent (`#C89A5A`) for anything interactive or "found" (active tabs, bookmarks, primary buttons). Text is warm parchment (`#F3ECDD`) on primary, muted sage (`#A8B4A5`) on secondary/metadata — never pure white or pure gray, which is what keeps the reading experience low-glare. A Light Canvas theme (`#F4EEE7` bg / `#121D18` ink) exists as an alternate reading mode, same accent.
- **Type:** Inter (or SF Pro/Roboto) for all UI chrome — bold, tight tracking (-0.02em) on headers, 1.5 line-height body. A separate editorial serif (Noto Serif / New York / Georgia) is reserved for document-adjacent content — metadata cards, page numbers, quoted notes — to give reading surfaces a tactile, paper feel distinct from the app chrome.
- **Elevation: zero shadows.** Every surface separation is a single 1px solid border (`#22342C`), never a blur/shadow. This is explicitly for rendering performance and to match the "fast, lightweight" positioning.
- **Corners:** sharp but not squared — 4px (small controls) to 8px (cards, dialogs) maximum. Never pill-shaped except true toggles/badges.
- **Layout:** three-panel structure on desktop (Sidebar 264px / Reader fluid / Tool Drawer 320px), collapsing to single/double-panel overlays on mobile.
- **Motion:** fast and linear — 80–100ms, no easing curves, no bounce, no fades-with-delay. Snappy, utilitarian.
- **Hover/press states:** flat color swaps only — hover lightens/tints background or border color (e.g. accent → lighter bronze), no scale, no shadow-lift. Active/pressed states darken toward `--bronze-600`.
- **Imagery:** none specified or provided — this is a text/document-first, chrome-heavy product with no photography, illustration, or gradient backgrounds in its visual language.
- **Transparency/blur:** used sparingly — only for scrims behind modal dialogs (`rgba(15,23,20,0.7)`), never for frosted-glass panels or chrome.

## Iconography

No icon codebase, sprite sheet, or icon font was available in the attached repo. Icons throughout the components and UI kit are **substituted with a Lucide-style stroke set** (1.75px stroke, no fill, 24×24 grid) — the closest CDN-available match to the thin, technical line-icon style implied by a developer-tool aesthetic like the Hermes WebUI. This is a flagged substitution: if the real app ships its own icon set, replace these before shipping anything derived from this system. No emoji or unicode-glyph icons are used anywhere in the system.

## Missing assets — please help

- **No logo file was in any attached source.** At the user's request, `assets/logo.svg` (wordmark + mark) and `assets/logomark.svg` (mark only) are an original lockup designed for this system — a document glyph with a folded corner and text rules, in the bronze accent. This is NOT a real Minima PDF brand asset; swap it out the moment a real logo exists.
- **No font files** were attached; Inter and Noto Serif are loaded from Google Fonts as the nearest published match to the brief's "Inter/SF Pro/Roboto" and "New York/Noto Serif/Georgia" specs. Attach the exact font files if the product ships specific licensed fonts.
- **The GitHub repo `minimapdf` is currently empty** (placeholder README only). Everything here is built from the written brief alone. Please push real code/assets and ask me to re-run against it for a pixel-accurate system.

## Index

- `styles.css` — global stylesheet entry (imports everything under `tokens/`)
- `tokens/colors.css`, `typography.css`, `spacing.css`, `radius.css`, `motion.css`, `fonts.css`, `base.css`
- `guidelines/*.html` — 14 foundation specimen cards (Colors ×4, Type ×4, Spacing ×2, Brand ×4)
- `components/forms/` — Button, IconButton, Input, Select, Checkbox, Radio, Switch
- `components/feedback/` — Badge, Tag, Toast, Tooltip, ProgressBar
- `components/navigation/` — Tabs
- `components/overlay/` — Dialog
- `components/surfaces/` — Card
- `ui_kits/minima-pdf-app/` — Library, Reader, Tool Drawer, Settings — interactive demo in `index.html`
- `SKILL.md` — Claude Code-compatible skill file
