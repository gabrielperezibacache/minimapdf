/* @ds-bundle: {"format":4,"namespace":"MinimaPDFHermesObsidianDesignSystem_1b8fb1","components":[{"name":"Badge","sourcePath":"components/feedback/Badge.jsx"},{"name":"ProgressBar","sourcePath":"components/feedback/ProgressBar.jsx"},{"name":"Tag","sourcePath":"components/feedback/Tag.jsx"},{"name":"Toast","sourcePath":"components/feedback/Toast.jsx"},{"name":"Tooltip","sourcePath":"components/feedback/Tooltip.jsx"},{"name":"Button","sourcePath":"components/forms/Button.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"IconButton","sourcePath":"components/forms/IconButton.jsx"},{"name":"Input","sourcePath":"components/forms/Input.jsx"},{"name":"Radio","sourcePath":"components/forms/Radio.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"},{"name":"Tabs","sourcePath":"components/navigation/Tabs.jsx"},{"name":"Dialog","sourcePath":"components/overlay/Dialog.jsx"},{"name":"Card","sourcePath":"components/surfaces/Card.jsx"}],"sourceHashes":{"components/feedback/Badge.jsx":"f075e4a1b742","components/feedback/ProgressBar.jsx":"2d6930378027","components/feedback/Tag.jsx":"17f142e6a96c","components/feedback/Toast.jsx":"244275d03e5e","components/feedback/Tooltip.jsx":"8da485457670","components/forms/Button.jsx":"828dc448a69d","components/forms/Checkbox.jsx":"318b5908eb8d","components/forms/IconButton.jsx":"10d4e9053856","components/forms/Input.jsx":"b4e83e632748","components/forms/Radio.jsx":"1151f0d9f234","components/forms/Select.jsx":"e870135624a8","components/forms/Switch.jsx":"7b64b36047c3","components/navigation/Tabs.jsx":"adf5ac1f5409","components/overlay/Dialog.jsx":"2c27cdb57c30","components/surfaces/Card.jsx":"d79d284f7ea8","ui_kits/minima-pdf-app/LibraryGrid.jsx":"8d75f5f4e0dc","ui_kits/minima-pdf-app/ReaderView.jsx":"f50c5a02e574","ui_kits/minima-pdf-app/SettingsPanel.jsx":"e345fc27ff95","ui_kits/minima-pdf-app/Sidebar.jsx":"dee4daa2b6ff","ui_kits/minima-pdf-app/ToolDrawer.jsx":"d05c7c14d31d","ui_kits/minima-pdf-app/data.js":"2bc91a4b51b4"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.MinimaPDFHermesObsidianDesignSystem_1b8fb1 = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/feedback/Badge.jsx
try { (() => {
function Badge({
  children,
  tone = "accent"
}) {
  const tones = {
    accent: {
      background: "rgba(200,154,90,0.14)",
      color: "var(--color-accent)",
      border: "1px solid rgba(200,154,90,0.4)"
    },
    neutral: {
      background: "var(--color-bg-surface)",
      color: "var(--color-text-secondary)",
      border: "1px solid var(--color-border)"
    },
    danger: {
      background: "rgba(192,96,74,0.14)",
      color: "var(--color-danger)",
      border: "1px solid rgba(192,96,74,0.4)"
    }
  };
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      padding: "2px 8px",
      borderRadius: "var(--radius-pill)",
      fontFamily: "var(--font-ui)",
      fontSize: "var(--text-xs)",
      fontWeight: 600,
      letterSpacing: "0.01em",
      ...tones[tone]
    }
  }, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Badge.jsx", error: String((e && e.message) || e) }); }

// components/feedback/ProgressBar.jsx
try { (() => {
function ProgressBar({
  value = 0
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: "100%",
      height: 4,
      background: "var(--color-border)",
      borderRadius: "var(--radius-pill)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: `${Math.min(100, Math.max(0, value))}%`,
      height: "100%",
      background: "var(--color-accent)",
      transitionProperty: "width",
      transitionDuration: "var(--duration-fast)"
    }
  }));
}
Object.assign(__ds_scope, { ProgressBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/ProgressBar.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Tag.jsx
try { (() => {
function Tag({
  children,
  onRemove
}) {
  return /*#__PURE__*/React.createElement("span", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 6,
      padding: "4px 10px",
      borderRadius: "var(--radius-sm)",
      border: "1px solid var(--color-border)",
      background: "var(--color-bg-surface)",
      color: "var(--color-text-primary)",
      fontFamily: "var(--font-ui)",
      fontSize: "var(--text-sm)"
    }
  }, children, onRemove && /*#__PURE__*/React.createElement("span", {
    onClick: onRemove,
    style: {
      cursor: "pointer",
      color: "var(--color-text-secondary)"
    }
  }, "\xD7"));
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Tag.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Toast.jsx
try { (() => {
function Toast({
  children,
  tone = "neutral"
}) {
  const border = tone === "danger" ? "var(--color-danger)" : tone === "success" ? "var(--color-success)" : "var(--color-border)";
  return /*#__PURE__*/React.createElement("div", {
    style: {
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
      maxWidth: 320
    }
  }, children);
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Toast.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Tooltip.jsx
try { (() => {
function Tooltip({
  children,
  label
}) {
  const [show, setShow] = React.useState(false);
  return /*#__PURE__*/React.createElement("span", {
    style: {
      position: "relative",
      display: "inline-flex"
    },
    onMouseEnter: () => setShow(true),
    onMouseLeave: () => setShow(false)
  }, children, show && /*#__PURE__*/React.createElement("span", {
    style: {
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
      fontFamily: "var(--font-ui)"
    }
  }, label));
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Tooltip.jsx", error: String((e && e.message) || e) }); }

// components/forms/Button.jsx
try { (() => {
const sizes = {
  sm: {
    padding: "6px 12px",
    fontSize: "var(--text-sm)"
  },
  md: {
    padding: "9px 16px",
    fontSize: "var(--text-base)"
  },
  lg: {
    padding: "12px 20px",
    fontSize: "var(--text-md)"
  }
};
const variants = {
  primary: {
    background: "var(--color-accent)",
    color: "var(--emerald-950)",
    border: "1px solid var(--color-accent)"
  },
  secondary: {
    background: "transparent",
    color: "var(--color-text-primary)",
    border: "1px solid var(--color-border)"
  },
  ghost: {
    background: "transparent",
    color: "var(--color-text-secondary)",
    border: "1px solid transparent"
  },
  danger: {
    background: "transparent",
    color: "var(--color-danger)",
    border: "1px solid var(--color-danger)"
  }
};
const hover = {
  primary: {
    background: "var(--color-accent-hover)",
    borderColor: "var(--color-accent-hover)"
  },
  secondary: {
    background: "var(--color-bg-surface)",
    borderColor: "var(--color-text-secondary)"
  },
  ghost: {
    color: "var(--color-text-primary)"
  },
  danger: {
    background: "rgba(192,96,74,0.12)"
  }
};
function Button({
  children,
  variant = "primary",
  size = "md",
  disabled = false,
  icon = null,
  onClick
}) {
  const [isHover, setHover] = React.useState(false);
  const base = variants[variant] || variants.primary;
  const h = hover[variant] || {};
  return /*#__PURE__*/React.createElement("button", {
    disabled: disabled,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    onClick: onClick,
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 8,
      fontFamily: "var(--font-ui)",
      fontWeight: 600,
      letterSpacing: "var(--tracking-tight)",
      borderRadius: "var(--radius-md)",
      cursor: disabled ? "default" : "pointer",
      transitionProperty: "background,border-color,color",
      transitionDuration: "var(--duration-fast)",
      opacity: disabled ? 0.45 : 1,
      ...sizes[size],
      ...base,
      ...(isHover && !disabled ? h : {})
    }
  }, icon, children);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Button.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
function Checkbox({
  checked,
  onChange,
  label
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 8,
      cursor: "pointer",
      color: "var(--color-text-primary)",
      fontFamily: "var(--font-ui)",
      fontSize: "var(--text-base)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    onClick: onChange,
    style: {
      width: 16,
      height: 16,
      borderRadius: "var(--radius-sm)",
      border: `1px solid ${checked ? "var(--color-accent)" : "var(--color-border)"}`,
      background: checked ? "var(--color-accent)" : "transparent",
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      transitionProperty: "background,border-color",
      transitionDuration: "var(--duration-fast)"
    }
  }, checked && /*#__PURE__*/React.createElement("svg", {
    width: "10",
    height: "8",
    viewBox: "0 0 10 8"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M1 4L3.5 6.5L9 1",
    stroke: "var(--emerald-950)",
    strokeWidth: "1.6",
    fill: "none"
  }))), label);
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/IconButton.jsx
try { (() => {
function IconButton({
  children,
  active = false,
  size = 32,
  title
}) {
  const [hover, setHover] = React.useState(false);
  return /*#__PURE__*/React.createElement("button", {
    title: title,
    onMouseEnter: () => setHover(true),
    onMouseLeave: () => setHover(false),
    style: {
      width: size,
      height: size,
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      borderRadius: "var(--radius-sm)",
      border: active ? "1px solid var(--color-accent)" : "1px solid transparent",
      background: active ? "rgba(200,154,90,0.14)" : hover ? "var(--color-bg-surface)" : "transparent",
      color: active ? "var(--color-accent)" : "var(--color-text-secondary)",
      cursor: "pointer",
      transitionProperty: "background,color,border-color",
      transitionDuration: "var(--duration-fast)"
    }
  }, children);
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/forms/Input.jsx
try { (() => {
function Input({
  placeholder,
  value,
  onChange,
  icon = null,
  type = "text"
}) {
  const [focused, setFocused] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      padding: "8px 12px",
      borderRadius: "var(--radius-md)",
      border: `1px solid ${focused ? "var(--color-accent)" : "var(--color-border)"}`,
      background: "var(--color-bg-surface)",
      transitionProperty: "border-color",
      transitionDuration: "var(--duration-fast)"
    }
  }, icon, /*#__PURE__*/React.createElement("input", {
    type: type,
    placeholder: placeholder,
    value: value,
    onChange: onChange,
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
    style: {
      flex: 1,
      border: "none",
      outline: "none",
      background: "transparent",
      color: "var(--color-text-primary)",
      fontFamily: "var(--font-ui)",
      fontSize: "var(--text-base)"
    }
  }));
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// components/forms/Radio.jsx
try { (() => {
function Radio({
  checked,
  onChange,
  label
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: "inline-flex",
      alignItems: "center",
      gap: 8,
      cursor: "pointer",
      color: "var(--color-text-primary)",
      fontFamily: "var(--font-ui)",
      fontSize: "var(--text-base)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    onClick: onChange,
    style: {
      width: 16,
      height: 16,
      borderRadius: "50%",
      border: `1px solid ${checked ? "var(--color-accent)" : "var(--color-border)"}`,
      display: "inline-flex",
      alignItems: "center",
      justifyContent: "center",
      transitionProperty: "border-color",
      transitionDuration: "var(--duration-fast)"
    }
  }, checked && /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8,
      height: 8,
      borderRadius: "50%",
      background: "var(--color-accent)"
    }
  })), label);
}
Object.assign(__ds_scope, { Radio });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Radio.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function Select({
  options = [],
  value,
  onChange
}) {
  const [focused, setFocused] = React.useState(false);
  return /*#__PURE__*/React.createElement("select", {
    value: value,
    onChange: onChange,
    onFocus: () => setFocused(true),
    onBlur: () => setFocused(false),
    style: {
      padding: "8px 12px",
      borderRadius: "var(--radius-md)",
      border: `1px solid ${focused ? "var(--color-accent)" : "var(--color-border)"}`,
      background: "var(--color-bg-surface)",
      color: "var(--color-text-primary)",
      fontFamily: "var(--font-ui)",
      fontSize: "var(--text-base)",
      cursor: "pointer",
      transitionProperty: "border-color",
      transitionDuration: "var(--duration-fast)"
    }
  }, options.map(o => /*#__PURE__*/React.createElement("option", {
    key: o.value,
    value: o.value
  }, o.label)));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
function Switch({
  checked,
  onChange
}) {
  return /*#__PURE__*/React.createElement("span", {
    onClick: onChange,
    role: "switch",
    "aria-checked": checked,
    style: {
      width: 36,
      height: 20,
      borderRadius: "var(--radius-pill)",
      background: checked ? "var(--color-accent)" : "var(--color-bg-surface)",
      border: "1px solid var(--color-border)",
      display: "inline-flex",
      alignItems: "center",
      padding: 2,
      cursor: "pointer",
      transitionProperty: "background",
      transitionDuration: "var(--duration-fast)"
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 14,
      height: 14,
      borderRadius: "50%",
      background: checked ? "var(--emerald-950)" : "var(--color-text-secondary)",
      transform: checked ? "translateX(16px)" : "translateX(0)",
      transitionProperty: "transform,background",
      transitionDuration: "var(--duration-fast)"
    }
  }));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// components/navigation/Tabs.jsx
try { (() => {
function Tabs({
  items = [],
  value,
  onChange
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      gap: 4,
      borderBottom: "1px solid var(--color-border)"
    }
  }, items.map(it => {
    const active = it.value === value;
    return /*#__PURE__*/React.createElement("button", {
      key: it.value,
      onClick: () => onChange && onChange(it.value),
      style: {
        padding: "10px 14px",
        background: "transparent",
        border: "none",
        borderBottom: active ? "2px solid var(--color-accent)" : "2px solid transparent",
        color: active ? "var(--color-accent)" : "var(--color-text-secondary)",
        fontFamily: "var(--font-ui)",
        fontWeight: 600,
        fontSize: "var(--text-sm)",
        cursor: "pointer",
        transitionProperty: "color,border-color",
        transitionDuration: "var(--duration-fast)"
      }
    }, it.label);
  }));
}
Object.assign(__ds_scope, { Tabs });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/Tabs.jsx", error: String((e && e.message) || e) }); }

// components/overlay/Dialog.jsx
try { (() => {
function Dialog({
  open,
  title,
  children,
  onClose
}) {
  if (!open) return null;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: "absolute",
      inset: 0,
      background: "rgba(15,23,20,0.7)",
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      zIndex: 50
    },
    onClick: onClose
  }, /*#__PURE__*/React.createElement("div", {
    onClick: e => e.stopPropagation(),
    style: {
      width: 380,
      background: "var(--color-bg-surface)",
      border: "1px solid var(--color-border)",
      borderRadius: "var(--radius-lg)",
      padding: 20,
      fontFamily: "var(--font-ui)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center",
      marginBottom: 12
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--color-text-primary)",
      fontWeight: 700,
      letterSpacing: "var(--tracking-tight)",
      fontSize: "var(--text-lg)"
    }
  }, title), /*#__PURE__*/React.createElement("span", {
    onClick: onClose,
    style: {
      cursor: "pointer",
      color: "var(--color-text-secondary)"
    }
  }, "\xD7")), /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--color-text-secondary)",
      fontSize: "var(--text-base)",
      lineHeight: "var(--leading-body)"
    }
  }, children)));
}
Object.assign(__ds_scope, { Dialog });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/overlay/Dialog.jsx", error: String((e && e.message) || e) }); }

// components/surfaces/Card.jsx
try { (() => {
function Card({
  children,
  padding = 16
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      background: "var(--color-bg-surface)",
      border: "1px solid var(--color-border)",
      borderRadius: "var(--radius-lg)",
      padding
    }
  }, children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/surfaces/Card.jsx", error: String((e && e.message) || e) }); }

// ui_kits/minima-pdf-app/LibraryGrid.jsx
try { (() => {
const {
  Badge,
  ProgressBar
} = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;
function FileIcon() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "26",
    height: "26",
    viewBox: "0 0 40 40",
    fill: "none",
    stroke: "var(--color-text-secondary)",
    strokeWidth: "2"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "7",
    y: "5",
    width: "26",
    height: "30",
    rx: "3"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M14 14h12M14 20h12M14 26h7",
    strokeLinecap: "round"
  }));
}
function LibraryGrid({
  docs,
  onOpen
}) {
  const [hoverId, setHoverId] = React.useState(null);
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      padding: 28,
      overflow: "auto"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-ui)",
      fontWeight: 700,
      fontSize: "var(--text-xl)",
      letterSpacing: "var(--tracking-tight)",
      color: "var(--color-text-primary)",
      marginBottom: 4
    }
  }, "Your library"), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-ui)",
      fontSize: "var(--text-sm)",
      color: "var(--color-text-secondary)",
      marginBottom: 20
    }
  }, docs.length, " documents \xB7 stored on this device only"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "grid",
      gridTemplateColumns: "repeat(auto-fill, minmax(200px, 1fr))",
      gap: 14
    }
  }, docs.map(d => /*#__PURE__*/React.createElement("div", {
    key: d.id,
    onClick: () => onOpen(d),
    onMouseEnter: () => setHoverId(d.id),
    onMouseLeave: () => setHoverId(null),
    style: {
      background: "var(--color-bg-surface)",
      border: `1px solid ${hoverId === d.id ? "var(--sage-600)" : "var(--color-border)"}`,
      borderRadius: "var(--radius-lg)",
      padding: 14,
      cursor: "pointer",
      display: "flex",
      flexDirection: "column",
      gap: 10,
      transitionProperty: "border-color",
      transitionDuration: "var(--duration-fast)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "flex-start"
    }
  }, /*#__PURE__*/React.createElement(FileIcon, null), /*#__PURE__*/React.createElement(Badge, {
    tone: d.progress === 100 ? "neutral" : "accent"
  }, d.progress === 100 ? "Read" : `${d.progress}%`)), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-ui)",
      fontWeight: 600,
      fontSize: "var(--text-base)",
      color: "var(--color-text-primary)",
      lineHeight: "var(--leading-snug)"
    }
  }, d.title), /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-ui)",
      fontSize: "var(--text-xs)",
      color: "var(--color-text-secondary)"
    }
  }, d.pages, " pages \xB7 ", d.tag), /*#__PURE__*/React.createElement(ProgressBar, {
    value: d.progress
  })))));
}
window.LibraryGrid = LibraryGrid;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/minima-pdf-app/LibraryGrid.jsx", error: String((e && e.message) || e) }); }

