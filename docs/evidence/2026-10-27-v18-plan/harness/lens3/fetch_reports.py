import sys, time, json, csv, io, gzip, urllib.request
from pathlib import Path
import jwt
ISSUER="c5671c11-49ec-47d9-bd38-5e3c1a249416"; KID="DMMFP6XTXX"
KEY=(Path.home()/"private_keys"/f"AuthKey_{KID}.p8").read_text()
BASE="https://api.appstoreconnect.apple.com"
n=int(time.time()); t=jwt.encode({"iss":ISSUER,"iat":n,"exp":n+1100,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID,"typ":"JWT"})
def get(u):
    if not u.startswith("http"): u=BASE+u
    return json.load(urllib.request.urlopen(urllib.request.Request(u,headers={"Authorization":f"Bearer {t}"}),timeout=60))
since=sys.argv[1]; out=Path(sys.argv[2])
for rid in sys.argv[3:]:
    rows=set(); header=None; ninst=0
    for gran in ("DAILY","WEEKLY"):
        try: insts=get(f"/v1/analyticsReports/{rid}/instances?filter[granularity]={gran}&limit=200")["data"]
        except Exception as e: print(rid,gran,"ERR",e); continue
        for inst in insts:
            if inst["attributes"]["processingDate"]<since: continue
            ninst+=1
            for seg in get(f"/v1/analyticsReportInstances/{inst['id']}/segments")["data"]:
                raw=urllib.request.urlopen(seg["attributes"]["url"],timeout=60).read()
                tab=list(csv.reader(io.StringIO(gzip.decompress(raw).decode()),delimiter="\t"))
                header=tab[0]; rows.update(tuple(r) for r in tab[1:])
    p=out/f"{rid.split('-')[0]}.tsv"
    with open(p,"w") as f:
        if header: f.write("\t".join(header)+"\n"); [f.write("\t".join(r)+"\n") for r in sorted(rows)]
    print(rid.split('-')[0], "instances",ninst,"rows",len(rows), p)
