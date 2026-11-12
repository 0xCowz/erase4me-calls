# Anti-démarchage — bloqueur d'appels iPhone (sideload)

Extension iOS « Call Directory » qui bloque, au niveau du téléphone, les tranches de numéros que l'ARCEP réserve à la
prospection commerciale (03 77, 03 78, 09 48, 09 49) **et qui sont réellement attribuées à un opérateur**
(713 000 numéros). Les tranches viennent des données ouvertes de l'ARCEP (voir `tools/gen_ranges.py`).

## Ce que ça ne fait pas
- Un appel depuis un 06 / 07, un numéro étranger ou un numéro usurpé n'est pas bloqué.
- Les plages 03 77 / 03 78 font partie d'une catégorie ARCEP « polyvalente authentifiée » : un appel légitime non commercial
  venant de ces plages serait aussi bloqué (rare, mais possible), même s'il figure dans tes contacts. Si ça te gêne, génère la
  liste sans ce préfixe (`python tools/gen_ranges.py 0948 0949`).
- Rien n'est testé sur un iPhone : le code n'a pas pu être compilé depuis Windows. À valider à la première installation.

## 1. Fabriquer l'IPA (sans Mac)
Il faut un Mac pour compiler une app iOS ; GitHub en prête un gratuitement :
1. Crée un dépôt GitHub (public = minutes gratuites) et envoie-y le contenu de ce dossier.
2. Onglet **Actions** > « Build IPA non signé » > **Run workflow**.
3. Quand c'est vert, télécharge l'artefact `Erase4meCalls-ipa` (un zip contenant `Erase4meCalls.ipa`).

## 2. Installer (sideload)
- **Sideloadly** (Windows) ou **AltStore / SideStore** : branche l'iPhone, choisis l'IPA, ton Apple ID signe l'app.
- Compte Apple gratuit : l'app expire au bout de **7 jours** (il faut la ré-signer : AltStore le fait seul quand l'iPhone et le PC
  sont sur le même Wi-Fi). Quand elle expire, **le blocage s'arrête**. Compte développeur payant (99 €/an) : 1 an.
- L'extension compte comme une app supplémentaire pour le quota de 3 apps du compte gratuit.

## 3. Activer
Réglages > Téléphone > **Blocage d'appels et identification** > active « Anti-démarchage ». L'app affiche l'état
(bouton « Recharger la liste » si besoin).

## 4. Mettre à jour la liste
```bash
python tools/gen_ranges.py              # 03 77, 03 78, 09 48, 09 49 (défaut)
python tools/gen_ranges.py 0162 0270    # d'autres plages (limite : environ 2 millions de numéros)
```
Puis recommence l'étape 1 (le workflow se relance à chaque `push`).

## Limites techniques
- CallKit ne sait pas bloquer « tous les numéros commençant par… » : il faut énumérer chaque numéro (le code le fait en flux).
- Apple ne documente aucune limite de nombre ; des développeurs rapportent environ 1,8 million d'entrées par extension.