// ui_kits/minima-pdf-app/ReaderView.jsx
try { (() => {
const {
  IconButton,
  ProgressBar
} = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;
function Back() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M15 18l-6-6 6-6"
  }));
}
function Bookmark() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75"
  }, /*#__PURE__*/React.createElement("path", {
    d: "M6 3h12v18l-6-4-6 4V3z"
  }));
}
function ZoomIn() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "11",
    r: "7"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M21 21l-4.3-4.3M11 8v6M8 11h6"
  }));
}
function ZoomOut() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "11",
    r: "7"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M21 21l-4.3-4.3M8 11h6"
  }));
}
function Panel() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "3",
    y: "4",
    width: "18",
    height: "16",
    rx: "2"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M15 4v16"
  }));
}
function ReaderView({
  doc,
  onBack,
  onToggleDrawer,
  bookmarked,
  onBookmark
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      flexDirection: "column",
      background: "var(--color-bg-canvas)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 10,
      padding: "10px 18px",
      borderBottom: "1px solid var(--color-border)",
      fontFamily: "var(--font-ui)"
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    title: "Back to library",
    onClick: onBack
  }, /*#__PURE__*/React.createElement(Back, null)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--color-text-primary)",
      fontWeight: 600,
      fontSize: "var(--text-base)",
      whiteSpace: "nowrap",
      overflow: "hidden",
      textOverflow: "ellipsis"
    }
  }, doc.title), /*#__PURE__*/React.createElement(ProgressBar, {
    value: doc.progress
  })), /*#__PURE__*/React.createElement(IconButton, {
    title: "Zoom out"
  }, /*#__PURE__*/React.createElement(ZoomOut, null)), /*#__PURE__*/React.createElement(IconButton, {
    title: "Zoom in"
  }, /*#__PURE__*/React.createElement(ZoomIn, null)), /*#__PURE__*/React.createElement(IconButton, {
    title: "Bookmark this page",
    active: bookmarked,
    onClick: onBookmark
  }, /*#__PURE__*/React.createElement(Bookmark, null)), /*#__PURE__*/React.createElement(IconButton, {
    title: "Toggle tool drawer",
    onClick: onToggleDrawer
  }, /*#__PURE__*/React.createElement(Panel, null))), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      padding: 32
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      width: 440,
      aspectRatio: "8.5/11",
      background: "var(--color-bg-surface)",
      border: "1px solid var(--color-border)",
      borderRadius: "var(--radius-md)",
      padding: 36,
      fontFamily: "var(--font-reader)",
      color: "var(--color-text-primary)",
      fontSize: 13,
      lineHeight: "var(--leading-reader)",
      overflow: "hidden"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontWeight: 700,
      fontSize: 17,
      marginBottom: 10
    }
  }, doc.title.replace(".pdf", "")), /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--color-text-secondary)"
    }
  }, "Section 4.2 \u2014 Findings", /*#__PURE__*/React.createElement("br", null), /*#__PURE__*/React.createElement("br", null), "The results indicate a measurable reduction in load time across all tested document sizes, consistent with the offline-first architecture described in Section 2. No network calls were observed during rendering..."))), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: "center",
      fontFamily: "var(--font-reader)",
      fontSize: 12,
      color: "var(--color-text-secondary)",
      paddingBottom: 14
    }
  }, "Page 42 of ", doc.pages));
}
window.ReaderView = ReaderView;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/minima-pdf-app/ReaderView.jsx", error: String((e && e.message) || e) }); }

