"""Validate curated provenance and packaging against the original local artifacts."""
import hashlib
import json
import pathlib
import re
import sys
import zipfile

import argparse
parser=argparse.ArgumentParser()
parser.add_argument('--workspace',type=pathlib.Path,required=True)
parser.add_argument('--docs',type=pathlib.Path,required=True)
args=parser.parse_args()
ROOT=args.workspace.resolve()
WORK=ROOT/'analysis'
DOC=args.docs.resolve()
checks=[]
def check(condition,message):
    if not condition:raise AssertionError(message)
    checks.append(message)
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def digest(b):return hashlib.sha256(b).hexdigest()
def text_at(blob,off,text):
    return any(blob[off:off+len(enc)]==enc for enc in [text.encode('utf8'),text.encode('utf-16-le'),text.encode('latin1',errors='replace')])

for row in load(WORK/'artifacts.json'):
    data=(ROOT/'dzienniki music'/row['file']).read_bytes()
    check(digest(data)==row['sha256'],f"original archive identity: {row['file']}")

fry=load(WORK/'fryderyk/curated-evidence.json')
with zipfile.ZipFile(WORK/'extracted/fryderyk-android/config.arm64_v8a.apk') as z:
    android=z.read('lib/arm64-v8a/libapp.so')
ios=(WORK/'extracted/fryderyk-ios/Payload/Runner.app/Frameworks/App.framework/App').read_bytes()
for platform,blob in [('android',android),('ios',ios)]:
    check(digest(blob)==fry['sources'][platform]['sha256'],f'Fryderyk {platform} native image hash')
for row in fry['routes']:
    check(text_at(android if row['platform']=='android' else ios,row['offset'],row['literal']),f"Fryderyk route bytes {row['platform']} {row['literal']}@{row['offset_hex']}")
for row in load(WORK/'fryderyk/feature-evidence.json')['items']:
    check(text_at(ios,row['offset'],row['text']),f"Fryderyk selected literal {row['id']}")

mob=(WORK/'extracted/mobireg-ios/Payload/Runner.app/Frameworks/App.framework/App').read_bytes()
selected=load(WORK/'mobireg/ios-selected-evidence.json')
check(digest(mob)==selected['source_sha256'],'MobiReg iOS native image hash')
for row in selected['strings']:
    check(text_at(mob,int(row['offset'],16),row['text']),f"MobiReg selected literal {row['offset']}")
for row in load(WORK/'mobireg/source-identities.json'):
    path=ROOT/row['path'].replace('\\','/')
    if path.is_file():check(digest(path.read_bytes())==row['sha256'],f"MobiReg source identity {row['label']}")

modern_path=WORK/'mobireg/modern-platform-comparison.json'
if modern_path.exists():
    comparison=load(modern_path)
    modern=(WORK/'extracted/mobireg-android-modern/config.arm64_v8a/lib/arm64-v8a/libapp.so').read_bytes()
    check(digest(modern)==comparison['sha256'],'MobiReg modern Android AOT image hash')
    for row in comparison['matches']:
        off=int(row['offset'],16)
        raw=row['text'].encode(row['encoding'])
        check(modern[off:off+len(raw)]==raw,f"MobiReg modern literal {row['offset']}")
        n=(len(row['text'].encode('utf-16-le'))//2<<1)|int(row['encoding']=='utf-16le')
        marker=bytearray()
        while n>127:
            marker.append(n&127);n>>=7
        marker.append(n|128)
        check(modern[off-len(marker):off]==marker,f"MobiReg modern length/encoding marker {row['offset']}")
    stamp=comparison['build_stamp']
    check(text_at(modern,int(stamp['offset'],16),stamp['text']),'MobiReg modern Android build stamp')

mapping=load(WORK/'mobireg/android-field-mapping.json')
cache=load(WORK/'mobireg/android-cache-schema.json')
check(len(mapping['import'])==34,'MobiReg legacy import table count')
check(len(mapping['export'])==13,'MobiReg library-only export table count')
check(len(cache['tables'])==37,'MobiReg packaged local cache table count')

coverage=load(DOC/'coverage.json')
features=coverage['features']
check(coverage['feature_count']==len(features),'coverage count matches records')
check(len({r['id'] for r in features})==len(features),'all feature IDs unique')
check(all(r['implementation_status']=='not_started' for r in features),'no false implementation claims in coverage')
for provider in ['fryderyk','mobireg']:
    data=load(DOC/provider/'features.json')
    rows=data['features'] if isinstance(data,dict) else data
    check({r['id'] for r in rows}=={r['id'] for r in features if r['provider']==provider},f'{provider} feature register complete')
for p in DOC.rglob('*.json'):
    load(p)
    checks.append('JSON syntax '+str(p.relative_to(DOC)))

for p in DOC.rglob('*.md'):
    # Check actual Markdown links, not inline-code source path references.
    text=p.read_text(encoding='utf8')
    for raw in re.findall(r'(?<!!)\[[^\]]+\]\(([^)]+)\)',text):
        path=raw.split('#')[0].strip('<>')
        if not path or '://' in path or path.startswith('mailto:'):continue
        check((p.parent/path).exists(),f'Markdown link {p.relative_to(DOC)} -> {path}')

allowed={'.md','.json','.csv','.py'}
for p in DOC.rglob('*'):
    if p.is_file():
        check(p.suffix.lower() in allowed,f'publishable file type {p.relative_to(DOC)}')
        content=p.read_text(encoding='utf8')
        check(not re.search(r'AIza[\w-]{30,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|gh[pousr]_[A-Za-z0-9]{30,}',content),f'no recognizable credential material {p.relative_to(DOC)}')

report={'status':'passed','checks':len(checks),'feature_count':len(features),
        'original_archive_count':len(load(WORK/'artifacts.json')),
        'limits':'Evidence integrity and documentation packaging only; no application implementation or live runtime tests.'}
(WORK/'validation-report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
print(json.dumps(report))
