const { Dialog, Radio, Switch, Button } = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;

function SettingsPanel({ open, onClose, theme, onTheme, lowGlare, onLowGlare }) {
  return (
    <Dialog open={open} title="Settings" onClose={onClose}>
      <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
        <div>
          <div style={{ color: "var(--color-text-primary)", fontWeight: 600, marginBottom: 8, fontSize: "var(--text-sm)" }}>Reading theme</div>
          <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
            <Radio checked={theme === "dark"} label="Low-Glare Dark" onChange={() => onTheme("dark")} />
            <Radio checked={theme === "light"} label="Light Canvas" onChange={() => onTheme("light")} />
          </div>
        </div>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}>
          <div style={{ color: "var(--color-text-primary)", fontWeight: 600, fontSize: "var(--text-sm)" }}>Ultra-low-glare mode</div>
          <Switch checked={lowGlare} onChange={onLowGlare} />
        </div>
        <div style={{ borderTop: "1px solid var(--color-border)", paddingTop: 12, fontSize: "var(--text-xs)", color: "var(--color-text-secondary)" }}>
          No cloud sync. No accounts. 100% offline, always.
        </div>
        <Button variant="secondary" onClick={onClose}>Done</Button>
      </div>
    </Dialog>
  );
}
window.SettingsPanel = SettingsPanel;
