import { env } from "cloudflare:workers";
import { Hono } from "hono";

const app = new Hono();
const repository = "sevenc-nanashi/aviutl2-scripts";
const mainRef = "refs/heads/main";
const githubApiBaseUrl = "https://api.github.com/repos";
const githubRawBaseUrl = "https://raw.githubusercontent.com";
const latestReadmeCloudflareCacheTtlSec = 10;
const versionLookupCloudflareCacheTtlSec = 60 * 60;
const scriptCloudflareCacheTtlSec = 60 * 60 * 24 * 7;

type GitHubCommit = {
	sha: string;
};

type ChangelogHeader = {
	version: string;
	commit: string | null;
};

type VersionEntry = {
	version: string;
	commit: string;
};

type GitHubFetchOptions = {
	cloudflareCacheTtlSec?: number;
};

app.get("/:scriptName", async (c) => {
	const { scriptName } = c.req.param();

	let scriptContent: string;
	try {
		const version = c.req.query("version");
		const entry =
			version === undefined
				? await resolveLatestVersionEntry(scriptName)
				: await resolveVersionEntry(scriptName, version);
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

async function resolveLatestVersionEntry(
	scriptName: string,
): Promise<VersionEntry> {
	const headers = await resolveVersionHeaders(scriptName);
	const latestHeader = headers[0];
	if (latestHeader === undefined) {
		throw new Error(
			`No changelog versions found in ${readmePathForScript(scriptName)}`,
		);
	}

	return findVersionEntry(scriptName, latestHeader);
}

async function resolveVersionEntry(
	scriptName: string,
	versionSpecifier: string,
): Promise<VersionEntry> {
	const version = normalizeVersionSpecifier(versionSpecifier);
	const headers = await resolveVersionHeaders(scriptName);
	const header = findVersionHeader(headers, scriptName, version);

	return findVersionEntry(scriptName, header);
}

function findVersionHeader(
	headers: ChangelogHeader[],
	scriptName: string,
	version: string,
): ChangelogHeader {
	const header = headers.find((header) => header.version === version);
	if (header === undefined) {
		throw new Error(
			`Could not find version ${version} in ${readmePathForScript(scriptName)}`,
		);
	}
	return header;
}

async function resolveVersionHeaders(
	scriptName: string,
): Promise<ChangelogHeader[]> {
	const headers = await findVersionHeaders(scriptName);
	return headers;
}

async function findVersionHeaders(
	scriptName: string,
): Promise<ChangelogHeader[]> {
	const readmePath = readmePathForScript(scriptName);
	const readmeContent = await fetchText(rawUrlForPath(readmePath, mainRef), {
		cloudflareCacheTtlSec: latestReadmeCloudflareCacheTtlSec,
	});
	const headers = parseChangelogHeaders(readmeContent);
	if (headers.length === 0) {
		throw new Error(`No changelog versions found in ${readmePath}`);
	}
	return headers;
}

async function findVersionEntry(
	scriptName: string,
	latestHeader: ChangelogHeader,
): Promise<VersionEntry> {
	const readmePath = readmePathForScript(scriptName);
	const overrideCommit = latestHeader.commit;
	if (overrideCommit !== null) {
		return { version: latestHeader.version, commit: overrideCommit };
	}

	const readmeCommits = await fetchReadmeCommits(readmePath);
	const chronologicalCommits = [...readmeCommits].reverse();
	const versionCommit = await findFirstCommitWithVersion(
		chronologicalCommits,
		readmePath,
		latestHeader.version,
	);
	if (versionCommit === undefined) {
		throw new Error(
			`Could not find commit for version ${latestHeader.version} in ${readmePath}`,
		);
	}
	return { version: latestHeader.version, commit: versionCommit };
}

function parseChangelogHeaders(content: string): ChangelogHeader[] {
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

async function fetchReadmeCommits(readmePath: string): Promise<string[]> {
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

async function findFirstCommitWithVersion(
	commits: string[],
	readmePath: string,
	version: string,
): Promise<string | undefined> {
	let low = 0;
	let high = commits.length - 1;
	let firstCommit: string | undefined;
	while (low <= high) {
		const middle = Math.floor((low + high) / 2);
		const commit = commits[middle];
		if (commit === undefined) {
			throw new Error(`Commit is undefined at index ${middle}`);
		}
		if (await commitHasVersion(commit, readmePath, version)) {
			firstCommit = commit;
			high = middle - 1;
		} else {
			low = middle + 1;
		}
	}
	return firstCommit;
}

async function commitHasVersion(
	commit: string,
	readmePath: string,
	version: string,
): Promise<boolean> {
	const readmeContent = await fetchText(rawUrlForPath(readmePath, commit), {
		cloudflareCacheTtlSec: versionLookupCloudflareCacheTtlSec,
	});
	const versions = parseChangelogHeaders(readmeContent);
	return versions.some((header) => header.version === version);
}

async function fetchText(
	url: string,
	options: GitHubFetchOptions = {},
): Promise<string> {
	const res = await fetch(url, githubRequestInit(options));
	if (!res.ok) {
		throw new Error(`Failed to fetch ${url}: ${res.status}`);
	}
	return res.text();
}

async function fetchJson<T>(
	url: string,
	options: GitHubFetchOptions = {},
): Promise<T> {
	const res = await fetch(url, githubRequestInit(options));
	if (!res.ok) {
		throw new Error(`Failed to fetch ${url}: ${res.status}`);
	}
	return (await res.json()) as T;
}

async function fetchScriptContent(
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

function rawUrlForPath(path: string, ref: string): string {
	return `${githubRawBaseUrl}/${repository}/${ref}/${encodePath(path)}`;
}

function encodePath(path: string): string {
	return path.split("/").map(encodeURIComponent).join("/");
}

function normalizeVersionSpecifier(versionSpecifier: string): string {
	const version = versionSpecifier.replace(/^v/, "");
	if (!version.match(/^[0-9.]+$/)) {
		throw new Error(`Invalid version specifier: ${versionSpecifier}`);
	}
	return version;
}

function readmePathForScript(scriptName: string): string {
	return `scripts/${scriptDir(scriptName)}/README.md`;
}

function scriptDir(scriptName: string): string {
	const extensionStart = scriptName.lastIndexOf(".");
	if (extensionStart === -1) {
		throw new Error(`Script name has no extension: ${scriptName}`);
	}
	return scriptName.slice(0, extensionStart);
}

export default app;
