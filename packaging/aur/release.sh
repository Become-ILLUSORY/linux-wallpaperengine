#!/usr/bin/env bash
#
# Regenerate .SRCINFO and (optionally) push this PKGBUILD to the AUR.
#
# Usage:
#   ./release.sh                    # refresh .SRCINFO only
#   ./release.sh <aur-username>     # refresh + commit + push to aur.archlinux.org
#
# Pushing requires an SSH key registered with your AUR account:
#   https://aur.archlinux.org  ->  My Account  ->  SSH Public Key
#
# For a new version:
#   1. bump pkgver in PKGBUILD
#   2. update sha256sums (take it from the .sha256 asset of the GitHub release)
#   3. ./release.sh <username>

set -euo pipefail

cd "$(dirname "$0")"

PKGNAME=$(bash -c 'source ./PKGBUILD; echo "$pkgname"')

echo "==> regenerating .SRCINFO for ${PKGNAME}"
bash mksrcinfo.sh > .SRCINFO
sed -i '/= *$/d' .SRCINFO
echo "    ok ($(wc -l < .SRCINFO) lines)"

if [ $# -lt 1 ]; then
    echo "==> done (no username given, skipping push)"
    exit 0
fi

USERNAME="$1"
REMOTE="ssh://aur@aur.archlinux.org/${PKGNAME}.git"

if [ ! -d .git ]; then
    echo "==> initialising AUR git repository"
    git init -q
    git remote add origin "$REMOTE"
else
    git remote set-url origin "$REMOTE" 2>/dev/null || git remote add origin "$REMOTE"
fi

git add PKGBUILD .SRCINFO
if git diff --cached --quiet; then
    echo "==> nothing changed"
else
    git -c user.name="$USERNAME" \
        -c user.email="${USERNAME}@users.noreply.github.com" \
        commit -q -m "upgpkg: ${PKGNAME} $(bash -c 'source ./PKGBUILD; echo "$pkgver-$pkgrel"')"
fi

echo "==> pushing to ${REMOTE}"
git push -u origin master

echo "==> published: https://aur.archlinux.org/packages/${PKGNAME}"
