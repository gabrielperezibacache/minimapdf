import React from "react";

export function Toast({ children, tone = "neutral" }) {
  const border = tone === "danger" ? "var(--color-danger)" : tone === "success" ? "var(--color-success)" : "var(--color-border)";
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 10,
        padding: "12px 16px",
        borderRadius: "var(--radius-md)",
        background: "var(--color-bg-surface)",
        border: `1px solid ${border}`,
        color: "var(--color-text-primary)",
        fontFamily: "var(--font-ui)",
        fontSize: "var(--text-sm)",
        maxWidth: 320,
      }}
    >
      {children}
    </div>
  );
}
