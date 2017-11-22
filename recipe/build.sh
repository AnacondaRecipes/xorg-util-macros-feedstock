#! /bin/bash

set -e
IFS=$' \t\n' # workaround for conda 4.2.13+toolchain bug

# Adopt a Unix-friendly path if we're on Windows (see bld.bat).
[ -n "$PATH_OVERRIDE" ] && export PATH="$PATH_OVERRIDE"

# On Windows we want $LIBRARY_PREFIX in both "mixed" (C:/Conda/...) and Unix
# (/c/Conda) forms, but Unix form is often "/" which can cause problems.
if [ -n "$LIBRARY_PREFIX_M" ] ; then
    mprefix="$LIBRARY_PREFIX_M"
    if [ "$ARCH" = "32" ]; then
        bprefix="${mprefix/h_env/build_env}"
    else
        bprefix=$mprefix
    fi
    if [ "$LIBRARY_PREFIX_U" = / ] ; then
        uprefix=""
    else
        uprefix="$LIBRARY_PREFIX_U"
    fi
    if [ "$ARCH" = "32" ]; then
        ubprefix="${uprefix/h_env/build_env}"
    else
        ubprefix=$uprefix
    fi
else
    mprefix="$PREFIX"
    bprefix="$PREFIX"
    uprefix="$PREFIX"
    ubprefix="$PREFIX"
fi

# On Windows we need to regenerate the configure scripts.
if [ -n "$VS_MAJOR" ] ; then
    am_version=1.15 # keep sync'ed with meta.yaml
    export ACLOCAL=aclocal-$am_version
    export AUTOMAKE=automake-$am_version
    autoreconf_args=(
        --force
        --install
        -I "$ubprefix/mingw-w64/share/aclocal" # note: this is correct for win32 also!
    )
    autoreconf "${autoreconf_args[@]}"
fi

# We used to provide our own config.{guess,sub} on Windows; now we are
# transitioning to running autoreconf in all Windows builds, since the
# distributed configure scripts have a lot of Windows special-casing that
# fails on msys2 unless we use msys2's autotools. But to smooth the transition
# we'll keep distributing the files for a bit.

mkdir -p $uprefix/share/util-macros

for f in config.guess config.sub ; do
    cp -p $RECIPE_DIR/$f .
    cp -p $RECIPE_DIR/$f $uprefix/share/util-macros/
done

export PKG_CONFIG_LIBDIR=$uprefix/lib/pkgconfig:$uprefix/share/pkgconfig

configure_args=(
    --prefix=$uprefix
    --disable-dependency-tracking
    --disable-selective-werror
    --disable-silent-rules
)

./configure "${configure_args[@]}"
make -j${CPU_COUNT}
make install
make check
