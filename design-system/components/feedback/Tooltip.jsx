import React from "react";

export function Tooltip({ children, label }) {
  const [show, setShow] = React.useState(false);
  return (
    <span style={{ position: "relative", display: "inline-flex" }} onMouseEnter={() => setShow(true)} onMouseLeave={() => setShow(false)}>
      {children}
      {show && (
        <span
          style={{
            position: "absolute",
            bottom: "calc(100% + 6px)",
            left: "50%",
            transform: "translateX(-50%)",
            background: "var(--emerald-975)",
            color: "var(--color-text-primary)",
            border: "1px solid var(--color-border)",
            borderRadius: "var(--radius-sm)",
            padding: "4px 8px",
            fontSize: "var(--text-xs)",
            whiteSpace: "nowrap",
            fontFamily: "var(--font-ui)",
          }}
        >
          {label}
        </span>
      )}
    </span>
  );
}
