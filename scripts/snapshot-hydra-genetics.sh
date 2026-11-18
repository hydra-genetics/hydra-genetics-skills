#!/usr/bin/env bash
# Capture the parts of a hydra-genetics release that the skills restate:
# CLI --help output and the scaffold/rule templates.
#
# Usage: scripts/snapshot-hydra-genetics.sh <tag> [snapshot_dir]
#   tag           release tag, e.g. v4.3.0
#   snapshot_dir  where to write snapshots (default: snapshots)
#
# The snapshot dir is wiped and regenerated, so `git diff snapshots/` after
# running against a new tag shows exactly what changed upstream.
set -euo pipefail

tag="${1:?usage: $0 <tag> [snapshot_dir]}"
out="${2:-snapshots}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

git clone -q --depth 1 --branch "$tag" https://github.com/hydra-genetics/hydra-genetics.git "$work/src"
python3 -m venv "$work/venv"
"$work/venv/bin/pip" install -q "$work/src"

rm -rf "$out"
mkdir -p "$out/help" "$out/templates"

# Fixed width so click's help wrapping is deterministic across machines.
export COLUMNS=120
hg="$work/venv/bin/hydra-genetics"
"$hg" --help > "$out/help/hydra-genetics.txt"
for cmd in create-pipeline create-rule create-input-files; do
  "$hg" "$cmd" --help > "$out/help/$cmd.txt"
done

pkg="$work/src/hydra_genetics"
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
(cd "$pkg/pipeline-template" && find . -type f -not -name '.DS_Store' | LC_ALL=C sort) > "$out/templates/pipeline-template.files.txt"

echo "$tag" > "$out/VERSION"
echo "Snapshot of hydra-genetics $tag written to $out/"
