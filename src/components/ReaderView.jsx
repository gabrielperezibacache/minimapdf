import { IconButton, ProgressBar } from "@ds";
import { BackIcon, BookmarkIcon, PanelIcon, ZoomInIcon, ZoomOutIcon } from "../icons.jsx";

export function ReaderView({ doc, onBack, onToggleDrawer, bookmarked, onBookmark, zoom, onZoomIn, onZoomOut }) {
  return (
    <section style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", background: "var(--color-bg-canvas)" }}>
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 10,
          padding: "10px 18px",
          borderBottom: "1px solid var(--color-border)",
          fontFamily: "var(--font-ui)",
        }}
      >
        <IconButton title="Back to library" onClick={onBack}>
          <BackIcon />
        </IconButton>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div
            style={{
              color: "var(--color-text-primary)",
              fontWeight: 600,
              fontSize: "var(--text-base)",
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
            }}
          >
            {doc.title}
          </div>
          <ProgressBar value={doc.progress} />
        </div>
        <IconButton title="Zoom out" onClick={onZoomOut} disabled={zoom <= 0.8}>
          <ZoomOutIcon />
        </IconButton>
        <IconButton title="Zoom in" onClick={onZoomIn} disabled={zoom >= 1.4}>
          <ZoomInIcon />
        </IconButton>
        <IconButton title="Bookmark this page" active={bookmarked} onClick={onBookmark}>
          <BookmarkIcon />
        </IconButton>
        <IconButton title="Toggle tool drawer" onClick={onToggleDrawer}>
          <PanelIcon />
        </IconButton>
      </div>
      <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", padding: 32, overflow: "auto" }}>
        <div
          style={{
            width: 440,
            transform: `scale(${zoom})`,
            transformOrigin: "center top",
            aspectRatio: "8.5/11",
            background: "var(--color-bg-surface)",
            border: "1px solid var(--color-border)",
            borderRadius: "var(--radius-md)",
            padding: 36,
            fontFamily: "var(--font-reader)",
            color: "var(--color-text-primary)",
            fontSize: 13,
            lineHeight: "var(--leading-reader)",
            overflow: "hidden",
            transitionProperty: "transform",
            transitionDuration: "var(--duration-fast)",
          }}
        >
          <div style={{ fontWeight: 700, fontSize: 17, marginBottom: 10 }}>{doc.title.replace(".pdf", "")}</div>
          <div style={{ color: "var(--color-text-secondary)" }}>
            Section 4.2 — Findings
            <br />
            <br />
            The results indicate a measurable reduction in load time across all tested document sizes, consistent with the
            offline-first architecture described in Section 2. No network calls were observed during rendering. Local
            indexing kept library navigation under 40ms even with multi-hundred-page collections.
            <br />
            <br />
            Read, organize, focus. Once.
          </div>
        </div>
      </div>
      <div
        style={{
          textAlign: "center",
          fontFamily: "var(--font-reader)",
          fontSize: 12,
          color: "var(--color-text-secondary)",
          paddingBottom: 14,
        }}
      >
        Page 42 of {doc.pages}
      </div>
    </section>
  );
}
