import React from "react";

export function Dialog({ open, title, children, onClose }) {
  if (!open) return null;
  return (
    <div style={{ position: "fixed", inset: 0, background: "rgba(15,23,20,0.7)", display: "flex", alignItems: "center", justifyContent: "center", zIndex: 50 }} onClick={onClose}>
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: 380,
          background: "var(--color-bg-surface)",
          border: "1px solid var(--color-border)",
          borderRadius: "var(--radius-lg)",
          padding: 20,
          fontFamily: "var(--font-ui)",
        }}
      >
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 12 }}>
          <div style={{ color: "var(--color-text-primary)", fontWeight: 700, letterSpacing: "var(--tracking-tight)", fontSize: "var(--text-lg)" }}>{title}</div>
          <span onClick={onClose} style={{ cursor: "pointer", color: "var(--color-text-secondary)" }}>×</span>
        </div>
        <div style={{ color: "var(--color-text-secondary)", fontSize: "var(--text-base)", lineHeight: "var(--leading-body)" }}>{children}</div>
      </div>
    </div>
  );
}
