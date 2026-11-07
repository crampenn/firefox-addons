#!/usr/bin/env bash
# Sets the release secrets (AMO_JWT_ISSUER, AMO_JWT_SECRET, RELEASES_TOKEN) on an
# add-on repo, reading the values from 1Password with the `op` CLI.
#
# Usage: scripts/set-secrets.sh [owner/repo | repo]
#   With no argument, prompts for the repo. A bare name means crampenn/<name>.
#
# The 1Password secret references can be overridden with env vars:
#   OP_AMO_JWT_ISSUER, OP_AMO_JWT_SECRET, OP_RELEASES_TOKEN
set -euo pipefail

vault_id=ied4g7xjwzfezjlqya7myhyp54
addon_key_item=yap5d6u3hdukx65tf3pol3emta
jwt_issuer_field=iuq3kwsdjk7xbhqfb6yyzr6squ
jwt_secret_field=xmoqd2kumbohregslmltjhylje
workflow_pat_item=jyjcerckqpbilsrxskcds4z624
token_field=74xyvrd5hudofjtub462hdt5ni

: "${OP_AMO_JWT_ISSUER:=op://$vault_id/$addon_key_item/$jwt_issuer_field}"
: "${OP_AMO_JWT_SECRET:=op://$vault_id/$addon_key_item/$jwt_secret_field}"
: "${OP_RELEASES_TOKEN:=op://$vault_id/$workflow_pat_item/$token_field}"

log()  { printf '==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

log "Checking tools"
for cmd in op gh; do
  command -v "$cmd" >/dev/null || die "'$cmd' is not installed"
  info "$cmd: $(command -v "$cmd")"
done

repo="${1:-}"
if [[ -z "$repo" ]]; then
  read -rp "Repo (owner/name, or name for crampenn/<name>): " repo
fi
repo="${repo// /}"
[[ -n "$repo" ]] || die "no repo given"
[[ "$repo" == */* ]] || repo="crampenn/$repo"

log "Checking access to $repo"
gh repo view "$repo" --json name >/dev/null || die "can't access $repo (check 'gh auth status')"
info "ok"

log "Reading secrets from 1Password (one approval)"
info "AMO_JWT_ISSUER <- $OP_AMO_JWT_ISSUER"
info "AMO_JWT_SECRET <- $OP_AMO_JWT_SECRET"
info "RELEASES_TOKEN <- $OP_RELEASES_TOKEN"

# One `op run` resolves all three references in a single 1Password auth (and
# fails before running anything if any reference is bad). The values only live
# in the child's environment and are piped to gh on stdin, never in argv.
export AMO_JWT_ISSUER="$OP_AMO_JWT_ISSUER"
export AMO_JWT_SECRET="$OP_AMO_JWT_SECRET"
export RELEASES_TOKEN="$OP_RELEASES_TOKEN"

op run -- bash -c '
  set -euo pipefail
  printf "    resolved all 3 references\n"
  printf "==> Setting secrets on %s\n" "$1"
  for name in AMO_JWT_ISSUER AMO_JWT_SECRET RELEASES_TOKEN; do
    value="${!name}"
    [[ -n "$value" ]] || { printf "error: %s is empty in 1Password\n" "$name" >&2; exit 1; }
    printf "    %s (%d chars)... " "$name" "${#value}"
    printf %s "$value" | gh secret set "$name" --repo "$1" >/dev/null
    printf "set\n"
  done
' _ "$repo" || die "setting secrets failed (see above)"

log "Secrets now on $repo"
gh secret list --repo "$repo" | sed 's/^/    /'

log "Done"
