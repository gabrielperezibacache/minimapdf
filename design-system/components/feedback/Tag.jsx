import React from "react";

export function Tag({ children, onRemove }) {
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        gap: 6,
        padding: "4px 10px",
        borderRadius: "var(--radius-sm)",
        border: "1px solid var(--color-border)",
        background: "var(--color-bg-surface)",
        color: "var(--color-text-primary)",
        fontFamily: "var(--font-ui)",
        fontSize: "var(--text-sm)",
      }}
    >
      {children}
      {onRemove && (
        <span onClick={onRemove} style={{ cursor: "pointer", color: "var(--color-text-secondary)" }}>×</span>
      )}
    </span>
  );
}
