# Segment: Event system i consequence loop

## Rola
Spina cause -> handler -> action dla ALife.

## Kluczowe pliki
- [project/scripts/alife_event_bus.gd](../../project/scripts/alife_event_bus.gd)
- [project/scripts/alife_consequence_registry.gd](../../project/scripts/alife_consequence_registry.gd)
- [project/scripts/alife_manager.gd](../../project/scripts/alife_manager.gd)

## Co robi EventBus
- validate payload,
- publish do kolejki,
- drain z budzetem per tick,
- telemetry published/processed/deferred/rejected.

## Co robi ConsequenceRegistry
- mapuje cause_type -> handler,
- loguje brak handlera,
- zapisuje outcome handlera.

## Co robi AlifeManager
- publikuje runtime causes,
- rejestruje consequence handlers,
- drenuje bus z limitem tick budget.

## Szybkie debug checki
- Czy payload ma wymagane pola: schema_version, cause_id, cause_type, source, location_key.
- Czy cause trafia do handlera: sprawdz log strategic_tick.
- Czy budget nie dusi kolejki: monitoruj deferred.
