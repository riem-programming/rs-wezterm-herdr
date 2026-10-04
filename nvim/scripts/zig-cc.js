// Wrapper that lets tree-sitter CLI (cc crate) use `zig cc` on Windows.
// The cc crate passes an MSVC-style target triple that zig rejects, so
// drop any target flag and force the GNU Windows target instead.
const { spawnSync } = require("child_process");

const args = process.argv.slice(2);
const out = [];
for (let i = 0; i < args.length; i++) {
  const a = args[i];
  if (a === "--target" || a === "-target") {
    i++; // skip the value too
  } else if (a.startsWith("--target=") || a.startsWith("-target=")) {
    continue;
  } else {
    out.push(a);
  }
}

const r = spawnSync("zig", ["cc", "-target", "x86_64-windows-gnu", ...out], {
  stdio: "inherit",
  shell: false,
});
process.exit(r.status === null ? 1 : r.status);
