const { IconButton, ProgressBar } = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;

function Back(){return <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><path d="M15 18l-6-6 6-6"/></svg>;}
function Bookmark(){return <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><path d="M6 3h12v18l-6-4-6 4V3z"/></svg>;}
function ZoomIn(){return <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3M11 8v6M8 11h6"/></svg>;}
function ZoomOut(){return <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3M8 11h6"/></svg>;}
function Panel(){return <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M15 4v16"/></svg>;}

function ReaderView({ doc, onBack, onToggleDrawer, bookmarked, onBookmark }) {
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", background: "var(--color-bg-canvas)" }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10, padding: "10px 18px", borderBottom: "1px solid var(--color-border)", fontFamily: "var(--font-ui)" }}>
        <IconButton title="Back to library" onClick={onBack}><Back /></IconButton>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ color: "var(--color-text-primary)", fontWeight: 600, fontSize: "var(--text-base)", whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{doc.title}</div>
          <ProgressBar value={doc.progress} />
        </div>
        <IconButton title="Zoom out"><ZoomOut /></IconButton>
        <IconButton title="Zoom in"><ZoomIn /></IconButton>
        <IconButton title="Bookmark this page" active={bookmarked} onClick={onBookmark}><Bookmark /></IconButton>
        <IconButton title="Toggle tool drawer" onClick={onToggleDrawer}><Panel /></IconButton>
      </div>
      <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", padding: 32 }}>
        <div style={{ width: 440, aspectRatio: "8.5/11", background: "var(--color-bg-surface)", border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)", padding: 36, fontFamily: "var(--font-reader)", color: "var(--color-text-primary)", fontSize: 13, lineHeight: "var(--leading-reader)", overflow: "hidden" }}>
          <div style={{ fontWeight: 700, fontSize: 17, marginBottom: 10 }}>{doc.title.replace(".pdf", "")}</div>
          <div style={{ color: "var(--color-text-secondary)" }}>
            Section 4.2 — Findings<br /><br />
            The results indicate a measurable reduction in load time across all tested document sizes, consistent with the offline-first architecture described in Section 2. No network calls were observed during rendering...
          </div>
        </div>
      </div>
      <div style={{ textAlign: "center", fontFamily: "var(--font-reader)", fontSize: 12, color: "var(--color-text-secondary)", paddingBottom: 14 }}>Page 42 of {doc.pages}</div>
    </div>
  );
}
window.ReaderView = ReaderView;
