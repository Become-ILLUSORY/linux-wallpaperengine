#!/usr/bin/env bash
# Minimal .SRCINFO generator: sources a PKGBUILD and emits the SRCINFO format
# that the AUR uses. Avoids needing a full makepkg (which refuses to run as
# root and expects an Arch userland).
set -euo pipefail

pkgbuild="${1:-PKGBUILD}"
# shellcheck disable=SC1090
source "./${pkgbuild}"

emit_scalar() {
    local key="$1" val="$2"
    [ -n "${val:-}" ] || return 0
    printf '\t%s = %s\n' "$key" "$val"
}

emit_array() {
    local key="$1"; shift
    local item
    for item in "$@"; do
        printf '\t%s = %s\n' "$key" "$item"
    done
}

pkgbase="${pkgbase:-$pkgname}"

printf 'pkgbase = %s\n' "$pkgbase"
emit_scalar pkgdesc "$pkgdesc"
emit_scalar pkgver "$pkgver"
emit_scalar pkgrel "$pkgrel"
emit_scalar epoch "${epoch:-}"
emit_scalar url "$url"
emit_scalar arch "${arch[*]:-}"
emit_array license "${license[@]:-}"
emit_array provides "${provides[@]:-}"
emit_array conflicts "${conflicts[@]:-}"
emit_array replaces "${replaces[@]:-}"
emit_array depends "${depends[@]:-}"
emit_array optdepends "${optdepends[@]:-}"
emit_array makedepends "${makedepends[@]:-}"
emit_array checkdepends "${checkdepends[@]:-}"
emit_array options "${options[@]:-}"

# source entries keep their local name prefix
if [ "${#source[@]}" -gt 0 ]; then
    for s in "${source[@]}"; do
        printf '\tsource = %s\n' "$s"
    done
fi

if [ "${#sha256sums[@]}" -gt 0 ]; then
    for s in "${sha256sums[@]}"; do
        printf '\tsha256sums = %s\n' "$s"
    done
fi

printf '\n'
printf 'pkgname = %s\n' "$pkgname"
