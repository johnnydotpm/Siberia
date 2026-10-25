"""Read-only extraction of candidate Dart AOT string objects; no target execution.

Validated on supplied MobiReg iOS 3.1.7 ARM64 App.framework/App. Class IDs and
layout are build-specific. This is structural evidence, not call-flow evidence.
Usage: python extract_dart_strings.py INPUT_BINARY OUTPUT_JSON
"""
import hashlib
import json
import pathlib
import struct
import sys


def extract(path):
    data = pathlib.Path(path).read_bytes()
    rows = []
    for header in range(0, len(data) - 16, 8):
        tags, _, smi_length = struct.unpack_from("<IIQ", data, header)
        class_id = (tags >> 12) & 0xFFFFF
        if class_id not in (94, 95) or smi_length & 1 or not 0 < smi_length <= 100000:
            continue
        length = smi_length // 2
        end = header + 16 + length * (2 if class_id == 95 else 1)
        if end > len(data):
            continue
        try:
            text = data[header + 16:end].decode("utf-16le" if class_id == 95 else "latin1")
        except UnicodeDecodeError:
            continue
        if any(ord(c) < 9 or 13 < ord(c) < 32 for c in text):
            continue
        rows.append({"offset": hex(header + 16), "object_offset": hex(header),
                     "cid": class_id, "length": length, "text": text})
    return {"sha256": hashlib.sha256(data).hexdigest(), "strings": rows,
            "limitations": ["Candidate structural object scan; false positives possible",
                            "No execution or function/data-flow relationship established",
                            "Class IDs and layout require validation for other builds"]}


if __name__ == "__main__":
    pathlib.Path(sys.argv[2]).write_text(json.dumps(extract(sys.argv[1]),
        ensure_ascii=False, indent=2), encoding="utf8")
