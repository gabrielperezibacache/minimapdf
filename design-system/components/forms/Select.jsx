import React from "react";

export function Select({ options = [], value, onChange }) {
  const [focused, setFocused] = React.useState(false);
  return (
    <select
      value={value}
      onChange={onChange}
      onFocus={() => setFocused(true)}
      onBlur={() => setFocused(false)}
      style={{
        padding: "8px 12px",
        borderRadius: "var(--radius-md)",
        border: `1px solid ${focused ? "var(--color-accent)" : "var(--color-border)"}`,
        background: "var(--color-bg-surface)",
        color: "var(--color-text-primary)",
        fontFamily: "var(--font-ui)",
        fontSize: "var(--text-base)",
        cursor: "pointer",
        transitionProperty: "border-color",
        transitionDuration: "var(--duration-fast)",
      }}
    >
      {options.map((o) => (
        <option key={o.value} value={o.value}>{o.label}</option>
      ))}
    </select>
  );
}
