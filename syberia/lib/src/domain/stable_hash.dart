import 'dart:convert';

/// A short name that stays the same across runs (FNV-1a, eight hex digits).
/// It keeps names of files and keys short; it is no secret.
String stableHash(String value) {
  var hash = 0x811c9dc5;
  for (final unit in utf8.encode(value)) {
    hash = ((hash ^ unit) * 0x01000193) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}
