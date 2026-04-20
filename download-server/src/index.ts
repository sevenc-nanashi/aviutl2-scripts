import { sValidator } from "@hono/standard-validator";
import { Hono } from "hono";
import * as v from "valibot";
import {
  doesScriptExist,
  resolveVersionEntries,
  selectVersionEntry,
} from "./resolve";
import { fetchScriptContent } from "./utils";
import { getPlainReadme, getScriptId, packageScript } from "./package";

const app = new Hono();

const scriptQueries = v.object({
  version: v.optional(
    v.pipe(
      v.string(),
      v.check((str) => {
        if (str === "latest") {
          return true;
        }
        return /^v?[0-9]+(\.[0-9]+)*$/.test(str);
      }, "Invalid version format"),
      v.transform((str) => {
        if (str === "latest") {
          return "latest";
        }
        return str.replace(/^v/, "");
      }),
    ),
    "latest",
  ),
  type: v.optional(
    v.picklist(["script", "releases", "au2pkg"] as const),
    "script" as const,
  ),
});

app.get("/:scriptName", sValidator("query", scriptQueries), async (c) => {
  const { scriptName } = c.req.param();
  const { version: versionSpecifier, type: requestedType } =
    c.req.valid("query");

  if (!(await doesScriptExist(scriptName))) {
    return c.text(`Script "${scriptName}" not found`, 404);
  }

  switch (requestedType) {
    case "releases": {
      const entries = await resolveVersionEntries(scriptName);
      return c.json({
        releases: entries,
      });
    }
    case "au2pkg": {
      const scriptId = await getScriptId(scriptName);
      if (!scriptId) {
        return c.text(
          `Script "${scriptName}" not found in catalog, please wait for it to be indexed.`,
          503,
        );
      }
      const entries = await resolveVersionEntries(scriptName);
      const entry = selectVersionEntry(entries, scriptName, versionSpecifier);
      const scriptContent = await fetchScriptContent(scriptName, entry);
      const plainReadme = await getPlainReadme(scriptName, entry.commit);
      const escapedScriptName = encodeURIComponent(`${scriptName}.au2pkg.zip`);
      const packaged = await packageScript(
        scriptId,
        scriptName,
        scriptContent,
        plainReadme,
      );
      return c.body(packaged, 200, {
        "Content-Disposition": `attachment; filename="${escapedScriptName}"`,
        "Content-Type": "application/zip",
        "X-Script-Version": entry.version,
        "X-Script-Commit": entry.commit ?? "unknown",
      });
    }
    case "script": {
      const entries = await resolveVersionEntries(scriptName);
      const entry = selectVersionEntry(entries, scriptName, versionSpecifier);
      const scriptContent = await fetchScriptContent(scriptName, entry);
      const escapedScriptName = encodeURIComponent(scriptName);
      return c.text(scriptContent, 200, {
        "Content-Disposition": `attachment; filename="${escapedScriptName}"`,
        "Content-Type": "application/octet-stream",
        "X-Script-Version": entry.version,
        "X-Script-Commit": entry.commit ?? "unknown",
      });
    }
  }
});

app.get("/", (c) => {
  return c.redirect("https://github.com/sevenc-nanashi/aviutl2-scripts", 302);
});

app.get("*", (c) => {
  return c.text("404 Not Found", 404);
});

export default app;
