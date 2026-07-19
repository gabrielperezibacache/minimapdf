import React from "react";

export function Tabs({ items = [], value, onChange }) {
  return (
    <div style={{ display: "flex", gap: 4, borderBottom: "1px solid var(--color-border)" }}>
      {items.map((it) => {
        const active = it.value === value;
        return (
          <button
            key={it.value}
            onClick={() => onChange && onChange(it.value)}
            style={{
              padding: "10px 14px",
              background: "transparent",
              border: "none",
              borderBottom: active ? "2px solid var(--color-accent)" : "2px solid transparent",
              color: active ? "var(--color-accent)" : "var(--color-text-secondary)",
              fontFamily: "var(--font-ui)",
              fontWeight: 600,
              fontSize: "var(--text-sm)",
              cursor: "pointer",
              transitionProperty: "color,border-color",
              transitionDuration: "var(--duration-fast)",
            }}
          >
            {it.label}
          </button>
        );
      })}
    </div>
  );
}
