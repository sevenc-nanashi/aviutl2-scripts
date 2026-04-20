import { env } from "cloudflare:workers";
import { Hono } from "hono";

const app = new Hono();
const repository = "sevenc-nanashi/aviutl2-scripts";
const mainRef = "refs/heads/main";
const githubApiBaseUrl = "https://api.github.com/repos";
const githubRawBaseUrl = "https://raw.githubusercontent.com";
const latestHeaderCacheTtlMs = 10 * 1000;
const latestHeaderCloudflareCacheTtlSec = 10;
const versionHeadersCloudflareCacheTtlSec = 60 * 60;
const versionHeadersCacheTtlMs = versionHeadersCloudflareCacheTtlSec * 1000;
const scriptCloudflareCacheTtlSec = 60 * 60 * 24 * 7;
const cacheUrlBase = "https://aviutl2-scripts-download-cache.local";
const latestHeaderCache = new Map<string, LatestHeaderCacheEntry>();
const versionHeadersCache = new Map<string, VersionHeadersCacheEntry>();
const versionEntryCache = new Map<string, Promise<VersionEntry>>();

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

type LatestHeaderCacheEntry = {
	expiresAt: number;
	promise: Promise<ChangelogHeader>;
};

type VersionHeadersCacheEntry = {
	expiresAt: number;
	promise: Promise<ChangelogHeader[]>;
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
		scriptContent = await fetchCachedScriptContent(
			scriptName,
			entry,
			version === undefined,
		);
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
	const cachedEntry = await resolveCachedVersionEntry(
		scriptName,
		latestHeader.version,
	);
	if (cachedEntry?.version === latestHeader.version) {
		return cachedEntry;
	}

	return setVersionEntryCache(scriptName, latestHeader);
}

async function resolveVersionEntry(
	scriptName: string,
	versionSpecifier: string,
): Promise<VersionEntry> {
	const version = normalizeVersionSpecifier(versionSpecifier);
	const headers = await resolveVersionHeaders(scriptName);
	const header = findVersionHeader(headers, scriptName, version);
	const cachedEntry = await resolveCachedVersionEntry(scriptName, version);
	if (cachedEntry !== undefined) {
		return cachedEntry;
	}

	return setVersionEntryCache(scriptName, header);
}

function setVersionEntryCache(
	scriptName: string,
	header: ChangelogHeader,
): Promise<VersionEntry> {
	const cacheKey = versionEntryCacheKey(scriptName, header.version);
	const promise = findVersionEntry(scriptName, header).catch((error) => {
		versionEntryCache.delete(cacheKey);
		throw error;
	});
	versionEntryCache.set(cacheKey, promise);
	return promise;
}

async function resolveLatestHeader(
	scriptName: string,
): Promise<ChangelogHeader> {
	const now = Date.now();
	let entry = latestHeaderCache.get(scriptName);
	if (entry === undefined || entry.expiresAt <= now) {
		const cachedHeader = await getCachedLatestHeader(scriptName);
		const promise =
			cachedHeader === undefined
				? findLatestHeader(scriptName)
						.then(async (header) => {
							await putCachedLatestHeader(scriptName, header);
							return header;
						})
						.catch((error) => {
							latestHeaderCache.delete(scriptName);
							throw error;
						})
				: Promise.resolve(cachedHeader);
		entry = { expiresAt: now + latestHeaderCacheTtlMs, promise };
		latestHeaderCache.set(scriptName, entry);
	}
	return entry.promise;
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
	const latestHeader = await resolveLatestHeader(scriptName);
	const cachedHeaders = await getCachedVersionHeaders(scriptName);
	if (cachedHeaders !== undefined) {
		const cachedLatestHeader = cachedHeaders[0];
		if (cachedLatestHeader === undefined) {
			throw new Error(
				`No changelog versions found in ${readmePathForScript(scriptName)}`,
			);
		}
		if (sameChangelogHeader(cachedLatestHeader, latestHeader)) {
			return cachedHeaders;
		}
		await purgeVersionCaches(scriptName, cachedHeaders);
	}

	let entry = versionHeadersCache.get(scriptName);
	const now = Date.now();
	if (entry === undefined || entry.expiresAt <= now) {
		const promise = findVersionHeaders(scriptName).catch((error) => {
			versionHeadersCache.delete(scriptName);
			throw error;
		});
		entry = { expiresAt: now + versionHeadersCacheTtlMs, promise };
		versionHeadersCache.set(scriptName, entry);
	}
	const headers = await entry.promise;
	await putCachedVersionHeaders(scriptName, headers);
	return headers;
}

async function resolveCachedVersionEntry(
	scriptName: string,
	version: string,
): Promise<VersionEntry | undefined> {
	const cacheKey = versionEntryCacheKey(scriptName, version);
	const promise = versionEntryCache.get(cacheKey);
	if (promise === undefined) {
		return undefined;
	}
	try {
		return await promise;
	} catch {
		versionEntryCache.delete(cacheKey);
		return undefined;
	}
}

async function findVersionHeaders(
	scriptName: string,
): Promise<ChangelogHeader[]> {
	const readmePath = readmePathForScript(scriptName);
	const readmeContent = await fetchText(rawUrlForPath(readmePath, mainRef));
	const headers = parseChangelogHeaders(readmeContent);
	if (headers.length === 0) {
		throw new Error(`No changelog versions found in ${readmePath}`);
	}
	return headers;
}

async function findLatestHeader(scriptName: string): Promise<ChangelogHeader> {
	const headers = await findVersionHeaders(scriptName);
	const latestHeader = headers[0];
	if (latestHeader === undefined) {
		throw new Error(
			`No changelog versions found in ${readmePathForScript(scriptName)}`,
		);
	}
	return latestHeader;
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
	const commits = await fetchJson<GitHubCommit[]>(url);
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
	const readmeContent = await fetchText(rawUrlForPath(readmePath, commit));
	const versions = parseChangelogHeaders(readmeContent);
	return versions.some((header) => header.version === version);
}