// ui_kits/minima-pdf-app/SettingsPanel.jsx
try { (() => {
const {
  Dialog,
  Radio,
  Switch,
  Button
} = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;
function SettingsPanel({
  open,
  onClose,
  theme,
  onTheme,
  lowGlare,
  onLowGlare
}) {
  return /*#__PURE__*/React.createElement(Dialog, {
    open: open,
    title: "Settings",
    onClose: onClose
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 16
    }
  }, /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--color-text-primary)",
      fontWeight: 600,
      marginBottom: 8,
      fontSize: "var(--text-sm)"
    }
  }, "Reading theme"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 8
    }
  }, /*#__PURE__*/React.createElement(Radio, {
    checked: theme === "dark",
    label: "Low-Glare Dark",
    onChange: () => onTheme("dark")
  }), /*#__PURE__*/React.createElement(Radio, {
    checked: theme === "light",
    label: "Light Canvas",
    onChange: () => onTheme("light")
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      justifyContent: "space-between",
      alignItems: "center"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      color: "var(--color-text-primary)",
      fontWeight: 600,
      fontSize: "var(--text-sm)"
    }
  }, "Ultra-low-glare mode"), /*#__PURE__*/React.createElement(Switch, {
    checked: lowGlare,
    onChange: onLowGlare
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      borderTop: "1px solid var(--color-border)",
      paddingTop: 12,
      fontSize: "var(--text-xs)",
      color: "var(--color-text-secondary)"
    }
  }, "No cloud sync. No accounts. 100% offline, always."), /*#__PURE__*/React.createElement(Button, {
    variant: "secondary",
    onClick: onClose
  }, "Done")));
}
window.SettingsPanel = SettingsPanel;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/minima-pdf-app/SettingsPanel.jsx", error: String((e && e.message) || e) }); }

