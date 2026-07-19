import { Input } from "@ds";
import { Brand } from "./Brand.jsx";
import { LibraryIcon, SearchIcon, SettingsIcon } from "../icons.jsx";

export function Sidebar({ tags, activeTag, onTag, onOpenSettings, search, onSearch, onNavigate }) {
  return (
    <aside
      className="app-sidebar"
      style={{
        width: "var(--panel-sidebar-w)",
        background: "var(--color-bg-sidebar)",
        borderRight: "1px solid var(--color-border)",
        display: "flex",
        flexDirection: "column",
        padding: 16,
        gap: 16,
        fontFamily: "var(--font-ui)",
        flexShrink: 0,
      }}
    >
      <Brand />
      <Input
        placeholder="Search library…"
        icon={<SearchIcon />}
        value={search}
        onChange={(e) => onSearch(e.target.value)}
      />
      <div
        style={{
          display: "flex",
          alignItems: "center",
          gap: 8,
          color: "var(--color-accent)",
          fontSize: "var(--text-sm)",
          fontWeight: 600,
        }}
      >
        <LibraryIcon /> Library
      </div>
      <nav style={{ display: "flex", flexDirection: "column", gap: 2 }} aria-label="Library tags">
        {tags.map((tag) => {
          const active = activeTag === tag;
          return (
            <button
              key={tag}
              type="button"
              onClick={() => {
                onTag(tag);
                onNavigate?.();
              }}
              style={{
                padding: "7px 10px",
                borderRadius: "var(--radius-sm)",
                fontSize: "var(--text-sm)",
                cursor: "pointer",
                textAlign: "left",
                border: "none",
                color: active ? "var(--color-accent)" : "var(--color-text-secondary)",
                background: active ? "rgba(200,154,90,0.1)" : "transparent",
                transitionProperty: "background,color",
                transitionDuration: "var(--duration-fast)",
                fontFamily: "var(--font-ui)",
              }}
            >
              {tag}
            </button>
          );
        })}
      </nav>
      <div style={{ marginTop: "auto", display: "flex", flexDirection: "column", gap: 10 }}>
        <button
          type="button"
          onClick={onOpenSettings}
          style={{
            display: "flex",
            alignItems: "center",
            gap: 8,
            color: "var(--color-text-secondary)",
            fontSize: "var(--text-sm)",
            cursor: "pointer",
            background: "transparent",
            border: "none",
            padding: 0,
            fontFamily: "var(--font-ui)",
          }}
        >
          <SettingsIcon /> Settings
        </button>
        <div
          style={{
            border: "1px solid var(--color-border)",
            borderRadius: "var(--radius-md)",
            padding: 10,
            fontSize: "var(--text-xs)",
            color: "var(--color-text-secondary)",
          }}
        >
          Lifetime license · $1.99 — <span style={{ color: "var(--color-accent)" }}>owned</span>
        </div>
      </div>
    </aside>
  );
}
