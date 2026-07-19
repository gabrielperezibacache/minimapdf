export function Brand({ compact = false }) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 10,
        fontFamily: "var(--font-ui)",
        minWidth: 0,
      }}
    >
      <svg width="22" height="26" viewBox="0 0 32 40" fill="none" aria-hidden="true">
        <rect x="2" y="5" width="26" height="30" rx="3" stroke="var(--color-accent)" strokeWidth="2" />
        <path d="M9 14h12M9 20h12M9 26h7" stroke="var(--color-accent)" strokeWidth="2" strokeLinecap="round" />
      </svg>
      {!compact && (
        <span
          style={{
            fontWeight: 800,
            fontSize: 18,
            letterSpacing: "-0.6px",
            color: "var(--color-text-primary)",
            whiteSpace: "nowrap",
          }}
        >
          Minima
          <span style={{ color: "var(--color-accent)", marginLeft: 6 }}>PDF</span>
        </span>
      )}
    </div>
  );
}
