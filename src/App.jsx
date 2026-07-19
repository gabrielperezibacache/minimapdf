import React from "react";
import { IconButton } from "@ds";
import { Brand } from "./components/Brand.jsx";
import { LibraryGrid } from "./components/LibraryGrid.jsx";
import { ReaderView } from "./components/ReaderView.jsx";
import { SettingsPanel } from "./components/SettingsPanel.jsx";
import { Sidebar } from "./components/Sidebar.jsx";
import { ToolDrawer } from "./components/ToolDrawer.jsx";
import { LIBRARY_DOCS, LIBRARY_TAGS } from "./data/library.js";
import { MenuIcon } from "./icons.jsx";

export default function App() {
  const [screen, setScreen] = React.useState("library");
  const [activeDoc, setActiveDoc] = React.useState(null);
  const [activeTag, setActiveTag] = React.useState("All");
  const [search, setSearch] = React.useState("");
  const [drawerOpen, setDrawerOpen] = React.useState(true);
  const [drawerTab, setDrawerTab] = React.useState("outline");
  const [settingsOpen, setSettingsOpen] = React.useState(false);
  const [theme, setTheme] = React.useState("dark");
  const [lowGlare, setLowGlare] = React.useState(true);
  const [bookmarked, setBookmarked] = React.useState(false);
  const [zoom, setZoom] = React.useState(1);
  const [sidebarOpen, setSidebarOpen] = React.useState(false);

  React.useEffect(() => {
    document.documentElement.setAttribute("data-theme", theme);
  }, [theme]);

  React.useEffect(() => {
    document.documentElement.style.filter = lowGlare && theme === "dark" ? "saturate(0.92) brightness(0.98)" : "none";
  }, [lowGlare, theme]);

  const filtered = LIBRARY_DOCS.filter((doc) => {
    const tagOk = activeTag === "All" || doc.tag === activeTag;
    const q = search.trim().toLowerCase();
    const searchOk = !q || doc.title.toLowerCase().includes(q) || doc.tag.toLowerCase().includes(q);
    return tagOk && searchOk;
  });

  return (
    <div className="app-shell" data-theme={theme} data-sidebar-open={sidebarOpen ? "true" : "false"}>
      <div className="sidebar-scrim" onClick={() => setSidebarOpen(false)} aria-hidden="true" />
      <Sidebar
        tags={LIBRARY_TAGS}
        activeTag={activeTag}
        onTag={setActiveTag}
        search={search}
        onSearch={setSearch}
        onOpenSettings={() => setSettingsOpen(true)}
        onNavigate={() => setSidebarOpen(false)}
      />
      <div className="app-main">
        <div className="mobile-topbar">
          <IconButton title="Open library menu" onClick={() => setSidebarOpen(true)}>
            <MenuIcon />
          </IconButton>
          <Brand compact={false} />
        </div>
        {screen === "library" && (
          <LibraryGrid
            docs={filtered}
            onOpen={(doc) => {
              setActiveDoc(doc);
              setScreen("reader");
              setBookmarked(false);
              setZoom(1);
              setSidebarOpen(false);
            }}
          />
        )}
        {screen === "reader" && activeDoc && (
          <div className="app-reader-row">
            <ReaderView
              doc={activeDoc}
              onBack={() => setScreen("library")}
              onToggleDrawer={() => setDrawerOpen((v) => !v)}
              bookmarked={bookmarked}
              onBookmark={() => setBookmarked((v) => !v)}
              zoom={zoom}
              onZoomIn={() => setZoom((z) => Math.min(1.4, Number((z + 0.1).toFixed(1))))}
              onZoomOut={() => setZoom((z) => Math.max(0.8, Number((z - 0.1).toFixed(1))))}
            />
            {drawerOpen && <ToolDrawer tab={drawerTab} onTab={setDrawerTab} bookmarked={bookmarked} />}
          </div>
        )}
      </div>
      <SettingsPanel
        open={settingsOpen}
        onClose={() => setSettingsOpen(false)}
        theme={theme}
        onTheme={setTheme}
        lowGlare={lowGlare}
        onLowGlare={() => setLowGlare((v) => !v)}
      />
    </div>
  );
}
