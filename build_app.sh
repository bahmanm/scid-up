#!/bin/bash

if [ -z "$Build_SourcesDirectory" ]; then
  Build_SourcesDirectory=$(pwd)
fi

cd $Build_SourcesDirectory
mkdir -p tcltk && cd tcltk
git clone --depth=1 --branch core-8-6-branch https://github.com/tcltk/tcl.git
cd tcl/unix
./configure --prefix=$Build_SourcesDirectory/tcltk --enable-64bit --disable-shared
make -j
make install

cd $Build_SourcesDirectory
mkdir -p tcltk && cd tcltk
git clone --depth=1 --branch core-8-6-branch https://github.com/tcltk/tk.git
# LAYOUT_WITH_BASE_CHUNKS is not thread safe
sed -i'' -e '/define TK_LAYOUT_WITH_BASE_CHUNKS/d' tk/macosx/tkMacOSXInt.h
sed -i'' -e '/define TK_DRAW_IN_CONTEXT/d' tk/macosx/tkMacOSXInt.h
cd tk/unix
./configure --prefix=$Build_SourcesDirectory/tcltk --enable-64bit --enable-aqua
make -j
make install

cd $Build_SourcesDirectory
mkdir -p Scid.app/Contents
cp -R $Build_SourcesDirectory/resources/macos Scid.app/Contents/Resources
mv Scid.app/Contents/Resources/Info.plist Scid.app/Contents
cp -R $Build_SourcesDirectory/tcltk/lib Scid.app/Contents
rm -f Scid.app/Contents/lib/*.a
rm -f Scid.app/Contents/lib/*.sh
rm -Rf Scid.app/Contents/lib/pkgconfig

cd $Build_SourcesDirectory
if [[ "$(uname)" == "Darwin" ]]; then
  EXTRA_TCL_LIBS="-lz -framework CoreFoundation"
else
  EXTRA_TCL_LIBS="-lz -ldl"
fi

tcltk/bin/tclsh8.6 configure \
  LIBS="$EXTRA_TCL_LIBS" \
  SHAREDIR="$Build_SourcesDirectory/Scid.app/Contents/scid" \
  BINDIR="$Build_SourcesDirectory/Scid.app/Contents/MacOS"

echo "Type \"make install\" to build the Scid.app."