// ui_kits/minima-pdf-app/Sidebar.jsx
try { (() => {
const {
  Input,
  IconButton,
  Button
} = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;
function SearchIcon() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "14",
    height: "14",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "11",
    cy: "11",
    r: "7"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M21 21l-4.3-4.3"
  }));
}
function LibraryIcon() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75"
  }, /*#__PURE__*/React.createElement("rect", {
    x: "3",
    y: "4",
    width: "18",
    height: "16",
    rx: "2"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M3 9h18M8 4v5"
  }));
}
function SettingsIcon() {
  return /*#__PURE__*/React.createElement("svg", {
    width: "16",
    height: "16",
    viewBox: "0 0 24 24",
    fill: "none",
    stroke: "currentColor",
    strokeWidth: "1.75"
  }, /*#__PURE__*/React.createElement("circle", {
    cx: "12",
    cy: "12",
    r: "3"
  }), /*#__PURE__*/React.createElement("path", {
    d: "M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"
  }));
}
function Sidebar({
  tags,
  activeTag,
  onTag,
  onOpenSettings
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: "var(--panel-sidebar-w)",
      background: "var(--color-bg-sidebar)",
      borderRight: "1px solid var(--color-border)",
      display: "flex",
      flexDirection: "column",
      padding: 16,
      gap: 16,
      fontFamily: "var(--font-ui)"
    }
  }, /*#__PURE__*/React.createElement("img", {
    src: "../../assets/logo.svg",
    alt: "Minima PDF",
    style: {
      height: 24,
      width: "auto"
    }
  }), /*#__PURE__*/React.createElement(Input, {
    placeholder: "Search library\u2026",
    icon: /*#__PURE__*/React.createElement(SearchIcon, null)
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      color: "var(--color-accent)",
      fontSize: "var(--text-sm)",
      fontWeight: 600
    }
  }, /*#__PURE__*/React.createElement(LibraryIcon, null), " Library"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: "flex",
      flexDirection: "column",
      gap: 2
    }
  }, tags.map(t => /*#__PURE__*/React.createElement("div", {
    key: t,
    onClick: () => onTag(t),
    style: {
      padding: "7px 10px",
      borderRadius: "var(--radius-sm)",
      fontSize: "var(--text-sm)",
      cursor: "pointer",
      color: activeTag === t ? "var(--color-accent)" : "var(--color-text-secondary)",
      background: activeTag === t ? "rgba(200,154,90,0.1)" : "transparent",
      transitionProperty: "background,color",
      transitionDuration: "var(--duration-fast)"
    }
  }, t))), /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: "auto",
      display: "flex",
      flexDirection: "column",
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: onOpenSettings,
    style: {
      display: "flex",
      alignItems: "center",
      gap: 8,
      color: "var(--color-text-secondary)",
      fontSize: "var(--text-sm)",
      cursor: "pointer"
    }
  }, /*#__PURE__*/React.createElement(SettingsIcon, null), " Settings"), /*#__PURE__*/React.createElement("div", {
    style: {
      border: "1px solid var(--color-border)",
      borderRadius: "var(--radius-md)",
      padding: 10,
      fontSize: "var(--text-xs)",
      color: "var(--color-text-secondary)"
    }
  }, "Lifetime license \xB7 $1.99 \u2014 ", /*#__PURE__*/React.createElement("span", {
    style: {
      color: "var(--color-accent)"
    }
  }, "owned"))));
}
window.Sidebar = Sidebar;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/minima-pdf-app/Sidebar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/minima-pdf-app/ToolDrawer.jsx
try { (() => {
const {
  Tabs
} = window.MinimaPDFHermesObsidianDesignSystem_1b8fb1;
const outline = ["1. Introduction", "2. Related Work", "3. Method", "4. Findings", "5. Discussion", "6. Conclusion"];
const notes = [{
  page: 12,
  text: "Revisit this claim — check citation."
}, {
  page: 42,
  text: "Strong result, use in summary."
}];
function ToolDrawer({
  tab,
  onTab
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      width: "var(--panel-drawer-w)",
      background: "var(--color-bg-sidebar)",
      borderLeft: "1px solid var(--color-border)",
      display: "flex",
      flexDirection: "column",
      fontFamily: "var(--font-ui)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: "10px 14px 0"
    }
  }, /*#__PURE__*/React.createElement(Tabs, {
    items: [{
      label: "Outline",
      value: "outline"
    }, {
      label: "Bookmarks",
      value: "bookmarks"
    }, {
      label: "Notes",
      value: "notes"
    }],
    value: tab,
    onChange: onTab
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: 16,
      overflow: "auto"
    }
  }, tab === "outline" && outline.map(o => /*#__PURE__*/React.createElement("div", {
    key: o,
    style: {
      padding: "8px 4px",
      fontSize: "var(--text-sm)",
      color: "var(--color-text-secondary)",
      borderBottom: "1px solid var(--color-border)",
      cursor: "pointer"
    }
  }, o)), tab === "bookmarks" && /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "var(--text-sm)",
      color: "var(--color-text-secondary)"
    }
  }, "Page 42 bookmarked"), tab === "notes" && notes.map(n => /*#__PURE__*/React.createElement("div", {
    key: n.page,
    style: {
      marginBottom: 10,
      padding: 10,
      border: "1px solid var(--color-border)",
      borderRadius: "var(--radius-md)",
      background: "var(--color-bg-surface)"
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      fontFamily: "var(--font-reader)",
      fontSize: 13,
      color: "var(--color-text-primary)",
      fontStyle: "italic"
    }
  }, n.text), /*#__PURE__*/React.createElement("div", {
    style: {
      fontSize: "var(--text-xs)",
      color: "var(--color-text-secondary)",
      marginTop: 4
    }
  }, "Page ", n.page)))));
}
window.ToolDrawer = ToolDrawer;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/minima-pdf-app/ToolDrawer.jsx", error: String((e && e.message) || e) }); }

