pkgname=emacs-git-ryan
pkgver=31.0.50
pkgrel=1
pkgdesc="GNU Emacs development build with PGTK, native compilation, and tree-sitter"
arch=('x86_64')
url="http://www.gnu.org/software/emacs/"
license=('GPL3')
depends=('gnutls' 'libxml2' 'jansson' 'harfbuzz' 'libotf' 'libgccjit' 'libxi'
         'gtk3' 'libsm' 'xcb-util' 'libxcb' 'libjpeg-turbo' 'libpng' 'giflib'
         'libwebp' 'libtiff' 'libxpm' 'tree-sitter' 'sqlite3')
makedepends=('git')
provides=('emacs')
conflicts=('emacs')
source=("emacs-git::git+https://github.com/emacs-mirror/emacs.git")
sha256sums=('SKIP')

pkgver() {
  cd "$srcdir/emacs-git"
  local base=$(grep '^AC_INIT' configure.ac | sed -n 's/.*\[\([0-9.]*\)\].*/\1/p')
  local count=$(git rev-list --count HEAD)
  local commit=$(git rev-parse --short HEAD)
  printf "%s.r%s.%s" "$base" "$count" "$commit"
}

build() {
  cd "$srcdir/emacs-git"
  [[ -x configure ]] || ( ./autogen.sh git && ./autogen.sh autoconf )
  mkdir -p build
  cd build

  ../configure \
    --prefix=/usr \
    --sysconfdir=/etc \
    --libexecdir=/usr/lib \
    --localstatedir=/var \
    --mandir=/usr/share/man \
    --with-gameuser=:games \
    --with-modules \
    --without-m17n-flt \
    --without-gconf \
    --with-native-compilation=yes \
    --with-xinput2 \
    --with-pgtk \
    --without-xaw3d \
    --with-sound=no \
    --with-tree-sitter \
    --without-gpm \
    --without-compress-install \
    --program-transform-name=s/\([ec]tags\)/\1.emacs/

  CFLAGS="$CFLAGS -flto=auto" LDFLAGS="$LDFLAGS -flto=auto" make
}

package() {
  cd "$srcdir/emacs-git/build"
  make DESTDIR="$pkgdir/" install

  # Fix permissions
  find "$pkgdir/usr/share/emacs" -exec chown root:root {} \;
  mkdir -p "$pkgdir/var/games/emacs"
  chown -R root:games "$pkgdir/var/games"
  chmod 775 "$pkgdir/var/games" "$pkgdir/var/games/emacs"
}
