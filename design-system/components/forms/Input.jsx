import React from "react";

export function Input({ placeholder, value, onChange, icon = null, type = "text" }) {
  const [focused, setFocused] = React.useState(false);
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "8px 12px",
        borderRadius: "var(--radius-md)",
        border: `1px solid ${focused ? "var(--color-accent)" : "var(--color-border)"}`,
        background: "var(--color-bg-surface)",
        transitionProperty: "border-color",
        transitionDuration: "var(--duration-fast)",
      }}
    >
      {icon}
      <input
        type={type}
        placeholder={placeholder}
        value={value}
        onChange={onChange}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        style={{
          flex: 1,
          border: "none",
          outline: "none",
          background: "transparent",
          color: "var(--color-text-primary)",
          fontFamily: "var(--font-ui)",
          fontSize: "var(--text-base)",
        }}
      />
    </div>
  );
}
