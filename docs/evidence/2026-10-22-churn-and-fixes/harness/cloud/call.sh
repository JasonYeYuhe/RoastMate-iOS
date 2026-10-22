#!/bin/bash
# usage: call.sh <intensity> <locale> <styleName> <situation>
python3 - "$@" <<'PY'
import json,sys,urllib.request,time
i,loc,sty,sit=sys.argv[1:5]
body=json.dumps({"situation":sit,"styleName":sty,"intensity":i,"locale":loc,"deviceId":"audit-churn-lens-2026-10-22"}).encode()
req=urllib.request.Request("https://roastmate-vent.yyyyy-yeyuhe.workers.dev/v1/vent",data=body,headers={"Content-Type":"application/json","User-Agent":"RoastMate/24 CFNetwork/3826.400.120 Darwin/25.0.0"})
t=time.time()
try:
    r=urllib.request.urlopen(req,timeout=60); d=json.load(r)
except urllib.error.HTTPError as e:
    d={"http":e.code,"body":e.read().decode()[:300]}
d["latency_s"]=round(time.time()-t,1)
print(json.dumps(d,ensure_ascii=False))
PY
