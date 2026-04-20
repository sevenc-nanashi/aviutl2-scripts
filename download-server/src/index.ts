import { Hono } from "hono";
import { resolveVersionEntries, selectVersionEntry } from "./resolve";
import { fetchScriptContent } from "./utils";

const app = new Hono();
app.get("/:scriptName", async (c) => {
  const { scriptName } = c.req.param();

  let scriptContent: string;
  try {
    const version = c.req.query("version");
    const entries = await resolveVersionEntries(scriptName);
    const entry = selectVersionEntry(entries, scriptName, version);
    scriptContent = await fetchScriptContent(scriptName, entry);
  } catch (error) {
    console.error(error);
    return c.text("Script not found", 404);
  }
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
