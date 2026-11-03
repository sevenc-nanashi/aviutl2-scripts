import JSZip from "jszip";
import {
  fetchBinary,
  fetchJson,
  fetchRepositoryTree,
  fetchText,
  githubRawBaseUrl,
  rawUrlForPath,
  repository,
} from "./utils";

export type ExtraFile = {
  name: string;
  content: ArrayBuffer;
};

export async function getPlainReadme(
  scriptName: string,
  commit: string,
): Promise<string> {
  const baseName = scriptName.split(".")[0];
  const readmeUrl = `${githubRawBaseUrl}/${repository}/${commit}/scripts/${encodeURIComponent(baseName)}/readme.lua`;
  const readme = await fetchText(readmeUrl);
  return `${readme
    .replace(/^--( |$)/gm, "")
    .replaceAll("=".repeat(120), "")
    .trim()}\n`;
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

export async function getExtraFiles(
  scriptName: string,
  commit: string,
): Promise<ExtraFile[]> {
  const baseName = scriptName.split(".")[0];
  const extraDir = `scripts/${baseName}/extra/`;
  const tree = await fetchRepositoryTree(commit);
  const extraPaths = tree
    .filter((entry) => entry.type === "blob")
    .map((entry) => entry.path)
    .filter((path) => path.startsWith(extraDir))
    .sort();

  return Promise.all(
    extraPaths.map(async (path) => {
      const name = path.slice(extraDir.length);
      return {
        name,
        content: await fetchBinary(rawUrlForPath(path, commit)),
      };
    }),
  );
}

export async function packageScript(
  scriptId: string,
  scriptName: string,
  scriptContent: string,
  readmeContent: string,
  extraFiles: ExtraFile[],
): Promise<Uint8Array<ArrayBuffer>> {
  const zip = new JSZip();
  zip.file(`Script/${scriptName}`, scriptContent);
  for (const extraFile of extraFiles) {
    zip.file(extraFile.name, extraFile.content);
  }
  zip.file("package.txt", readmeContent.replaceAll("\n", "\r\n"));
  const basename = scriptName.split(".")[0];
  zip.file(
    "package.ini",
    `[package]\nid=${scriptId}\nname=${scriptName}\ninformation=https://github.com/sevenc-nanashi/aviutl2-scripts/blob/main/scripts/${encodeURIComponent(
      basename,
    )}/README.md\n`,
  );
  return (await zip.generateAsync({
    type: "uint8array",
  })) as Uint8Array<ArrayBuffer>;
}
