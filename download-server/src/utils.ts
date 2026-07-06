import { env } from "cloudflare:workers";
import * as v from "valibot";

export const repository = "sevenc-nanashi/aviutl2-scripts";
export const githubApiBaseUrl = "https://api.github.com/repos";
export const githubRawBaseUrl = "https://raw.githubusercontent.com";

export const mainRef = "refs/heads/main";
export const latestReadmeCloudflareCacheTtlSec = 10;
export const versionLookupCloudflareCacheTtlSec = 60 * 60;
export const scriptCloudflareCacheTtlSec = 60 * 60 * 24 * 7;

type GitHubCommit = {
  sha: string;
};

const GitTreeSchema = v.object({
  tree: v.array(
    v.object({
      path: v.string(),
      type: v.string(),
    }),
  ),
});

export type GitTreeEntry = v.InferOutput<typeof GitTreeSchema>["tree"][number];

export type ChangelogHeader = {
  version: string;
  commit: string | null;
};

export type VersionEntry = {
  version: string;
  commit: string;
};

type GitHubFetchOptions = {
  cloudflareCacheTtlSec?: number;
};

export function parseChangelogHeaders(content: string): ChangelogHeader[] {
  const changelogStart = content
    .split("\n")
    .findIndex((line) => line.trimEnd() === "# 更新履歴");
  if (changelogStart === -1) {
    return [];
  }
  return content
    .split("\n")
    .slice(changelogStart)
    .flatMap((line) => {
      const match = line.match(/^## v(?<version>[0-9.]+)/);
      if (match?.groups === undefined) {
        return [];
      }
      const { version } = match.groups;
      if (version === undefined) {
        throw new Error("Version is undefined");
      }
      const override = line.match(
        /<!-- commit-override: (?<commit>[0-9a-f]{7,40}) -->/,
      );
      const commit = override?.groups?.commit;
      return [{ version, commit: commit === undefined ? null : commit }];
    });
}

export async function fetchReadmeCommits(
  readmePath: string,
): Promise<string[]> {
  const searchParams = new URLSearchParams({
    path: readmePath,
    per_page: "100",
  });
  const url = `${githubApiBaseUrl}/${repository}/commits?${searchParams}`;
  const commits = await fetchJson<GitHubCommit[]>(url, {
    cloudflareCacheTtlSec: latestReadmeCloudflareCacheTtlSec,
  });
  return commits.map((commit) => commit.sha);
}

export async function resolveCommitSha(commit: string): Promise<string> {
  const url = `${githubApiBaseUrl}/${repository}/commits/${commit}`;
  const resolvedCommit = await fetchJson<GitHubCommit>(url, {
    cloudflareCacheTtlSec: versionLookupCloudflareCacheTtlSec,
  });
  return resolvedCommit.sha;
}

export async function fetchRepositoryTree(
  commit: string,
): Promise<GitTreeEntry[]> {
  const url = `${githubApiBaseUrl}/${repository}/git/trees/${commit}?recursive=1`;
  const tree = await fetchJson<unknown>(url, {
    cloudflareCacheTtlSec: scriptCloudflareCacheTtlSec,
  });
  return v.parse(GitTreeSchema, tree).tree;
}

export async function fetchText(
  url: string,
  options: GitHubFetchOptions = {},
): Promise<string> {
  const res = await fetch(url, githubRequestInit(options));
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url}: ${res.status}`);
  }
  return res.text();
}

export async function fetchJson<T>(
  url: string,
  options: GitHubFetchOptions = {},
): Promise<T> {
  const res = await fetch(url, githubRequestInit(options));
  if (!res.ok) {
    throw new Error(`Failed to fetch ${url}: ${res.status}`);
  }
  return (await res.json()) as T;
}

export async function fetchScriptContent(
  scriptName: string,
  entry: VersionEntry,
): Promise<string> {
  return fetchText(rawUrlForPath(`scripts/${scriptName}`, entry.commit), {
    cloudflareCacheTtlSec: scriptCloudflareCacheTtlSec,
  });
}

function githubHeaders(): HeadersInit {
  return {
    Accept: "application/vnd.github+json",
    "User-Agent": "aviutl2-scripts-download-server",
    Authorization: `token ${env.GITHUB_TOKEN}`,
  };
}

function githubRequestInit(options: GitHubFetchOptions): RequestInit {
  const cf =
    options.cloudflareCacheTtlSec === undefined
      ? undefined
      : {
          cacheEverything: true,
          cacheTtlByStatus: {
            "200-299": options.cloudflareCacheTtlSec,
            "400-599": 0,
          },
        };
  return {
    headers: githubHeaders(),
    cf,
  };
}

export function rawUrlForPath(path: string, ref: string): string {
  return `${githubRawBaseUrl}/${repository}/${ref}/${encodePath(path)}`;
}

function encodePath(path: string): string {
  return path.split("/").map(encodeURIComponent).join("/");
}

export function readmePathForScript(scriptName: string): string {
  return `scripts/${scriptDir(scriptName)}/README.md`;
}

function scriptDir(scriptName: string): string {
  const extensionStart = scriptName.lastIndexOf(".");
  if (extensionStart === -1) {
    throw new Error(`Script name has no extension: ${scriptName}`);
  }
  return scriptName.slice(0, extensionStart);
}
