const { Badge, ProgressBar } = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;

function FileIcon(){return <svg width="26" height="26" viewBox="0 0 40 40" fill="none" stroke="var(--color-text-secondary)" strokeWidth="2"><rect x="7" y="5" width="26" height="30" rx="3"/><path d="M14 14h12M14 20h12M14 26h7" strokeLinecap="round"/></svg>;}

function LibraryGrid({ docs, onOpen }) {
  const [hoverId, setHoverId] = React.useState(null);
  return (
    <div style={{ flex: 1, padding: 28, overflow: "auto" }}>
      <div style={{ fontFamily: "var(--font-ui)", fontWeight: 700, fontSize: "var(--text-xl)", letterSpacing: "var(--tracking-tight)", color: "var(--color-text-primary)", marginBottom: 4 }}>Your library</div>
      <div style={{ fontFamily: "var(--font-ui)", fontSize: "var(--text-sm)", color: "var(--color-text-secondary)", marginBottom: 20 }}>{docs.length} documents · stored on this device only</div>
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))", gap: 14 }}>
        {docs.map((d) => (
          <div
            key={d.id}
            onClick={() => onOpen(d)}
            onMouseEnter={() => setHoverId(d.id)}
            onMouseLeave={() => setHoverId(null)}
            style={{ background: "var(--color-bg-surface)", border: `1px solid ${hoverId === d.id ? "var(--sage-600)" : "var(--color-border)"}`, borderRadius: "var(--radius-lg)", padding: 14, cursor: "pointer", display: "flex", flexDirection: "column", gap: 10, transitionProperty: "border-color", transitionDuration: "var(--duration-fast)" }}
          >
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
              <FileIcon />
              <Badge tone={d.progress === 100 ? "neutral" : "accent"}>{d.progress === 100 ? "Read" : `${d.progress}%`}</Badge>
            </div>
            <div style={{ fontFamily: "var(--font-ui)", fontWeight: 600, fontSize: "var(--text-base)", color: "var(--color-text-primary)", lineHeight: "var(--leading-snug)" }}>{d.title}</div>
            <div style={{ fontFamily: "var(--font-ui)", fontSize: "var(--text-xs)", color: "var(--color-text-secondary)" }}>{d.pages} pages · {d.tag}</div>
            <ProgressBar value={d.progress} />
          </div>
        ))}
      </div>
    </div>
  );
}
window.LibraryGrid = LibraryGrid;
