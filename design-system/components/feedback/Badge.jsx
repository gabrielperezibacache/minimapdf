import React from "react";

export function Badge({ children, tone = "accent" }) {
  const tones = {
    accent: { background: "rgba(200,154,90,0.14)", color: "var(--color-accent)", border: "1px solid rgba(200,154,90,0.4)" },
    neutral: { background: "var(--color-bg-surface)", color: "var(--color-text-secondary)", border: "1px solid var(--color-border)" },
    danger: { background: "rgba(192,96,74,0.14)", color: "var(--color-danger)", border: "1px solid rgba(192,96,74,0.4)" },
  };
  return (
    <span
      style={{
        display: "inline-flex",
        alignItems: "center",
        padding: "2px 8px",
        borderRadius: "var(--radius-pill)",
        fontFamily: "var(--font-ui)",
        fontSize: "var(--text-xs)",
        fontWeight: 600,
        letterSpacing: "0.01em",
        ...tones[tone],
      }}
    >
      {children}
    </span>
  );
}