async function fetchText(url: string): Promise<string> {
	const res = await fetch(url, { headers: githubHeaders() });
	if (!res.ok) {
		throw new Error(`Failed to fetch ${url}: ${res.status}`);
	}
	return res.text();
}

async function fetchJson<T>(url: string): Promise<T> {
	const res = await fetch(url, { headers: githubHeaders() });
	if (!res.ok) {
		throw new Error(`Failed to fetch ${url}: ${res.status}`);
	}
	return (await res.json()) as T;
}

async function fetchCachedScriptContent(
	scriptName: string,
	entry: VersionEntry,
	isLatest: boolean,
): Promise<string> {
	const cacheKey = isLatest
		? latestScriptContentCacheKey(scriptName)
		: scriptContentCacheKey(scriptName, entry.version);
	const cachedContent = await getCachedText(cacheKey);
	if (cachedContent !== undefined) {
		return cachedContent;
	}

	const versionedCachedContent = await getCachedText(
		scriptContentCacheKey(scriptName, entry.version),
	);
	if (versionedCachedContent !== undefined) {
		if (isLatest) {
			await putCachedText(
				latestScriptContentCacheKey(scriptName),
				versionedCachedContent,
				scriptCloudflareCacheTtlSec,
			);
		}
		return versionedCachedContent;
	}

	const scriptContent = await fetchText(
		rawUrlForPath(`scripts/${scriptName}`, entry.commit),
	);
	await putCachedText(
		scriptContentCacheKey(scriptName, entry.version),
		scriptContent,
		scriptCloudflareCacheTtlSec,
	);
	if (isLatest) {
		await putCachedText(
			latestScriptContentCacheKey(scriptName),
			scriptContent,
			scriptCloudflareCacheTtlSec,
		);
	}
	return scriptContent;
}

async function getCachedVersionHeaders(
	scriptName: string,
): Promise<ChangelogHeader[] | undefined> {
	return getCachedJson<ChangelogHeader[]>(versionHeadersCacheKey(scriptName));
}

async function putCachedVersionHeaders(
	scriptName: string,
	headers: ChangelogHeader[],
): Promise<void> {
	await putCachedJson(
		versionHeadersCacheKey(scriptName),
		headers,
		versionHeadersCloudflareCacheTtlSec,
	);
}

async function getCachedLatestHeader(
	scriptName: string,
): Promise<ChangelogHeader | undefined> {
	return getCachedJson<ChangelogHeader>(latestHeaderCacheKey(scriptName));
}

async function putCachedLatestHeader(
	scriptName: string,
	header: ChangelogHeader,
): Promise<void> {
	await putCachedJson(
		latestHeaderCacheKey(scriptName),
		header,
		latestHeaderCloudflareCacheTtlSec,
	);
}

async function getCachedJson<T>(cacheKey: string): Promise<T | undefined> {
	const cachedText = await getCachedText(cacheKey);
	if (cachedText === undefined) {
		return undefined;
	}
	return JSON.parse(cachedText) as T;
}

async function putCachedJson(
	cacheKey: string,
	value: unknown,
	ttlSec: number,
): Promise<void> {
	await putCachedText(cacheKey, JSON.stringify(value), ttlSec);
}

async function getCachedText(cacheKey: string): Promise<string | undefined> {
	const cache = caches.default;
	const response = await cache.match(cacheRequest(cacheKey));
	if (response === undefined) {
		return undefined;
	}
	return response.text();
}

async function putCachedText(
	cacheKey: string,
	value: string,
	ttlSec: number,
): Promise<void> {
	const cache = caches.default;
	await cache.put(
		cacheRequest(cacheKey),
		new Response(value, {
			headers: {
				"Cache-Control": `public, max-age=${ttlSec}`,
			},
		}),
	);
}

async function purgeVersionCaches(
	scriptName: string,
	headers: ChangelogHeader[],
): Promise<void> {
	versionHeadersCache.delete(scriptName);
	await deleteCache(versionHeadersCacheKey(scriptName));
	await deleteCache(latestScriptContentCacheKey(scriptName));
	for (const header of headers) {
		versionEntryCache.delete(versionEntryCacheKey(scriptName, header.version));
		await deleteCache(scriptContentCacheKey(scriptName, header.version));
	}
}

async function deleteCache(cacheKey: string): Promise<void> {
	const cache = caches.default;
	await cache.delete(cacheRequest(cacheKey));
}

function sameChangelogHeader(
	left: ChangelogHeader,
	right: ChangelogHeader,
): boolean {
	return left.version === right.version && left.commit === right.commit;
}

function cacheRequest(cacheKey: string): Request {
	return new Request(`${cacheUrlBase}/${encodePath(cacheKey)}`);
}

function latestHeaderCacheKey(scriptName: string): string {
	return `latest-header/${scriptName}`;
}

function versionHeadersCacheKey(scriptName: string): string {
	return `version-headers/${scriptName}`;
}

function scriptContentCacheKey(scriptName: string, version: string): string {
	return `script-content/${scriptName}/${version}`;
}

function latestScriptContentCacheKey(scriptName: string): string {
	return `script-content/${scriptName}/latest`;
}

function githubHeaders(): HeadersInit {
	return {
		Accept: "application/vnd.github+json",
		"User-Agent": "aviutl2-scripts-download-server",
		Authorization: `token ${env.GITHUB_TOKEN}`,
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

function versionEntryCacheKey(scriptName: string, version: string): string {
	return `${scriptName}@${version}`;
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
