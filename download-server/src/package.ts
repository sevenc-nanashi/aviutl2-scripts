import JSZip from "jszip";
import {
  fetchJson,
  fetchRepositoryTree,
  fetchText,
  githubRawBaseUrl,
  rawUrlForPath,
  repository,
} from "./utils";

export type I18nFile = {
  name: string;
  content: string;
};

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

export async function getI18nFiles(
  scriptName: string,
  commit: string,
): Promise<I18nFile[]> {
  const baseName = scriptName.split(".")[0];
  const i18nDir = `scripts/${baseName}/i18n/`;
  const tree = await fetchRepositoryTree(commit);
  const i18nPaths = tree
    .filter((entry) => entry.type === "blob")
    .map((entry) => entry.path)
    .filter((path) => path.startsWith(i18nDir) && path.endsWith(".aul2"))
    .sort();

  return Promise.all(
    i18nPaths.map(async (path) => {
      const name = path.slice(i18nDir.length);
      if (name.includes("/")) {
        throw new Error(`Nested i18n file is not supported: ${path}`);
      }
      return {
        name,
        content: await fetchText(rawUrlForPath(path, commit)),
      };
    }),
  );
}

export async function packageScript(
  scriptId: string,
  scriptName: string,
  scriptContent: string,
  readmeContent: string,
  i18nFiles: I18nFile[],
): Promise<Uint8Array<ArrayBuffer>> {
  const zip = new JSZip();
  zip.file(`Script/${scriptName}`, scriptContent);
  for (const i18nFile of i18nFiles) {
    zip.file(`Language/${i18nFile.name}`, i18nFile.content);
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
