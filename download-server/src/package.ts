import JSZip from "jszip";
import { fetchJson, fetchText, githubRawBaseUrl, repository } from "./utils";

export async function getPlainReadme(
  scriptName: string,
  commit: string,
): Promise<string> {
  const baseName = scriptName.split(".")[0];
  const readmeUrl = `${githubRawBaseUrl}/${repository}/${commit}/scripts/${encodeURIComponent(baseName)}/readme.lua`;
  const readme = await fetchText(readmeUrl);
  return (
    readme
      .replace(/^--( |$)/gm, "")
      .replaceAll("=".repeat(120), "")
      .trim() + "\n"
  );
}

export async function getScriptId(
  scriptName: string,
): Promise<string | undefined> {
  const index = await fetchJson<
    {
      id: string;
      name: string;
      author: string;
    }[]
  >(
    "https://raw.githubusercontent.com/Neosku/aviutl2-catalog-data/refs/heads/main/index.json",
  );
  const entry = index.find(
    (entry) => entry.author === "Nanashi." && entry.name === scriptName,
  );
  if (entry === undefined) {
    return undefined;
  }
  return entry.id;
}

export async function packageScript(
  scriptId: string,
  scriptName: string,
  scriptContent: string,
  readmeContent: string,
): Promise<Uint8Array<ArrayBuffer>> {
  const zip = new JSZip();
  zip.file(`Script/${scriptName}`, scriptContent);
  zip.file("package.txt", readmeContent);
  const basename = scriptName.split(".")[0];
  zip.file(
    "package.ini",
    `[package]\nid=${scriptId}\nname=${scriptName}\ninformation=https://github.com/sevenc-nanashi/aviutl2-scripts/blob/main/scripts/${encodeURIComponent(
      basename,
    )}/README.md\n`,
  );
  return await zip.generateAsync({ type: "uint8array" }) as Uint8Array<ArrayBuffer>;
}
