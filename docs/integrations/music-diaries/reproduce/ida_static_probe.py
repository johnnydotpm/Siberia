"""Execution-free IDA inventory of copied Flutter AOT images; no app launch."""
import idapro
import hashlib
import json
import pathlib
import sys
import time
import ida_funcs
import ida_loader
import ida_segment
import ida_nalt
import idautils

target = pathlib.Path(sys.argv[1]).resolve()
output = pathlib.Path(sys.argv[2]).resolve()
started = time.monotonic()
rc = idapro.open_database(str(target), True)
if rc:
    raise RuntimeError(f"IDA open_database failed: {rc}")
try:
    probes = []
    blob = target.read_bytes()
    for literal in (b'/modules/api/auth.php', b'/modules/api/refresh.php',
                    b'/modules/api/qrlogin.php', b'/modules/api/app.php',
                    b'/identify', b'/reIdentify', b'/login', b'/validate',
                    b'messages/', b'homeworks'):
        pos = blob.find(literal)
        if pos < 0:
            continue
        ea = ida_loader.get_fileregion_ea(pos)
        refs = []
        # A Dart string reference normally addresses its tagged object, not payload.
        for delta in (0, -16, -15):
            for ref in idautils.XrefsTo(ea + delta, 0):
                fn = ida_funcs.get_func(ref.frm)
                refs.append({'to_delta': delta, 'from': hex(ref.frm),
                             'is_code': bool(ref.iscode), 'type': ref.type,
                             'function': hex(fn.start_ea) if fn else None})
        probes.append({'literal': literal.decode(), 'first_file_offset': hex(pos),
                       'mapped_ea': hex(ea), 'incoming_refs': refs})
    segments = []
    for ea in idautils.Segments():
        s = ida_segment.getseg(ea)
        segments.append({'name': ida_segment.get_segm_name(s),
                         'start': hex(s.start_ea), 'end': hex(s.end_ea)})
    report = {'tool': 'IDA Pro idalib', 'version': idapro.get_library_version(),
              'artifact': str(target), 'sha256': hashlib.sha256(blob).hexdigest(),
              'auto_analysis_completed': True, 'elapsed_seconds': time.monotonic()-started,
              'function_count': ida_funcs.get_func_qty(), 'segments': segments,
              'probes': probes,
              'limitations': ['Static auto-analysis does not recover Dart source or wire contracts.',
                             'Only first literal occurrence is probed.',
                             'Absent native xrefs do not prove that a Dart feature is unused.']}
    output.write_text(json.dumps(report, indent=2), encoding='utf8')
    print(json.dumps({'output': str(output), 'functions': report['function_count'],
                      'seconds': report['elapsed_seconds']}))
finally:
    idapro.close_database(False)
