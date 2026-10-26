# Read-only ASC API: subscription products, TW/US prices, intro offers, IAP prices.
import time, json, urllib.request, urllib.error
from pathlib import Path
import jwt
ISSUER="c5671c11-49ec-47d9-bd38-5e3c1a249416"; KID="DMMFP6XTXX"
KEY=(Path.home()/"private_keys"/f"AuthKey_{KID}.p8").read_text()
BASE="https://api.appstoreconnect.apple.com"
n=int(time.time()); t=jwt.encode({"iss":ISSUER,"iat":n,"exp":n+1100,"aud":"appstoreconnect-v1"},KEY,algorithm="ES256",headers={"kid":KID,"typ":"JWT"})
def get(u):
    if not u.startswith("http"): u=BASE+u
    try: return json.load(urllib.request.urlopen(urllib.request.Request(u,headers={"Authorization":f"Bearer {t}"}),timeout=60))
    except urllib.error.HTTPError as e: return {"error":e.code,"body":e.read().decode()[:300]}
subs=get("/v1/subscriptionGroups/22088713/subscriptions?limit=20")
for s in subs.get("data",[]):
    a=s["attributes"]; sid=s["id"]
    print("SUB",sid,a.get("productId"),a.get("state"),a.get("subscriptionPeriod"),"familySharable",a.get("familySharable"))
    for terr in ("TWN","USA","HKG","JPN"):
        p=get(f"/v1/subscriptions/{sid}/prices?filter[territory]={terr}&include=subscriptionPricePoint&limit=5")
        pts={i["id"]:i["attributes"] for i in p.get("included",[])}
        for d in p.get("data",[]):
            pp=d["relationships"]["subscriptionPricePoint"]["data"]["id"]
            at=pts.get(pp,{})
            print("   price",terr,d["attributes"].get("startDate"),at.get("customerPrice"),at.get("proceeds"))
    io=get(f"/v1/subscriptions/{sid}/introductoryOffers?limit=50")
    if "error" in io: print("   intro ERR",io)
    else:
        print("   introOffers:",len(io.get("data",[])), [ (d["attributes"].get("offerMode"),d["attributes"].get("duration"),d["attributes"].get("numberOfPeriods")) for d in io.get("data",[])][:3])
    wb=get(f"/v1/subscriptions/{sid}/winBackOffers?limit=10")
    print("   winBack:", wb.get("error") or len(wb.get("data",[])))
    po=get(f"/v1/subscriptions/{sid}/promotionalOffers?limit=10")
    print("   promoOffers:", po.get("error") or len(po.get("data",[])))
    oc=get(f"/v1/subscriptions/{sid}/offerCodes?limit=10")
    print("   offerCodes:", oc.get("error") or [(d["attributes"].get("name"),d["attributes"].get("duration"),d["attributes"].get("offerMode"),d["attributes"].get("active")) for d in oc.get("data",[])])
# IAP consumables
iaps=get("/v1/apps/6769317103/inAppPurchasesV2?limit=20")
for i in iaps.get("data",[]):
    a=i["attributes"]; print("IAP",i["id"],a.get("productId"),a.get("state"),a.get("inAppPurchaseType"))
    ps=get(f"/v2/inAppPurchases/{i['id']}/pricePoints?filter[territory]=TWN,USA&limit=1")
    # manual price schedule
    sch=get(f"/v2/inAppPurchases/{i['id']}/iapPriceSchedule?include=manualPrices,baseTerritory")
    mp=[x for x in sch.get("included",[]) if x["type"]=="inAppPurchasePrices"]
    print("   manualPrices:",len(mp), "base:", [x["id"] for x in sch.get("included",[]) if x["type"]=="territories"])
