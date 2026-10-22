{ clang, lld, mingw32Binutils, mingw64Binutils, lib, stdenv, symlinkJoin, writeShellScriptBin }:

# Native fixtures need Nix's libc/loader. Freestanding foreign fixtures need
# raw Clang and target linkers, without cc-wrapper's host-only flags.
let
  resourceDir = "${clang.cc.lib}/lib/clang/${lib.versions.major clang.version}";
in symlinkJoin {
  name = "kuna-fixture-clang";
  paths = map (name: writeShellScriptBin name ''
    target=
    targetNext=false
    linking=true
    for arg in "$@"; do
      if $targetNext; then
        target="$arg"
        targetNext=false
        continue
      fi
      case "$arg" in
        --target=*) target="''${arg#*=}" ;;
        --target|-target) targetNext=true ;;
        -c|-S|-E|-fsyntax-only) linking=false ;;
      esac
    done
    case "$target" in
      ""|${stdenv.hostPlatform.config}|${stdenv.hostPlatform.parsed.cpu.name}*-linux-*)
        exec ${clang}/bin/${name} "$@"
        ;;
    esac
    if $linking; then
      case "$target" in
        i?86*-windows-gnu|i?86*-mingw*|i?86*-w64-*)
          linker=${mingw32Binutils.bintools}/bin/${mingw32Binutils.targetPrefix}ld ;;
        x86_64*-windows-gnu|x86_64*-mingw*|x86_64*-w64-*)
          linker=${mingw64Binutils.bintools}/bin/${mingw64Binutils.targetPrefix}ld ;;
        *windows-msvc*) linker=${lld}/bin/lld-link ;;
        *apple*|*darwin*) linker=${lld}/bin/ld64.lld ;;
        wasm*) linker=${lld}/bin/wasm-ld ;;
        *) linker=${lld}/bin/ld.lld ;;
      esac
      exec ${clang.cc}/bin/${name} -resource-dir ${resourceDir} "-fuse-ld=$linker" "$@"
    fi
    exec ${clang.cc}/bin/${name} -resource-dir ${resourceDir} "$@"
  '') [ "clang" "clang++" ];
}
