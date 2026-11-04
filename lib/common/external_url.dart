import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:url_launcher/url_launcher.dart';

Future<bool> launchExternalUrl(
  Uri uri, {
  bool? windows,
  String? Function(String scheme)? browserExecutable,
  Future<void> Function(String executable, List<String> arguments)?
  startBrowser,
  Future<bool> Function(Uri uri)? fallback,
}) async {
  if ((windows ?? Platform.isWindows) &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host.isNotEmpty) {
    final executable = (browserExecutable ?? _windowsBrowser)(uri.scheme);
    if (executable != null) {
      try {
        await (startBrowser ?? _startBrowser)(executable, [uri.toString()]);
        return true;
      } on ProcessException {
        // Shell activation still supports packaged browsers without a direct executable.
      }
    }
  }
  return (fallback ?? _launch)(uri);
}

Future<void> _startBrowser(String executable, List<String> arguments) async {
  await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.detached,
    runInShell: false,
  );
}

Future<bool> _launch(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

typedef _QueryAssociationNative =
    Int32 Function(
      Uint32,
      Uint32,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Pointer<Uint32>,
    );
typedef _QueryAssociation =
    int Function(
      int,
      int,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Pointer<Utf16>,
      Pointer<Uint32>,
    );

final _queryAssociation = DynamicLibrary.open('shlwapi.dll')
    .lookupFunction<_QueryAssociationNative, _QueryAssociation>(
      'AssocQueryStringW',
    );

String? _windowsBrowser(String scheme) {
  const protocol = 0x1000;
  const executable = 2;
  final association = scheme.toNativeUtf16();
  final length = calloc<Uint32>();
  Pointer<Utf16> output = nullptr;
  try {
    _queryAssociation(
      protocol,
      executable,
      association,
      nullptr,
      nullptr,
      length,
    );
    if (length.value == 0 || length.value > 32768) return null;
    output = calloc<Uint16>(length.value).cast<Utf16>();
    final result = _queryAssociation(
      protocol,
      executable,
      association,
      nullptr,
      output,
      length,
    );
    if (result != 0) return null;
    final path = output.toDartString();
    return path.isNotEmpty && File(path).existsSync() ? path : null;
  } finally {
    calloc.free(association);
    calloc.free(length);
    if (output != nullptr) calloc.free(output);
  }
}
