#!/usr/bin/env bash
# Capture the parts of a hydra-genetics release that the skills restate:
# CLI --help output and the scaffold/rule templates.
#
# Usage: scripts/snapshot-hydra-genetics.sh <tag> [snapshot_dir]
#   tag           release tag, e.g. v4.3.0 (the leading "v" is optional)
#   snapshot_dir  where to write snapshots (default: snapshots)
#
# The release is installed from PyPI (what users actually run), and the
# templates are copied from the installed package, so no git clone is needed.
# The snapshot dir is wiped and regenerated, so `git diff snapshots/` after
# running against a new tag shows exactly what changed upstream.
set -euo pipefail

tag="${1:?usage: $0 <tag> [snapshot_dir]}"
version="${tag#v}"
out="${2:-snapshots}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

python3 -m venv "$work/venv"
"$work/venv/bin/pip" install -q --disable-pip-version-check "hydra-genetics==$version"

rm -rf "$out"
mkdir -p "$out/help" "$out/templates"

# Fixed width so click's help wrapping is deterministic across machines.
export COLUMNS=120
hg="$work/venv/bin/hydra-genetics"
"$hg" --help > "$out/help/hydra-genetics.txt"
for cmd in create-pipeline create-rule create-input-files; do
  "$hg" "$cmd" --help > "$out/help/$cmd.txt"
done

pkg="$(cd "$work" && "$work/venv/bin/python" -I -c 'import hydra_genetics, os; print(os.path.dirname(hydra_genetics.__file__))')"
cp -R "$pkg/rule-template" "$out/templates/rule-template"
[ -d "$pkg/script-template" ] && cp -R "$pkg/script-template" "$out/templates/script-template"

pt="$out/templates/pipeline-template"
mkdir -p "$pt/workflow/rules"
cp "$pkg/pipeline-template/workflow/Snakefile" "$pt/workflow/Snakefile"
cp "$pkg/pipeline-template/workflow/rules/common.smk" "$pt/workflow/rules/common.smk"
cp -R "$pkg/pipeline-template/workflow/schemas" "$pt/workflow/schemas"
cp -R "$pkg/pipeline-template/config" "$pt/config"
cp "$pkg/pipeline-template/README.md" "$pt/README.md"

# File layout of the scaffold (pipeline-creation documents the folder tree).
# Skip bytecode pip compiles at install time; create-pipeline ignores it too.
(cd "$pkg/pipeline-template" && find . -type f -not -name '.DS_Store' -not -path '*/__pycache__/*' -not -name '*.pyc' | LC_ALL=C sort) > "$out/templates/pipeline-template.files.txt"

echo "v$version" > "$out/VERSION"
echo "Snapshot of hydra-genetics $tag written to $out/"
