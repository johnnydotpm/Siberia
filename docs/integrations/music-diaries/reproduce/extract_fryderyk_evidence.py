"""Offline reproducible Fryderyk literal evidence extraction; no execution/network.
Usage: python extract_fryderyk_evidence.py --workspace WORKSPACE --output NEW_OUTPUT_DIR
Do not publish full uncurated AOT dumps without reviewing embedded configuration.
"""
from pathlib import Path
import argparse
import re, json, struct, hashlib, zipfile
parser=argparse.ArgumentParser()
parser.add_argument("--workspace", type=Path, default=Path.cwd())
parser.add_argument("--output", type=Path, required=True)
args=parser.parse_args()
ROOT=args.workspace.resolve()
OUT=args.output.resolve()
OUT.mkdir(parents=True, exist_ok=True)
SRC=ROOT/"analysis/extracted"
ANDROID=SRC/"fryderyk-android/config.arm64_v8a.apk"
IOS=SRC/"fryderyk-ios/Payload/Runner.app/Frameworks/App.framework/App"
def save(name,obj):
 (OUT/name).write_text(json.dumps(obj,indent=2,ensure_ascii=False)+"\n",encoding="utf8")
with zipfile.ZipFile(ANDROID) as z:
 member=next(n for n in z.namelist() if n.endswith("/libapp.so"))
 android=z.read(member)
if hashlib.sha256(android).hexdigest() != "8fdabb00afead92a3f36b71621ddf5976441191255b504c49de01c9681aeb738":
 raise ValueError("Different Android AOT library: re-establish the snapshot encoding first")
ios=IOS.read_bytes()
if hashlib.sha256(ios).hexdigest() != "2c11d5a1be3f1f21d85c2b9c4deb8c59d2c3c33dfd9eebf0235657bcc6f7cca1":
 raise ValueError("Different iOS library: re-establish snapshot range/class IDs before using this build-specific scanner")
rows=[]
for pos in range(0x840000,len(ios)-16,16):
 tag=struct.unpack_from("<I",ios,pos)[0]; cid=(tag>>12)&0xfffff
 if cid not in (94,95):continue
 smi=struct.unpack_from("<Q",ios,pos+8)[0]
 if smi%2 or smi>20000:continue
 n=smi//2; off=pos+16
 try:text=ios[off:off+n*(1 if cid==94 else 2)].decode("latin1" if cid==94 else "utf-16-le")
 except UnicodeError:continue
 if any(ord(c)<9 or 13<ord(c)<32 for c in text):continue
 rows.append({"offset":off,"text":text,"encoding":"latin1" if cid==94 else "utf16le"})
a=[{"offset":m.start(),"text":m.group().decode("ascii")} for m in re.finditer(rb"[\x20-\x7e]{4,}",android)]
route=lambda s:bool(re.match(r"^(attendances|grades|messages|homeworks|lessons|users)/[A-Za-z/]+$",s) or s in ("/identify","/reIdentify","/login","/validate"))
result={"method":"static literal recovery; does not establish execution, call graph or wire contracts", "sources":{"ios":{"sha256":hashlib.sha256(ios).hexdigest(),"path":str(IOS.relative_to(ROOT))},"android":{"sha256":hashlib.sha256(android).hexdigest(),"archive":str(ANDROID.relative_to(ROOT)),"member":member}},"counts":{"ios_parsed_dart_strings":len(rows),"android_ascii_runs":len(a)},"routes":[]}
for platform,rs in (("ios",rows),("android",a)):
 for r in rs:
  if route(r["text"]):result["routes"].append({"platform":platform,"literal":r["text"],"offset":r["offset"],"offset_hex":hex(r["offset"]),"http_method":None,"payload":None,"response_schema":None,"confidence":"observed literal; inferred endpoint candidate"})
result["application_source_paths"]={}
for platform,rs in (("ios",rows),("android",a)):
 result["application_source_paths"][platform]=[{"offset":r["offset"],"path":re.search(r"package:fryderyk_mobile_v3/[^ ]+?\.dart",r["text"]).group()} for r in rs if re.search(r"package:fryderyk_mobile_v3/[^ ]+?\.dart",r["text"])]
save("curated-evidence.json",result)
print("Recovered",len(result["routes"]),"platform-specific route candidates")
