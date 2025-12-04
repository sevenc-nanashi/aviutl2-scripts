import { Hono } from "hono";
import { pathcat } from "pathcat";

const app = new Hono();

app.get("/:scriptName", async (c) => {
  const { scriptName } = c.req.param();

  const url = pathcat(
    "https://raw.githubusercontent.com/sevenc-nanashi/aviutl2-scripts/refs/heads/main/scripts/:scriptName",
    { scriptName },
  );
  const res = await fetch(url);
  if (!res.ok) {
    return c.text("Script not found", 404);
  }
  const scriptContent = await res.text();
	const escapedScriptName = encodeURIComponent(scriptName);
  return c.text(scriptContent, 200, {
    "Content-Disposition": `attachment; filename="${escapedScriptName}"`,
    "Content-Type": "application/octet-stream",
  });
});

app.get("/", (c) => {
  return c.redirect("https://github.com/sevenc-nanashi/aviutl2-scripts", 302);
});

app.get("*", (c) => {
  return c.text("404 Not Found", 404);
});

export default app;
