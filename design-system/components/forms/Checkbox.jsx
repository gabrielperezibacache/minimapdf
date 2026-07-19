import React from "react";

export function Checkbox({ checked, onChange, label }) {
  return (
    <label style={{ display: "inline-flex", alignItems: "center", gap: 8, cursor: "pointer", color: "var(--color-text-primary)", fontFamily: "var(--font-ui)", fontSize: "var(--text-base)" }}>
      <span
        onClick={onChange}
        style={{
          width: 16,
          height: 16,
          borderRadius: "var(--radius-sm)",
          border: `1px solid ${checked ? "var(--color-accent)" : "var(--color-border)"}`,
          background: checked ? "var(--color-accent)" : "transparent",
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          transitionProperty: "background,border-color",
          transitionDuration: "var(--duration-fast)",
        }}
      >
        {checked && <svg width="10" height="8" viewBox="0 0 10 8"><path d="M1 4L3.5 6.5L9 1" stroke="var(--emerald-950)" strokeWidth="1.6" fill="none"/></svg>}
      </span>
      {label}
    </label>
  );
}
