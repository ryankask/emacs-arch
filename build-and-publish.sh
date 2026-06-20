#!/usr/bin/env bash
set -euo pipefail
#
# This script builds the emacs-git-ryan package and publishes it to a local
# pacman repository in /var/lib/arch-repo/x86_64.
#
# See Caddyfile.repo in this directory for an example Caddy config.
#

# Config
REPO_DIR="/var/lib/arch-repo/x86_64"
REPO_NAME="vole"
PKG_NAME="emacs-git-ryan"
PKGBUILD_DIR="$HOME/src/emacs-arch"
# Set this if you want to use a specific GPG key ID, otherwise default key is used
GPG_KEY=""

# Validate GPG signing capability
if [[ -n "${GPG_KEY:-}" ]]; then
    gpg --list-secret-keys "$GPG_KEY" >/dev/null 2>&1 || { echo "ERROR: No GPG secret key available for signing"; exit 1; }
else
    gpg --list-secret-keys >/dev/null 2>&1 || { echo "ERROR: No GPG secret key available for signing"; exit 1; }
fi

mkdir -p "$REPO_DIR"
cd "$PKGBUILD_DIR"

echo "=== Updating sources ==="
makepkg -fo -s --nobuild --nocheck

echo "=== Building package ==="
# Use chroot if we have passwordless sudo, otherwise local build
if sudo -n extra-x86_64-build -- --needed 2>/dev/null; then
    echo "Chroot build succeeded"
elif makepkg -fs --noconfirm; then
    echo "Local build succeeded"
else
    echo "ERROR: Build failed"
    exit 1
fi

echo "=== Identifying built packages ==="
mapfile -t pkg_files < <(makepkg --packagelist)
if [[ ${#pkg_files[@]} -eq 0 ]]; then
    echo "ERROR: No packages found after build"
    exit 1
fi

pkg_file=""
for f in "${pkg_files[@]}"; do
    if [[ "$(basename "$f")" == "${PKG_NAME}"-*.pkg.tar.zst ]]; then
        pkg_file="$f"
        break
    fi
done

if [[ -z "$pkg_file" ]]; then
    echo "ERROR: Could not find main package ${PKG_NAME}"
    exit 1
fi

echo "Built: $(basename "$pkg_file")"

echo "=== Managing package retention ==="

# Find existing non-backup package
existing=$(find "$REPO_DIR" -maxdepth 1 -name "${PKG_NAME}-*.pkg.tar.zst" ! -name "*.old" | head -n1 || true)

# Remove stale backups
rm -f "$REPO_DIR"/${PKG_NAME}-*.pkg.tar.zst.old "$REPO_DIR"/${PKG_NAME}-*.pkg.tar.zst.old.sig 2>/dev/null || true

# Backup current to .old
if [[ -n "$existing" && -f "$existing" ]]; then
    echo "Preserving rollback: $(basename "$existing") -> .old"
    mv -f "$existing" "${existing}.old"
    if [[ -f "${existing}.sig" ]]; then
        mv -f "${existing}.sig" "${existing}.old.sig"
    fi
fi

# Remove any remaining current packages (defensive)
rm -f "$REPO_DIR"/${PKG_NAME}-*.pkg.tar.zst "$REPO_DIR"/${PKG_NAME}-*.pkg.tar.zst.sig 2>/dev/null || true

cp "$pkg_file" "$REPO_DIR/"
cd "$REPO_DIR"

echo "=== Signing package ==="
if [[ -n "${GPG_KEY:-}" ]]; then
    gpg --detach-sign --use-agent --batch --no-tty --local-user "$GPG_KEY" "$(basename "$pkg_file")"
else
    gpg --detach-sign --use-agent --batch --no-tty "$(basename "$pkg_file")"
fi

echo "=== Updating repo database ==="
if [[ -n "${GPG_KEY:-}" ]]; then
    repo-add --sign --key "$GPG_KEY" "$REPO_NAME.db.tar.gz" "$(basename "$pkg_file")"
else
    repo-add --sign "$REPO_NAME.db.tar.gz" "$(basename "$pkg_file")"
fi

# Flatten symlinks so any web server (Caddy, etc.) serves them correctly
rm -f "$REPO_NAME.db"
cp "$REPO_NAME.db.tar.gz" "$REPO_NAME.db"
rm -f "$REPO_NAME.files"
cp "$REPO_NAME.files.tar.gz" "$REPO_NAME.files" 2>/dev/null || true
if [[ -f "$REPO_NAME.db.tar.gz.sig" ]]; then
    rm -f "$REPO_NAME.db.sig"
    cp "$REPO_NAME.db.tar.gz.sig" "$REPO_NAME.db.sig"
fi

echo "=== Build complete ==="
ls -la "$REPO_DIR"

echo "=== Cleaning up build artifacts ==="
cd "$PKGBUILD_DIR"
rm -rf pkg/
