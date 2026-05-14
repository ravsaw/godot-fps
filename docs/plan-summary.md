# Plan summary (maj 2026)

Zrodlo: [plan.md](../plan.md)

## Co dowiezione
- Stabilny fundament debug map i runtime (headless smoke green).
- Dzialajace strefy A / T_AB / B / T_BC / C z przejsciami opartymi o commit trigger.
- World graph i LOD regionow aktywne.
- Pathing squadow miedzy regionami naprawiony.
- Publiczne command API dla squadow wdrozone.
- Debug/UI odseparowane od runtime internals squadow.
- Stabilizacja transition 2D/3D pod obciazeniem (budget + throttling).
- Sprint 1 (ALife Core Hardening) oznaczony jako completed.
- Migracja krytycznego ticku ruchu/formacji squadow do C++ oznaczona jako completed.

## Co jest aktualnie priorytetem
- Sprint 2 Event Bus MVP i pelny loop cause -> consequence -> action.

## Ryzyka operacyjne
- Build i runtime sa stabilne, ale po zmianach C++ dalej wymagaja pelnej sekwencji: build + headless smoke.

## Minimalna checklista po zmianie gameplay
1. Build GDExtension przechodzi.
2. Headless smoke przechodzi.
3. Brak nowych parser errors.
4. Odpowiedni plik w docs/segments jest zaktualizowany.
