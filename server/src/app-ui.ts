// The window a host with MCP Apps shows next to get_view (#624, extension io.modelcontextprotocol/ui, spec 2026-01-26).
// Schnitt 1: only a placeholder on the app's paper, light and dark; no script and no outside source (no _meta.ui.csp, so the
// host allows nothing external). Schnitt 2 replaces the content with the list.
export const UI_URI = "ui://loose-ends/view.html";
export const UI_MIME = "text/html;profile=mcp-app";

export const viewHtml: string = `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Loose Ends</title>
<style>
:root { --paper: #F4F3EE; --ink: #1B1C19; --quiet: #77786F; --rule: #DCDBD3; color-scheme: light dark;
  --serif: ui-serif, "New York", Georgia, "Times New Roman", serif; }
@media (prefers-color-scheme: dark) {
  :root { --paper: #171816; --ink: #ECECE6; --quiet: #8E8F88; --rule: #2E2F2B; }
}
body { margin: 0; background: var(--paper); color: var(--ink); font-family: var(--serif); }
main { padding: 16px 18px; border-top: 1px solid var(--rule); }
h1 { margin: 0; font-size: 17px; font-weight: 600; }
p { margin: 4px 0 0; font-size: 14px; font-style: italic; color: var(--quiet); }
</style>
</head>
<body>
<main>
<h1>Loose Ends</h1>
<p>Die Ansicht folgt.</p>
</main>
</body>
</html>
`;
