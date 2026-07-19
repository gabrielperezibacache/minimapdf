import React from "react";

export function Card({ children, padding = 16 }) {
  return (
    <div
      style={{
        background: "var(--color-bg-surface)",
        border: "1px solid var(--color-border)",
        borderRadius: "var(--radius-lg)",
        padding,
      }}
    >
      {children}
    </div>
  );
}
