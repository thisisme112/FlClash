import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:flutter_rust_bridge_hooks/flutter_rust_bridge_hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (input.userDefines['build_assets'] == false) {
      stdout.writeln('Skipping the Rust build: user-define build_assets=false');
      return;
    }
    await FlutterRustBridgeNativeAssetsBuilder(
      cratePath: 'rust',
      extraCargoEnvironmentVariables: _bindgenEnvironment(input),
    ).run(input: input, output: output);
  });
}

const _androidTriples = {
  Architecture.arm64: (
    rust: 'aarch64_linux_android',
    ndk: 'aarch64-linux-android',
  ),
  Architecture.arm: (
    rust: 'armv7_linux_androideabi',
    ndk: 'arm-linux-androideabi',
  ),
  Architecture.x64: (rust: 'x86_64_linux_android', ndk: 'x86_64-linux-android'),
};

// rquickjs runs bindgen on Android, which must load the NDK's libclang; Linux
// NDKs before r26 keep it under lib64, later ones and every macOS NDK under lib.
Map<String, String> _bindgenEnvironment(BuildInput input) {
  if (!input.config.buildCodeAssets ||
      input.config.code.targetOS != OS.android) {
    return const {};
  }
  final compiler = input.config.code.cCompiler?.compiler;
  if (compiler == null) {
    return const {};
  }
  final llvmRoot = File.fromUri(compiler).parent.parent;
  for (final name in const ['lib', 'lib64']) {
    final path = '${llvmRoot.path}${Platform.pathSeparator}$name';
    if (_holdsLibclang(path)) {
      return {'LIBCLANG_PATH': path};
    }
  }
  final hostLibclang = input.userDefines['libclang_path'];
  if (hostLibclang is String && _holdsLibclang(hostLibclang)) {
    return {
      'LIBCLANG_PATH': hostLibclang,
      ..._hostBindgenArgs(llvmRoot, input.config.code.targetArchitecture),
    };
  }
  throw StateError(
    'No libclang under ${llvmRoot.path} (lib or lib64); the NDK Flutter '
    'passed cannot run bindgen for rquickjs',
  );
}

bool _holdsLibclang(String path) {
  final directory = Directory(path);
  return directory.existsSync() && directory.listSync().any(_isLibclang);
}

// The Windows NDK ships no libclang. A host one loads, but resolves its
// builtin headers from its own install, so the NDK's are named explicitly;
// this replaces the per-target arguments native_toolchain_rust sets.
Map<String, String> _hostBindgenArgs(
  Directory llvmRoot,
  Architecture architecture,
) {
  final triples = _androidTriples[architecture];
  final clang = Directory('${llvmRoot.path}/lib/clang');
  if (triples == null || !clang.existsSync()) {
    return const {};
  }
  final root = llvmRoot.path.replaceAll(r'\', '/');
  final builtins = [
    for (final version in clang.listSync().whereType<Directory>())
      '-isystem ${version.path.replaceAll(r'\', '/')}/include',
  ].join(' ');
  return {
    'BINDGEN_EXTRA_CLANG_ARGS_${triples.rust}':
        '--sysroot=$root/sysroot '
        '-I$root/sysroot/usr/include/${triples.ndk} $builtins',
  };
}

bool _isLibclang(FileSystemEntity entity) {
  return entity.path.split(Platform.pathSeparator).last.startsWith('libclang.');
}
