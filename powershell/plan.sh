pkg_name=powershell
pkg_origin=core
pkg_version=6.0.0-alpha.12
pkg_license=('MIT')
pkg_upstream_url=https://msdn.microsoft.com/powershell
pkg_description="PowerShell is a cross-platform (Windows, Linux, and macOS) automation and configuration tool/framework that works well with your existing tools and is optimized for dealing with structured data (e.g. JSON, CSV, XML, etc.), REST APIs, and object models. It includes a command-line shell, an associated scripting language and a framework for processing cmdlets."
pkg_maintainer="The Habitat Maintainers <humans@habitat.sh>"
pkg_source="https://github.com/PowerShell/PowerShell"
pkg_deps=(
  mwrock/dotnet-core
  core/gcc
  core/glibc
  core/gcc-libs
  core/icu/52.1
  core/util-linux
  core/krb5
  core/libunwind
  core/lttng-ust
  core/openssl
)
pkg_build_deps=(
  core/patchelf
  core/cmake
  core/make
  core/git
)
pkg_bin_dirs=(bin)

do_download() {
  pushd $HAB_CACHE_SRC_PATH
  rm -rf $pkg_dirname
  mkdir $pkg_dirname

  # Important to recursively clone submodules.
  # This is why we do not download source
  git clone -b v$pkg_version --recursive "$pkg_source"
  popd
}

do_unpack() {
  return 0
}

do_verify() {
  return 0
}

do_prepare() {
  cp -r $HAB_CACHE_SRC_PATH/PowerShell/* $HAB_CACHE_SRC_PATH/$pkg_dirname
  rm -rf $HAB_CACHE_SRC_PATH/PowerShell
}

do_build() {
  dotnet restore
  find /root/.nuget -type f -name '*.so*' \
    -exec patchelf --set-rpath $LD_RUN_PATH {} \;

  cd src/ResGen
  dotnet build
  find -type f -name 'resgen' \
    -exec patchelf --interpreter "$(pkg_path_for glibc)/lib/ld-linux-x86-64.so.2" --set-rpath $LD_RUN_PATH {} \;
  find -type f -name '*.so*' \
    -exec patchelf --set-rpath $LD_RUN_PATH {} \;
  dotnet run

  cd ../TypeCatalogParser
  dotnet build --runtime ubuntu.14.04-x64
  find -type f -name 'TypeCatalogParser' \
    -exec patchelf --interpreter "$(pkg_path_for glibc)/lib/ld-linux-x86-64.so.2" --set-rpath $LD_RUN_PATH {} \;
  find -type f -name '*.so*' \
    -exec patchelf --set-rpath $LD_RUN_PATH {} \;
  bin/Debug/netcoreapp1.0/ubuntu.14.04-x64/TypeCatalogParser

  cd ../TypeCatalogGen
  dotnet build
  find -type f -name 'TypeCatalogGen' \
    -exec patchelf --interpreter "$(pkg_path_for glibc)/lib/ld-linux-x86-64.so.2" --set-rpath $LD_RUN_PATH {} \;
  find -type f -name '*.so*' \
    -exec patchelf --set-rpath $LD_RUN_PATH {} \;
  dotnet run ../Microsoft.PowerShell.CoreCLR.AssemblyLoadContext/CorePsTypeCatalog.cs powershell.inc

  cd ../libpsl-native
  cmake \
    -DCMAKE_BUILD_TYPE=Debug \
    -DCMAKE_INSTALL_PREFIX="$pkg_prefix" \
    -DCMAKE_CXX_FLAGS="$CXXFLAGS" \
    .
  make -j

  cd ../powershell-unix
  find -type f -name '*.so*' \
    -exec patchelf --set-rpath $LD_RUN_PATH {} \;
  dotnet build --configuration Linux
}

do_install() {
  cd src/powershell-unix
  dotnet publish --configuration Linux --output $pkg_prefix/bin
  find $pkg_prefix/bin -type f -name 'powershell' \
    -exec patchelf --interpreter "$(pkg_path_for glibc)/lib/ld-linux-x86-64.so.2" --set-rpath $LD_RUN_PATH {} \;
  find $pkg_prefix/bin -type f -name '*.so*' \
    -exec patchelf --set-rpath $LD_RUN_PATH {} \;
}

do_strip() {
  return 0
}
