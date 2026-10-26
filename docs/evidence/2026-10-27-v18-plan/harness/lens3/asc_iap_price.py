import time, json, urllib.request, urllib.error
from pathlib import Path
import jwt
ISSUER="c5671c11-49ec-47d9-bd38-5e3c1a249416"; KID="DMMFP6XTXX"
KEY=(Path.home()/"private_keys"/f"AuthKey_{KID}.p8").read_text()
n=int(time.time()); t=jwt.encode({"iss":ISSUER,"iat":n,"exp":n+1100,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID,"typ":"JWT"})
B="https://api.appstoreconnect.apple.com"
def get(u):
    try: return json.load(urllib.request.urlopen(urllib.request.Request(B+u,headers={"Authorization":f"Bearer {t}"}),timeout=60))
    except urllib.error.HTTPError as e: return {"error":e.code,"body":e.read().decode()[:200]}
for iid,name in [("6770406611","10"),("6770406395","70"),("6770406396","160"),("6770406652","380")]:
    out=[]
    for kind in ("manualPrices","automaticPrices"):
        d=get(f"/v1/inAppPurchasePriceSchedules/{iid}/{kind}?include=inAppPurchasePricePoint,territory&filter[territory]=USA,TWN&limit=10")
        if "error" in d: out.append((kind,d["error"])); continue
        pts={x["id"]:x["attributes"] for x in d.get("included",[]) if x["type"]=="inAppPurchasePricePoints"}
        for r in d["data"]:
            pp=r["relationships"]["inAppPurchasePricePoint"]["data"]["id"]; terr=r["relationships"]["territory"]["data"]["id"]
            out.append((terr,pts[pp].get("customerPrice"),pts[pp].get("proceeds")))
    print("credits",name,out)
