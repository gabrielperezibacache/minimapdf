const { Input, IconButton, Button } = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;

function SearchIcon(){return <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><circle cx="11" cy="11" r="7"/><path d="M21 21l-4.3-4.3"/></svg>;}
function LibraryIcon(){return <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M3 9h18M8 4v5"/></svg>;}
function SettingsIcon(){return <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.75"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/></svg>;}

function Sidebar({ tags, activeTag, onTag, onOpenSettings }) {
  return (
    <div style={{ width: "var(--panel-sidebar-w)", background: "var(--color-bg-sidebar)", borderRight: "1px solid var(--color-border)", display: "flex", flexDirection: "column", padding: 16, gap: 16, fontFamily: "var(--font-ui)" }}>
      <img src="../../assets/logo.svg" alt="Minima PDF" style={{ height: 24, width: "auto" }} />
      <Input placeholder="Search library…" icon={<SearchIcon />} />
      <div style={{ display: "flex", alignItems: "center", gap: 8, color: "var(--color-accent)", fontSize: "var(--text-sm)", fontWeight: 600 }}>
        <LibraryIcon /> Library
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 2 }}>
        {tags.map((t) => (
          <div
            key={t}
            onClick={() => onTag(t)}
            style={{
              padding: "7px 10px",
              borderRadius: "var(--radius-sm)",
              fontSize: "var(--text-sm)",
              cursor: "pointer",
              color: activeTag === t ? "var(--color-accent)" : "var(--color-text-secondary)",
              background: activeTag === t ? "rgba(200,154,90,0.1)" : "transparent",
              transitionProperty: "background,color",
              transitionDuration: "var(--duration-fast)",
            }}
          >
            {t}
          </div>
        ))}
      </div>
      <div style={{ marginTop: "auto", display: "flex", flexDirection: "column", gap: 10 }}>
        <div onClick={onOpenSettings} style={{ display: "flex", alignItems: "center", gap: 8, color: "var(--color-text-secondary)", fontSize: "var(--text-sm)", cursor: "pointer" }}>
          <SettingsIcon /> Settings
        </div>
        <div style={{ border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)", padding: 10, fontSize: "var(--text-xs)", color: "var(--color-text-secondary)" }}>
          Lifetime license · $1.99 — <span style={{ color: "var(--color-accent)" }}>owned</span>
        </div>
      </div>
    </div>
  );
}
window.Sidebar = Sidebar;
