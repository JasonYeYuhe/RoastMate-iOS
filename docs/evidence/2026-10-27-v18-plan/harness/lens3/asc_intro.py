import time, json, urllib.request
from pathlib import Path
import jwt
ISSUER="c5671c11-49ec-47d9-bd38-5e3c1a249416"; KID="DMMFP6XTXX"
KEY=(Path.home()/"private_keys"/f"AuthKey_{KID}.p8").read_text()
n=int(time.time()); t=jwt.encode({"iss":ISSUER,"iat":n,"exp":n+1100,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID,"typ":"JWT"})
def get(u):
    return json.load(urllib.request.urlopen(urllib.request.Request(u,headers={"Authorization":f"Bearer {t}"}),timeout=60))
u="https://api.appstoreconnect.apple.com/v1/subscriptions/6769324200/introductoryOffers?limit=200&include=territory"
terrs=[]
while u:
    d=get(u); terrs+=[x["relationships"]["territory"]["data"]["id"] for x in d["data"] if x["relationships"].get("territory",{}).get("data")]
    u=d.get("links",{}).get("next")
print(len(terrs),"territories with yearly intro offer; TWN" ,"TWN" in terrs, "USA","USA" in terrs, "HKG","HKG" in terrs)
