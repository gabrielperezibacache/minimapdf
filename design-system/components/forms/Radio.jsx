import React from "react";

export function Radio({ checked, onChange, label }) {
  return (
    <label style={{ display: "inline-flex", alignItems: "center", gap: 8, cursor: "pointer", color: "var(--color-text-primary)", fontFamily: "var(--font-ui)", fontSize: "var(--text-base)" }}>
      <span
        onClick={onChange}
        style={{
          width: 16,
          height: 16,
          borderRadius: "50%",
          border: `1px solid ${checked ? "var(--color-accent)" : "var(--color-border)"}`,
          display: "inline-flex",
          alignItems: "center",
          justifyContent: "center",
          transitionProperty: "border-color",
          transitionDuration: "var(--duration-fast)",
        }}
      >
        {checked && <span style={{ width: 8, height: 8, borderRadius: "50%", background: "var(--color-accent)" }} />}
      </span>
      {label}
    </label>
  );
}
