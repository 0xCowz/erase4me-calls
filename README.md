# Anti-démarchage — bloqueur d'appels iPhone (sideload)

App iOS dans le style erase4me : elle bloque, au niveau du téléphone, les tranches de numéros que l'ARCEP réserve à la
prospection commerciale (01 62, 02 70, 03 77, 04 24, 05 68, 09 48 et leurs plages jumelles) **qui sont réellement attribuées
à un opérateur** : environ 2,27 millions de numéros, répartis sur deux extensions CallKit. Les tranches viennent des données
ouvertes de l'ARCEP (voir `tools/gen_ranges.py`).

## L'app
- **Protection** : état des deux extensions, chiffres clés, date d'expiration de la signature, opérateurs qui détiennent le plus de numéros.
- **Numéros** : opérateurs (nom, adresse, SIRET), tranches et dates d'attribution.
- **Appels** : journal manuel des appels reçus (iOS ne dit pas à une app quels appels il bloque), classement, infractions
  (week-end, jour férié, horaires, plus de 4 appels en 30 jours) et signalement prêt pour SignalConso.
- **Vérifier** : saisis un numéro, l'app dit s'il est bloqué et à qui appartient sa tranche.

## Ce que ça ne fait pas
- Un appel depuis un 06 / 07, un numéro étranger ou un numéro usurpé n'est pas bloqué.
- Un opérateur détient les numéros mais l'identité de son client n'est pas publique.
- Une plage « polyvalente authentifiée » (catégorie ARCEP) peut servir à un appel légitime non commercial : il serait bloqué aussi.
  Pour exclure un préfixe : `python tools/gen_ranges.py 0377 0568 ...` (liste des préfixes voulus).

## 1. Fabriquer l'IPA (sans Mac)
Le workflow GitHub Actions compile sur un Mac gratuit : à chaque `push`, ou à la main (onglet **Actions** > « Build IPA » > Run workflow).
Quand il est vert, télécharge l'artefact `Erase4meCalls-ipa` (zip contenant `Erase4meCalls-unsigned.ipa`).

## 2. Installer (sideload)
Sideloadly ou AltStore, avec ton Apple ID. Compte gratuit : signature valable **7 jours** (l'app affiche le compte à rebours).
Quand elle expire, le blocage s'arrête : réinstalle l'IPA. Première ouverture : Réglages > Général > VPN et gestion de l'appareil >
ton Apple ID > Faire confiance.

## 3. Activer
Réglages > Téléphone > **Blocage d'appels et identification** > active **« Anti-démarchage 1 »** et **« Anti-démarchage 2 »**
(deux extensions : la liste complète dépasse ce qu'une seule gère de façon fiable). L'onglet Protection affiche l'état.

## 4. Mettre à jour la liste
```bash
python tools/gen_ranges.py     # régénère Blocker1/ranges.json, Blocker2/ranges.json et App/blocks.json
```
Puis `git push` : le workflow recompile l'IPA.

## Limites techniques
- CallKit ne bloque pas par préfixe : il faut énumérer chaque numéro (le code les envoie en flux).
- Apple ne documente aucune limite ; des développeurs rapportent environ 1,8 million d'entrées par extension. Chaque extension
  en porte ici environ 1,13 million.
