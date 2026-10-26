# Read-only: fetch daily Sales & Trends subscription reports for RoastMate (app 6769317103).
import sys, time, gzip, io, urllib.request, urllib.error, json
from pathlib import Path
import jwt
ISSUER="c5671c11-49ec-47d9-bd38-5e3c1a249416"; KID="DMMFP6XTXX"
KEY=(Path.home()/"private_keys"/f"AuthKey_{KID}.p8").read_text()
VENDOR="94126306"; OUT=Path(sys.argv[1]); days=sys.argv[2:]
def tok():
    n=int(time.time()); return jwt.encode({"iss":ISSUER,"iat":n,"exp":n+1100,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID,"typ":"JWT"})
t=tok()
for rtype, sub in [("SUBSCRIPTION_EVENT","SUMMARY"),("SUBSCRIPTION","SUMMARY")]:
    for d in days:
        ok=False
        for ver in ("1_4","1_3"):
            url=(f"https://api.appstoreconnect.apple.com/v1/salesReports?filter[frequency]=DAILY&filter[reportDate]={d}"
                 f"&filter[reportSubType]={sub}&filter[reportType]={rtype}&filter[vendorNumber]={VENDOR}&filter[version]={ver}")
            req=urllib.request.Request(url,headers={"Authorization":f"Bearer {t}","Accept":"application/a-gzip"})
            try:
                raw=urllib.request.urlopen(req,timeout=60).read()
                txt=gzip.decompress(raw).decode()
                (OUT/f"{rtype.lower()}_{d}.tsv").write_text(txt); print(rtype,d,ver,"ok",len(txt.splitlines())); ok=True; break
            except urllib.error.HTTPError as e:
                body=e.read().decode()[:200]
                if e.code==404: print(rtype,d,ver,"404 (no data)"); ok=True; break
                print(rtype,d,ver,e.code,body)
