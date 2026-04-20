import {
  type ChangelogHeader,
  fetchReadmeCommits,
  fetchText,
  latestReadmeCloudflareCacheTtlSec,
  mainRef,
  normalizeVersionSpecifier,
  parseChangelogHeaders,
  rawUrlForPath,
  readmePathForScript,
  type VersionEntry,
  versionLookupCloudflareCacheTtlSec,
} from "./utils";

const versionEntriesCacheBaseUrl =
  "https://aviutl2-scripts-download.local/version-entries";

export async function resolveVersionEntries(
  scriptName: string,
): Promise<VersionEntry[]> {
  const headers = await resolveVersionHeaders(scriptName);
  const latestHeader = headers[0];
  if (latestHeader === undefined) {
    throw new Error(
      `No changelog versions found in ${readmePathForScript(scriptName)}`,
    );
  }

  const latestVersion = latestHeader.version;
  const cachedEntries = await fetchCachedVersionEntries(
    scriptName,
    latestVersion,
  );
  if (cachedEntries !== undefined) {
    return cachedEntries;
  }

  const entries = await findVersionEntries(scriptName, headers);
  await cacheVersionEntries(scriptName, latestVersion, entries);
  return entries;
}

export function selectVersionEntry(
  entries: VersionEntry[],
  scriptName: string,
  versionSpecifier: string | undefined,
): VersionEntry {
  if (versionSpecifier === undefined) {
    const latestEntry = entries[0];
    if (latestEntry === undefined) {
      throw new Error(
        `No changelog versions found in ${readmePathForScript(scriptName)}`,
      );
    }
    return latestEntry;
  }

  const version = normalizeVersionSpecifier(versionSpecifier);
  const entry = entries.find((entry) => entry.version === version);
  if (entry === undefined) {
    throw new Error(
      `Could not find version ${version} in ${readmePathForScript(scriptName)}`,
    );
  }
  return entry;
}

async function fetchCachedVersionEntries(
  scriptName: string,
  latestVersion: string,
): Promise<VersionEntry[] | undefined> {
  const cache = caches.default;
  const cacheKey = versionEntriesCacheRequest(scriptName, latestVersion);
  const cachedResponse = await cache.match(cacheKey);
  if (cachedResponse === undefined) {
    return undefined;
  }
  return (await cachedResponse.json()) as VersionEntry[];
}

async function cacheVersionEntries(
  scriptName: string,
  latestVersion: string,
  entries: VersionEntry[],
): Promise<void> {
  const cache = caches.default;
  const cacheKey = versionEntriesCacheRequest(scriptName, latestVersion);
  await cache.put(
    cacheKey,
    new Response(JSON.stringify(entries), {
      headers: {
        "Cache-Control": `public, max-age=${versionLookupCloudflareCacheTtlSec}`,
        "Content-Type": "application/json",
      },
    }),
  );
}

function versionEntriesCacheRequest(
  scriptName: string,
  latestVersion: string,
): Request {
  const url = new URL(
    `${versionEntriesCacheBaseUrl}/${encodeURIComponent(scriptName)}`,
  );
  url.searchParams.set("latest", latestVersion);
  return new Request(url);
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

async function findVersionEntries(
  scriptName: string,
  headers: ChangelogHeader[],
): Promise<VersionEntry[]> {
  const readmePath = readmePathForScript(scriptName);
  const entries: VersionEntry[] = [];
  const unresolvedHeaders = headers.filter((header) => header.commit === null);
  const chronologicalCommits =
    unresolvedHeaders.length === 0
      ? undefined
      : [...(await fetchReadmeCommits(readmePath))].reverse();

  for (const header of headers) {
    const overrideCommit = header.commit;
    if (overrideCommit !== null) {
      entries.push({ version: header.version, commit: overrideCommit });
      continue;
    }

    if (chronologicalCommits === undefined) {
      throw new Error("Chronological commits is undefined");
    }
    const versionCommit = await findFirstCommitWithVersion(
      chronologicalCommits,
      readmePath,
      header.version,
    );
    if (versionCommit === undefined) {
      throw new Error(
        `Could not find commit for version ${header.version} in ${readmePath}`,
      );
    }
    entries.push({ version: header.version, commit: versionCommit });
  }
  return entries;
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
