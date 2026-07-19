const { Tabs } = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;

const outline = ["1. Introduction", "2. Related Work", "3. Method", "4. Findings", "5. Discussion", "6. Conclusion"];
const notes = [
  { page: 12, text: "Revisit this claim — check citation." },
  { page: 42, text: "Strong result, use in summary." },
];

function ToolDrawer({ tab, onTab }) {
  return (
    <div style={{ width: "var(--panel-drawer-w)", background: "var(--color-bg-sidebar)", borderLeft: "1px solid var(--color-border)", display: "flex", flexDirection: "column", fontFamily: "var(--font-ui)" }}>
      <div style={{ padding: "10px 14px 0" }}>
        <Tabs items={[{ label: "Outline", value: "outline" }, { label: "Bookmarks", value: "bookmarks" }, { label: "Notes", value: "notes" }]} value={tab} onChange={onTab} />
      </div>
      <div style={{ padding: 16, overflow: "auto" }}>
        {tab === "outline" && outline.map((o) => (
          <div key={o} style={{ padding: "8px 4px", fontSize: "var(--text-sm)", color: "var(--color-text-secondary)", borderBottom: "1px solid var(--color-border)", cursor: "pointer" }}>{o}</div>
        ))}
        {tab === "bookmarks" && (
          <div style={{ fontSize: "var(--text-sm)", color: "var(--color-text-secondary)" }}>Page 42 bookmarked</div>
        )}
        {tab === "notes" && notes.map((n) => (
          <div key={n.page} style={{ marginBottom: 10, padding: 10, border: "1px solid var(--color-border)", borderRadius: "var(--radius-md)", background: "var(--color-bg-surface)" }}>
            <div style={{ fontFamily: "var(--font-reader)", fontSize: 13, color: "var(--color-text-primary)", fontStyle: "italic" }}>{n.text}</div>
            <div style={{ fontSize: "var(--text-xs)", color: "var(--color-text-secondary)", marginTop: 4 }}>Page {n.page}</div>
          </div>
        ))}
      </div>
    </div>
  );
}
window.ToolDrawer = ToolDrawer;
