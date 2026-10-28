#!/bin/sh
# Stop hook: in a Firefox add-on repo, block finishing a turn when shipped files
# changed since the last push but manifest.json's version didn't. One bump covers
# everything until the next push. Silent everywhere else.

input=$(cat)
# Only nag once per stop; if Claude already got the reminder, let it stop
[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false')" = "true" ] && exit 0

dir=$(printf '%s' "$input" | jq -r '.cwd // empty')
root=$(git -C "${dir:-.}" rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0
[ -f manifest.json ] || exit 0
jq -e '.browser_specific_settings.gecko' manifest.json >/dev/null 2>&1 || exit 0

# Compare against what's pushed so unpushed commits count too. With no upstream
# nothing has been released yet, so the current version is still unreleased.
base=$(git rev-parse -q --verify '@{upstream}' 2>/dev/null) || exit 0
base_version=$(git show "$base:manifest.json" 2>/dev/null | jq -r '.version // empty')
[ -n "$base_version" ] || exit 0
version=$(jq -r '.version // empty' manifest.json)
[ "$version" = "$base_version" ] || exit 0

# Dotfiles/dirs (.github, .claude, ...) aren't packaged by web-ext, so they don't need a bump
changed=$( { git diff --name-only "$base"; git ls-files --others --exclude-standard; } | grep -v '^\.' | sort -u)
[ -n "$changed" ] || exit 0

files=$(printf '%s' "$changed" | tr '\n' ' ')
jq -n --arg v "$version" --arg f "$files" '{
  decision: "block",
  reason: ("This Firefox add-on changed (" + $f + ") but manifest.json is still at version " + $v + ". Bump the minor version (e.g. 1.8 → 1.9) per the firefox-addon skill, or tell the user why not.")
}'
