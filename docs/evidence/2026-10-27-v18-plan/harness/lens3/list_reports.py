import sys, time, json, urllib.request
from pathlib import Path
import jwt
ISSUER="c5671c11-49ec-47d9-bd38-5e3c1a249416"; KID="DMMFP6XTXX"
KEY=(Path.home()/"private_keys"/f"AuthKey_{KID}.p8").read_text()
REQ="53b320a6-68d1-4796-930f-62521ea5e749"; BASE="https://api.appstoreconnect.apple.com"
n=int(time.time()); t=jwt.encode({"iss":ISSUER,"iat":n,"exp":n+1100,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID,"typ":"JWT"})
def get(u):
    if not u.startswith("http"): u=BASE+u
    return json.load(urllib.request.urlopen(urllib.request.Request(u,headers={"Authorization":f"Bearer {t}"}),timeout=60))
url=f"/v1/analyticsReportRequests/{REQ}/reports?limit=200"
names=[]
while url:
    d=get(url); names+= [(r["attributes"]["name"],r["id"],r["attributes"].get("category")) for r in d["data"]]
    url=d.get("links",{}).get("next")
for nm,i,c in names:
    if any(k in nm for k in ("Subscri","Retention","Offer","Cancel","Purchas","Session","Install","Deletion")):
        print(c, "|", nm, "|", i)
print(len(names),"reports total")
