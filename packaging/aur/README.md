# AUR packaging — `linux-wallpaperengine-v3-bin`

Prebuilt **x86-64-v3** binaries of [linux-wallpaperengine](https://github.com/Almamu/linux-wallpaperengine),
built in CI inside the CachyOS x86-64-v3 container.

## What's here

| File | Purpose |
| --- | --- |
| `PKGBUILD` | the AUR package definition |
| `.SRCINFO` | generated metadata, required by the AUR |
| `mksrcinfo.sh` | regenerates `.SRCINFO` from `PKGBUILD` without needing a full makepkg |
| `release.sh` | regenerates `.SRCINFO`, then optionally commits and pushes to the AUR |

## Publishing to the AUR

The AUR uses SSH for submissions. One-time setup:

1. Generate a key dedicated to the AUR:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/aur -C "aur"
   ```
2. Paste `~/.ssh/aur.pub` into your AUR account page
   (<https://aur.archlinux.org> → *My Account* → *SSH Public Key*).
3. Tell SSH about it:
   ```
   # ~/.ssh/config
   Host aur.archlinux.org
       IdentityFile ~/.ssh/aur
       User aur
   ```

Then, from this directory:

```bash
./release.sh <your-aur-username>
```

It creates/updates the local git repo, commits `PKGBUILD` + `.SRCINFO`, and
pushes to `ssh://aur@aur.archlinux.org/linux-wallpaperengine-v3-bin.git`.

> First push: if the package name does not exist yet, the AUR creates the
> repository on first successful push. Make sure the name is still free
> (`https://aur.archlinux.org/packages/linux-wallpaperengine-v3-bin`).

## Releasing a new version

1. Tag the build repo so CI produces a release:
   ```bash
   git tag v1.0.1 && git push origin v1.0.1
   ```
   `release-v3.yml` builds it and attaches
   `linux-wallpaperengine-<ver>-x86_64.tar.zst` to the GitHub release.
2. Grab the checksum from the release's `.sha256` asset.
3. Update `pkgver` and `sha256sums` in `PKGBUILD`.
4. Run `./release.sh <username>`.

## Requirements

The binaries need a CPU with **x86-64-v3** support (AVX2, BMI2, FMA).
Check with:

```bash
/lib/ld-linux-x86-64.so.2 --help | grep x86-64-v3
```

Anything from Haswell (2013) / Excavator (2015) onward qualifies. On older
hardware use the upstream `linux-wallpaperengine-git` package instead.

## Why a separate package

Upstream's `linux-wallpaperengine-git` compiles from source on your machine
using Arch's baseline `x86-64` target. This package ships the CachyOS
x86-64-v3 build instead, which also links against v3-optimised versions of
glibc, ffmpeg, mesa and friends. It `conflicts` with the source packages so
only one is installed at a time.

Note that it still needs the assets from the official Wallpaper Engine on
Steam — those are not redistributable and are not part of this package.
