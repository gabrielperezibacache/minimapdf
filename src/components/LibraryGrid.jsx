import { Badge, ProgressBar } from "@ds";
import { FileIcon } from "../icons.jsx";

export function LibraryGrid({ docs, onOpen }) {
  return (
    <div style={{ flex: 1, padding: 28, overflow: "auto" }}>
      <div
        style={{
          fontFamily: "var(--font-ui)",
          fontWeight: 700,
          fontSize: "var(--text-xl)",
          letterSpacing: "var(--tracking-tight)",
          color: "var(--color-text-primary)",
          marginBottom: 4,
        }}
      >
        Your library
      </div>
      <div
        style={{
          fontFamily: "var(--font-ui)",
          fontSize: "var(--text-sm)",
          color: "var(--color-text-secondary)",
          marginBottom: 20,
        }}
      >
        {docs.length} documents · stored on this device only
      </div>
      {docs.length === 0 ? (
        <div
          style={{
            border: "1px solid var(--color-border)",
            borderRadius: "var(--radius-lg)",
            padding: 28,
            color: "var(--color-text-secondary)",
            fontFamily: "var(--font-ui)",
            fontSize: "var(--text-sm)",
          }}
        >
          No documents match this filter.
        </div>
      ) : (
        <div
          className="library-grid"
          style={{
            display: "grid",
            gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))",
            gap: 14,
          }}
        >
          {docs.map((doc) => (
            <LibraryCard key={doc.id} doc={doc} onOpen={onOpen} />
          ))}
        </div>
      )}
    </div>
  );
}

function LibraryCard({ doc, onOpen }) {
  return (
    <button
      type="button"
      onClick={() => onOpen(doc)}
      style={{
        background: "var(--color-bg-surface)",
        border: "1px solid var(--color-border)",
        borderRadius: "var(--radius-lg)",
        padding: 14,
        cursor: "pointer",
        display: "flex",
        flexDirection: "column",
        gap: 10,
        textAlign: "left",
        transitionProperty: "border-color",
        transitionDuration: "var(--duration-fast)",
        fontFamily: "var(--font-ui)",
      }}
      onMouseEnter={(e) => {
        e.currentTarget.style.borderColor = "var(--sage-600)";
      }}
      onMouseLeave={(e) => {
        e.currentTarget.style.borderColor = "var(--color-border)";
      }}
    >
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}>
        <FileIcon />
        <Badge tone={doc.progress === 100 ? "neutral" : "accent"}>
          {doc.progress === 100 ? "Read" : `${doc.progress}%`}
        </Badge>
      </div>
      <div
        style={{
          fontWeight: 600,
          fontSize: "var(--text-base)",
          color: "var(--color-text-primary)",
          lineHeight: "var(--leading-snug)",
        }}
      >
        {doc.title}
      </div>
      <div style={{ fontSize: "var(--text-xs)", color: "var(--color-text-secondary)" }}>
        {doc.pages} pages · {doc.tag}
      </div>
      <ProgressBar value={doc.progress} />
    </button>
  );
}