// ui_kits/minima-pdf-app/data.js
try { (() => {
const docs = [{
  id: 1,
  title: "Q3 Research Notes.pdf",
  pages: 142,
  progress: 62,
  tag: "Research"
}, {
  id: 2,
  title: "Contract — NDA Draft.pdf",
  pages: 8,
  progress: 100,
  tag: "Contracts"
}, {
  id: 3,
  title: "Distributed Systems, 3rd Ed.pdf",
  pages: 612,
  progress: 18,
  tag: "Reference"
}, {
  id: 4,
  title: "Faculty Meeting Minutes.pdf",
  pages: 4,
  progress: 0,
  tag: "Admin"
}, {
  id: 5,
  title: "Grant Proposal — Draft 4.pdf",
  pages: 26,
  progress: 45,
  tag: "Research"
}, {
  id: 6,
  title: "Thesis — Chapter 2.pdf",
  pages: 51,
  progress: 88,
  tag: "Research"
}];
function LibraryData() {
  return docs;
}
window.LibraryData = LibraryData;
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/minima-pdf-app/data.js", error: String((e && e.message) || e) }); }

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.ProgressBar = __ds_scope.ProgressBar;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.Tooltip = __ds_scope.Tooltip;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Radio = __ds_scope.Radio;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.Tabs = __ds_scope.Tabs;

__ds_ns.Dialog = __ds_scope.Dialog;

__ds_ns.Card = __ds_scope.Card;

})();
