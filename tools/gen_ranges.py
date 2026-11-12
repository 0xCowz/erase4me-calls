#!/usr/bin/env python3
"""Génère les données du bloqueur à partir des données ouvertes de l'ARCEP :

  BlockerExtension/ranges.json  plages E.164 fusionnées, lues par l'extension CallKit
  App/blocks.json               tranches de 1 000 numéros avec leur opérateur (nom, SIRET, adresse, date d'attribution), lues par l'app

Sources (data.gouv.fr, licence ouverte) : [MAJNUM] « Ressources en numérotation téléphonique » et « Identifiants de communications électroniques ».
Les préfixes sont les plages que l'ARCEP réserve à la prospection commerciale depuis le 01/01/2023.

Usage :  python tools/gen_ranges.py                 # 0377 0378 0948 0949 (03 et 09)
         python tools/gen_ranges.py 0162 0270 ...   # autres préfixes (limite d'iOS : environ 2 millions de numéros par extension)
"""
import datetime
import json
import sys
import urllib.parse
import urllib.request

NUM_RID = "90e8bdd0-0f5c-47ac-bd39-5f46463eb806"
OPS_RID = "b0f62183-cd0c-498d-8153-aa1594e5e8d9"
API = "https://tabular-api.data.gouv.fr/api/resources/%s/data/"
DEFAULT = ("0377", "0378", "0948", "0949")
ALL_DEMARCHAGE = ("0162", "0163", "0270", "0271", "0377", "0378", "0424", "0425", "0568", "0569", "0948", "0949")


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "erase4me-ios-blocker/1.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read().decode("utf-8"))


def tranches(prefix):
    rows, url = [], API % NUM_RID + "?" + urllib.parse.urlencode({"EZABPQM__contains": prefix, "page_size": 200})
    while url:
        d = get(url)
        rows += [r for r in d["data"] if r["EZABPQM"].startswith(prefix)]
        url = d.get("links", {}).get("next")
    return rows


def operator(code):
    d = get(API % OPS_RID + "?" + urllib.parse.urlencode({"CODE_OPERATEUR__exact": code}))
    if not d["data"]:
        return {"name": code, "siret": "", "address": ""}
    x = d["data"][0]
    return {"name": (x.get("IDENTITE_OPERATEUR") or code).strip(), "siret": str(x.get("SIRET_ACTEUR") or "").strip(),
            "address": " ".join((x.get("ADRESSE_COMPLETE_ACTEUR") or "").split())}


def e164(national):          # "0377087295" -> 33377087295
    return int("33" + national[1:])


def main():
    prefixes = tuple(sys.argv[1:]) or DEFAULT
    bad = [p for p in prefixes if p not in ALL_DEMARCHAGE]
    if bad:
        sys.exit(f"préfixes non réservés à la prospection, refusés : {bad}")
    rows = []
    for p in prefixes:
        rows += tranches(p)
    out = sorted(({"s": e164(r["Tranche_Debut"]), "e": e164(r["Tranche_Fin"]), "c": r["Mnémo"], "d": r.get("Date_Attribution") or ""} for r in rows),
                 key=lambda t: t["s"])
    codes = sorted({t["c"] for t in out})
    ops = {c: operator(c) for c in codes}
    merged = []
    for t in out:                         # fusion des tranches contiguës ; CallKit exige un ordre croissant sans doublon
        if merged and t["s"] <= merged[-1][1] + 1:
            merged[-1][1] = max(merged[-1][1], t["e"])
        else:
            merged.append([t["s"], t["e"]])
    total = sum(b - a + 1 for a, b in merged)
    with open("BlockerExtension/ranges.json", "w", encoding="utf-8") as f:
        json.dump(merged, f)
    with open("App/blocks.json", "w", encoding="utf-8") as f:
        json.dump({"generated": datetime.date.today().isoformat(), "prefixes": list(prefixes), "operators": ops, "tranches": out}, f, ensure_ascii=False, separators=(",", ":"))
    print(f"{len(merged)} plages, {total} numéros, {len(out)} tranches, {len(ops)} opérateurs (préfixes : {' '.join(prefixes)})")
    if total > 2_000_000:
        print("ATTENTION : au-delà d'environ 2 millions de numéros, iOS peut refuser le chargement de l'extension.")


if __name__ == "__main__":
    main()
