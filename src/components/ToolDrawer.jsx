import { Tabs } from "@ds";
import { NOTES, OUTLINE } from "../data/library.js";

export function ToolDrawer({ tab, onTab, bookmarked }) {
  return (
    <aside
      className="tool-drawer"
      style={{
        width: "var(--panel-drawer-w)",
        background: "var(--color-bg-sidebar)",
        borderLeft: "1px solid var(--color-border)",
        display: "flex",
        flexDirection: "column",
        fontFamily: "var(--font-ui)",
        flexShrink: 0,
      }}
    >
      <div style={{ padding: "10px 14px 0" }}>
        <Tabs
          items={[
            { label: "Outline", value: "outline" },
            { label: "Bookmarks", value: "bookmarks" },
            { label: "Notes", value: "notes" },
          ]}
          value={tab}
          onChange={onTab}
        />
      </div>
      <div style={{ padding: 16, overflow: "auto" }}>
        {tab === "outline" &&
          OUTLINE.map((item) => (
            <div
              key={item}
              style={{
                padding: "8px 4px",
                fontSize: "var(--text-sm)",
                color: "var(--color-text-secondary)",
                borderBottom: "1px solid var(--color-border)",
                cursor: "pointer",
              }}
            >
              {item}
            </div>
          ))}
        {tab === "bookmarks" && (
          <div style={{ fontSize: "var(--text-sm)", color: "var(--color-text-secondary)" }}>
            {bookmarked ? "Page 42 bookmarked" : "No bookmarks yet."}
          </div>
        )}
        {tab === "notes" &&
          NOTES.map((note) => (
            <div
              key={note.page}
              style={{
                marginBottom: 10,
                padding: 10,
                border: "1px solid var(--color-border)",
                borderRadius: "var(--radius-md)",
                background: "var(--color-bg-surface)",
              }}
            >
              <div
                style={{
                  fontFamily: "var(--font-reader)",
                  fontSize: 13,
                  color: "var(--color-text-primary)",
                  fontStyle: "italic",
                }}
              >
                {note.text}
              </div>
              <div style={{ fontSize: "var(--text-xs)", color: "var(--color-text-secondary)", marginTop: 4 }}>
                Page {note.page}
              </div>
            </div>
          ))}
      </div>
    </aside>
  );
}
