# Minima PDF

Ultra-lightweight, 100% offline PDF reader and library manager.

**Slogan:** Read, organize, focus. Once.

## App

The React app under `src/` uses the Hermes Obsidian design system for tokens, primitives, and the Library → Reader → Settings product surface.

```bash
npm install
npm run dev
```

```bash
npm run build
npm run preview
```

### What’s wired up

- Design tokens + global styles from `design-system/styles.css`
- UI primitives imported via the `@ds` alias (`design-system/index.js`)
- Library grid, three-panel reader, tool drawer, and settings dialog
- Dark / Light Canvas themes and ultra-low-glare mode
- Responsive sidebar / drawer on smaller viewports

## Design system

Source package: [`design-system/`](./design-system/). Full docs: [`design-system/readme.md`](./design-system/readme.md).

Prototype HTML (reference): `design-system/Minima PDF Design System - App Prototype.html`

## Deploy

`render.yaml` publishes the Vite `dist/` output as a static site with SPA rewrite to `index.html`.
