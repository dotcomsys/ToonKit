const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");

const root = path.resolve(__dirname, "..");
const content = path.join(root, ".sources", "content");
const recovery = path.join(root, ".sources", "recovered-0.10-alpha");
const manifest = JSON.parse(fs.readFileSync(path.join(root, "ToonKit", "SOURCE-MANIFEST.json"), "utf8"));
const digest = bytes => crypto.createHash("sha256").update(bytes).digest("hex");

function archivePath(record) {
    if (record.localFile) return record.localFile;
    if (record.repository) return record.repository.split("/").at(-1) + "/" + record.file;
    return "sixty-books.json";
}

function upstream(record) {
    if (record.localFile?.startsWith("refresh-metadata/")) {
        const leaf = path.basename(record.localFile, "-tree.json");
        const pin = Object.entries(manifest.refresh?.pins ?? {}).find(([repo])=>repo.endsWith("/"+leaf));
        if (pin) return `https://api.github.com/repos/${pin[0]}/git/trees/${pin[1]}?recursive=1`;
    }
    if (record.repository && record.revision && record.file) {
        const file = record.file.split("/").map(encodeURIComponent).join("/");
        return `https://raw.githubusercontent.com/${record.repository}/${record.revision}/${file}`;
    }
    const url = record.url;
    if (url?.startsWith("https://github.com/") && url.includes("/blob/")) {
        return url.replace("https://github.com/", "https://raw.githubusercontent.com/").replace("/blob/", "/");
    }
    return url?.startsWith("https://") && !url.endsWith("/db2") ? url : undefined;
}

function exactLocal(directory, name, expectedHash) {
    try { return digest(fs.readFileSync(path.join(directory, name))) === expectedHash; }
    catch (error) {
        if (!["ENOENT", "EACCES", "EPERM"].includes(error.code)) throw error;
        return false;
    }
}

async function recover(record) {
    const name = archivePath(record);
    const expected = record.sha256;
    if (!name || path.isAbsolute(name) || name.split(/[\\/]/).includes("..") || !/^[a-f0-9]{64}$/.test(expected)) {
        throw Error("Invalid manifest record: " + name);
    }
    if (exactLocal(content, name, expected) || exactLocal(recovery, name, expected)) return "Verified local";
    const url = upstream(record);
    if (!url) return "Exact local input unavailable; no upstream file URL";
    try {
        const response = await fetch(url, {signal: AbortSignal.timeout(8000)});
        if (!response.ok) return "HTTP " + response.status;
        let bytes = Buffer.from(await response.arrayBuffer());
        if (digest(bytes) !== expected && name.startsWith("refresh-metadata/")) {
            const tree = JSON.parse(bytes);
            const variations=[JSON.stringify(tree),JSON.stringify(tree,null,2),JSON.stringify(tree,null,4)];
            for (const text of variations) {
                const exact=[text,text+"\n",text.replaceAll("\n","\r\n"),text.replaceAll("\n","\r\n")+"\r\n"]
                    .map(value=>Buffer.from(value)).find(value=>digest(value)===expected);
                if (exact) {bytes=exact;break;}
            }
        }
        if (digest(bytes) !== expected) return "Upstream response did not match SHA-256";
        const destination = path.join(recovery, name);
        fs.mkdirSync(path.dirname(destination), {recursive:true});
        fs.writeFileSync(destination, bytes);
        return "Recovered and hash verified";
    } catch (error) {
        return "Recovery failed: " + error.message;
    }
}

async function main() {
    const results = [];
    let cursor = 0;
    await Promise.all(Array.from({length:16}, async () => {
        while (cursor < manifest.sources.length) {
            const record = manifest.sources[cursor++];
            results.push({path:archivePath(record), sha256:record.sha256, status:await recover(record)});
        }
    }));
    results.sort((a,b)=>a.path.localeCompare(b.path));
    const statuses = Object.groupBy(results, entry=>entry.status);
    for (const [status, entries] of Object.entries(statuses)) console.log(`${entries.length} ${status}`);
    const unresolved = results.filter(entry=>!["Verified local", "Recovered and hash verified"].includes(entry.status));
    fs.mkdirSync(recovery, {recursive:true});
    fs.writeFileSync(path.join(recovery, "unresolved.json"), JSON.stringify(unresolved, null, 2)+"\n");
    if (unresolved.length) process.exitCode = 1;
}

main().catch(error=>{console.error(error);process.exitCode=1;});
