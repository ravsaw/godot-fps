# Plan: Stalker-like FPS w Godot 4 + GDExtension

## Kontekst
- FPS, Godot 4 + C++ GDExtension
- Setting: alternatywny wymiar, estetyka postsowieckiej republiki
- Cele gracza: przeżyj, znajdź wyjście, odkryj tajemnicę
- Świat: kilka stref z płynnymi przejściami (seamless)
- Pierwsza strefa: mała, debug-friendly, zaprojektowana jako vertical slice systemów
- Broń: EFT-style (animowane przeładowanie, attachmenty, degradacja)
- ALife offline: pełna symulacja 2D (potrzeby, ekonomia, terytorium)
- Każdy NPC ma backstory wpływające na zachowanie, preferencje i adaptację do świata
- Frakcje: zacznij od progu lidera, docelowo wszystkie typy dynamiczne
- MVP: podstawowy FPS (ruch, strzelanie, zabijanie NPC)

---

## STATUS IMPLEMENTACJI (Maj 2026)

### Zrealizowane i działające
- Fundament gry i debug mapy działają stabilnie (headless smoke test zielony).
- Strefy A / T_AB / B / T_BC / C działają z płynnym przejściem opartym o commit trigger.
- Regiony mają warstwę LOD (loaded / adjacent / far) oraz widoczność niezaładowanych regionów.
- Globalny graf świata obejmuje wszystkie regiony i przejścia.
- Squady poruszają się po ścieżkach międzyregionowych (naprawione łączenie sąsiadów między strefami).
- Mapowe komendy squadów działają jako narzędzie testowe (wybór, cel, trasa, overlay).

### Otwarte ryzyka / blokery na teraz
- Build GDExtension przez SCons przechodzi w bieżącej sesji (`template_debug` up to date), ale wcześniej wystąpił błąd środowiskowy, więc potrzebna jest obserwacja stabilności.
- Headless runtime Godota uruchamia się poprawnie; każde większe dotknięcie warstwy natywnej dalej wymaga pełnej weryfikacji build + smoke.

### Zamrożenie scope na teraz
- UX klikania squadów pozostaje w trybie debug/test i nie jest teraz priorytetem produkcyjnym.
- Priorytet: pchanie głównego rdzenia ALife (decyzje, event bus, konsekwencje, potrzeby).

---

## PLAN WYKONAWCZY — Następne 2 Sprinty

### Sprint 1 (ALife Core Hardening)
**Cel:** Ustabilizować logikę squadów i dane runtime pod event-driven ALife.

#### Start wykonania Sprintu 1 (najbliższe kroki)
1. Zdiagnozować i opisać przyczynę błędu builda SCons (bez rozszerzania scope feature'ów).
2. Wdrożyć kontrakt ID lokacji (`zone_id:local_id`) i helpery parse/compose w miejscach najbardziej krytycznych dla grafu.
3. Dodać minimalny walidator grafu przy starcie (osierocone węzły + brakujące cele) z czytelnym raportem debug.
4. Odpalić smoke test headless po każdej zmianie i zapisać wynik do krótkiego dziennika sprintu.

1. Ujednolicić model ID lokacji i walidację połączeń międzyregionowych.
2. Dodać debug assertions i checki dla grafu (osierocone węzły, połączenia jednostronne, zerowe edge-case).
3. Dodać prosty task queue dla squadów (goal stack: explicit order -> fallback patrol -> return home).
4. Odseparować warstwę debug map commands od logiki runtime (interfejs poleceń).
5. Ustabilizować transition 2D/3D pod obciążeniem (budżet aktywacji, brak skoków stanu).

**Exit criteria Sprint 1:**
- Squady realizują cele międzyregionowe bez zacięć i bez utraty stanu.
- Graf waliduje się automatycznie przy starcie i po przejściach stref.
- Komendy debug nie ingerują bezpośrednio w detale implementacyjne squad runtime.

#### Sprint 1 — Backlog dzienny (10 dni roboczych)

#### Sprint 1 — Postęp wykonania (aktualizacja)
- Day 1 ✅: Format `zone_id:local_id` używany konsekwentnie. Helpery parse/compose/get_graph_id w ZoneManager. ALife i Squad używają `_format_location_ref()`.
- Day 2-3 ✅: `_validate_world_graph()` + `_report_world_graph_validation()` — orphan/missing/one-way/bad-cost, fail-fast assert w debug, uruchamiane przy każdym przebudowaniu grafu.
- Day 4 ✅: Goal stack w `SquadManager` (`_goal_stack_by_name: Dictionary`). Helpery `_get_active_goal`, `_set_explicit_goal`, `_push_low_priority_goal`, `_pop_goal_and_get_next`. Priorytet: explicit order > return_home.
- Day 5 ✅: Fallback przy braku ścieżki (pop goal + warning, nie blokuje squadu). Głębokość stosu w status i map debug text (`goal:X (+N queued)`).
- Day 6 ✅: Publiczny command API w `SquadManager` (`issue_move_squad`, `issue_move_all_squads`, `issue_select_squad`, `issue_select_next_squad`, `issue_clear_goal`, `issue_clear_all_goals`, `query_selected_squad`, `query_squad_near`).
- Day 7 ✅: `main.gd` używa API komend (UI -> API), bez bezpośredniego dostępu do detali runtime squadów.
- Day 8 ✅: `TransitionManager` ma budżet aktywacji (`_MAX_SPAWNS_PER_TICK`), kolejkę pending spawnów i throttling synchronizacji pozycji (`_POSITION_SYNC_EVERY_N_TICKS`).
- Day 9 ✅: Usunięty hotspot O(n^2) przy spawnach (indeks `info_by_name`) oraz guard przed spóźnionym spawnem poza zasięgiem.
- Weryfikacja: headless smoke test przechodzi, walidacja grafu raportuje stan OK (33 nodes, 0 bad_cost).

**Dzień 1 — Kontrakt ID lokacji**
- Zdefiniować jeden format ID (`zone_id:local_id`) i helpery parse/compose.
- Przepiąć miejsca, gdzie nadal używane są lokalne ID bez prefiksu strefy.
- Dodać check spójności przy tworzeniu grafu świata.

**Dzień 2 — Walidator grafu v1**
- Dodać walidację osieroconych węzłów i brakujących lokacji docelowych.
- Dodać raport ostrzeżeń do debug loga przy starcie.
- Zakończyć fail-fast w trybie debug przy krytycznej niespójności.

**Dzień 3 — Walidator grafu v2**
- Dodać test połączeń jednostronnych (A->B bez B->A).
- Dodać kontrolę edge-case dla zerowego/ujemnego kosztu przejścia.
- Uruchomić smoke test przejść stref i potwierdzić brak regresji.

**Dzień 4 — Task queue squadów: model danych**
- Wprowadzić prosty model `SquadTask` (typ, target, priorytet, TTL).
- Dodać `goal stack` z zasadą: explicit order > fallback patrol > return home.
- Migrować aktualny pojedynczy goal do nowego modelu bez zmiany zachowania.

**Dzień 5 — Task queue squadów: wykonanie**
- Zaimplementować wybór aktywnego taska i przejście do kolejnego po ukończeniu.
- Dodać bezpieczny fallback przy braku ścieżki (nie zawieszaj squadu).
- Dodać debug tekst stanu kolejki na mapie.

**Dzień 6 — Interfejs komend runtime**
- Wyciągnąć publiczny interfejs rozkazów (`issue_move`, `clear_goal`, `set_patrol`).
- Ograniczyć map debug UI do wołania tylko interfejsu (bez dostępu do detali danych).
- Utrzymać pełną kompatybilność aktualnych skrótów klawiszowych.

**Dzień 7 — Dekoupling map debug od runtime**
- Domknąć refactor zależności jednokierunkowej (UI -> API, nie odwrotnie).
- Usunąć bezpośrednie zapisy pól runtime z warstwy mapy.
- Dodać minimalne logi telemetryczne komend gracza.

**Dzień 8 — Stabilizacja transition 2D/3D**
- Wprowadzić budżet aktywacji/dezaktywacji NPC na tick.
- Kolejkować przełączenia przy większym ruchu gracza między strefami.
- Dodać guardy stanu, by uniknąć podwójnej aktywacji i utraty referencji.

**Dzień 9 — Test obciążeniowy i poprawki**
- Odpalić scenariusz z wieloma squadami i częstymi przejściami regionów.
- Zidentyfikować hotspoty i usunąć 1-2 największe źródła niestabilności.
- Potwierdzić brak regresji na map command overlay.

**Dzień 10 — Stabilization freeze + odbiór sprintu**
- Zamrozić nowe zmiany feature'owe, tylko bugfix.
- Sprawdzić kryteria wyjścia sprintu i udokumentować wynik.
- Przygotować checklistę wejściową pod Sprint 2 (Event Bus MVP).

**Definition of Done (Sprint 1):**
- Każdy dzień kończy się krótkim smoke testem headless.
- Brak nowych błędów parsera/skryptów po zmianach.
- Po Dniu 10 wszystkie 3 exit criteria Sprintu 1 są spełnione.

### Sprint 2 (Event Bus MVP)
**Cel:** Dostarczyć działający cause -> consequence loop na aktualnym świecie.

1. Wprowadzić `CauseType` + prosty `EventBus` z budżetem per tick.
2. Dodać minimalny `ConsequenceRegistry` i 2-3 consequences:
  - investigate,
  - retaliate,
  - fallback_retreat.
3. Podpiąć publikację pierwszych cause'ów z istniejących zdarzeń (death/wound/squad_arrive).
4. Dodać log diagnostyczny łańcucha decyzji (cause -> handler -> action).
5. Spiąć ALife tick z prostym systemem priorytetu (nie spamować nowych akcji co tick).

**Exit criteria Sprint 2:**
- W runtime widać pełny łańcuch: cause -> consequence -> ruch squadu.
- Co najmniej jeden emergentny scenariusz konfliktu pojawia się bez ręcznego skryptowania.
- Budżet eventów chroni przed eksplozją akcji i degradacją wydajności.

#### Sprint 2 — Backlog dzienny (10 dni roboczych)

**Dzień 1 — CauseType i payload kontrakt**
- Zdefiniować stabilny enum `CauseType` oraz minimalny format payloadu.
- Ustalić wersjonowanie payloadu (pole `schema_version`) pod dalszą rozbudowę.
- Dodać walidację wymaganych pól w debug buildzie.

**Dzień 2 — EventBus core**
- Zaimplementować `publish` i `subscribe` z prostym lifecycle subskrypcji.
- Dodać kolejkę eventów per tick (bez re-entrant chaosu).
- Dodać budżet przetwarzania eventów na tick.

**Dzień 3 — Integracja ticku ALife z EventBus**
- Spiąć przetwarzanie eventów z istniejącym ALife tick.
- Dodać fallback gdy budżet jest przekroczony (reszta eventów przechodzi na kolejny tick).
- Potwierdzić brak zacięć przy burst publikacji.

**Dzień 4 — ConsequenceRegistry v1**
- Dodać registry handlerów consequence i kontrakt wywołania.
- Wprowadzić kolejność faz: RULES -> SCAN -> ACTION.
- Dodać minimalne guardy dla pustych kandydatów i błędnych danych.

**Dzień 5 — Consequence: investigate**
- Zaimplementować handler `investigate`.
- Podpiąć wybór najbliższego sensownego squadu jako kandydata.
- Dodać log decyzji odrzuceń i przyjęć (why accepted/rejected).

**Dzień 6 — Consequence: retaliate**
- Zaimplementować handler `retaliate` dla wydarzeń konfliktowych.
- Dodać prostą politykę unikania wielokrotnego wysyłania tego samego squadu.
- Potwierdzić, że ruch squadu jest generowany przez consequence, nie przez ręczny skrypt.

**Dzień 7 — Consequence: fallback_retreat**
- Dodać handler odwrotu przy słabym stanie squadu.
- Zaimplementować priorytet bezpieczeństwa nad ofensywą.
- Dodać cooldown, by uniknąć pętli retreat/return.

**Dzień 8 — Publikacja pierwszych cause'ów z runtime**
- Podpiąć `DEATH`, `WOUND`, `SQUAD_ARRIVE` z istniejących miejsc w kodzie.
- Zapewnić idempotencję (brak duplikatów przy pojedynczym zdarzeniu).
- Potwierdzić kompatybilność z obecnym modelem squad task queue.

**Dzień 9 — Diagnostyka i telemetria**
- Dodać czytelny log łańcucha: cause -> handler -> action -> outcome.
- Dodać zliczanie eventów odrzuconych przez budget/cooldown.
- Przygotować prosty raport sesji testowej do porównań regresji.

**Dzień 10 — Odbiór Sprintu 2 i twardnienie**
- Wykonać scenariusz emergentny bez ręcznego skryptowania i spisać wynik.
- Domknąć poprawki stabilności bez dodawania nowych feature'ów.
- Sprawdzić spełnienie exit criteria i przygotować wejście pod fazę potrzeb NPC.

**Definition of Done (Sprint 2):**
- Każdy dzień kończy się krótkim testem headless + weryfikacją logów eventów.
- Co najmniej 3 consequence handlery działają w runtime na realnych zdarzeniach.
- Po Dniu 10 wszystkie exit criteria Sprintu 2 są spełnione.

### Następne TODO (kolejność wykonania)

1. EventBus MVP skeleton w GDScript (`publish`, `subscribe`, `drain`).
  Verify: pojedynczy testowy event przechodzi pełny cykl i jest widoczny w logu.
2. Kontrakt `CauseType` + payload (`schema_version`, `cause_id`, `source`, `location_key`).
  Verify: walidator odrzuca payload bez wymaganych pól z czytelnym warningiem.
3. Integracja EventBus z tickiem ALife (budżet per tick + odłożone eventy).
  Verify: burst eventów nie blokuje ticka; nadmiar przechodzi na kolejny tick.
4. `ConsequenceRegistry` (mapowanie `CauseType -> handler`).
  Verify: brak handlera nie crashuje runtime, tylko loguje odrzucenie.
5. Handler `investigate` (minimalna selekcja najbliższego squadu).
  Verify: po cause typu alert jeden squad dostaje rozkaz ruchu przez public API.
6. Handler `retaliate` + prosty cooldown antyspam.
  Verify: ten sam squad nie dostaje seryjnie identycznej akcji co tick.
7. Publikacja 3 pierwszych cause'ów z runtime: `DEATH`, `WOUND`, `SQUAD_ARRIVE`.
  Verify: każde zdarzenie emituje dokładnie jeden event z poprawnym payloadem.
8. Telemetria łańcucha decyzji (`cause -> handler -> action -> outcome`).
  Verify: w logu da się prześledzić pełny przebieg pojedynczego przypadku.

### Stop Condition (na koniec tej paczki)
- Headless smoke przechodzi po każdym większym kroku.
- Brak nowych błędów parsera w skryptach EventBus/ALife.
- Co najmniej 1 emergentny scenariusz działa bez ręcznego skryptowania.

---

## Dalsze priorytety (po Sprint 2)

1. Needs evaluator i dzienno-nocne różnicowanie zachowań.
2. Własność lokacji / terytorium i presja frakcyjna.
3. Ekonomia podstawowa i loot flow z istniejącym ALife.
4. Dopiero później: dalszy polish UX mapy i rozbudowany panel dowodzenia.

---

## FAZA 0 — Fundament projektu
**Cel:** Kompiluje się, Godot widzi rozszerzenie.

1. Struktura katalogów: `src/`, `project/`, `SConstruct`, `gdextension.gdextension`
2. `register_types.cpp/.h` — puste, poprawna rejestracja
3. Podstawowy SCons build pass (debug + release)
4. Testowa scena `project/scenes/test.tscn` z jednym CustomNode
5. `.gitignore` z `.scons_cache`, `bin/`, `build/`

**Weryfikacja:** `scons target=template_debug` + Godot editor wczytuje projekt bez błędów

---

## FAZA 1 — Rdzeń FPS (MVP)
**Cel:** Gracz może chodzić, strzelać, zabijać NPC.

Kluczowe pliki C++:
- `src/player/player_controller.h/.cpp` — CharacterBody3D, ruch (walk/run/crouch), kamera z head-bob
- `src/player/health_component.h/.cpp` — HP, damage, śmierć
- `src/weapon/weapon_base.h/.cpp` — raycast strzał, ammo, animowany reload (AnimationPlayer)
- `src/npc/npc_agent_3d.h/.cpp` — CharacterBody3D NPC, prosty patrol (NavigationAgent3D), combat (widzi gracza → strzela)
- `src/npc/hitbox.h/.cpp` — hitbox z mnożnikiem obrażeń (głowa, tułów)

GDScript (glue):
- `project/scripts/hud.gd` — HP, ammo na ekranie
- `project/scenes/player.tscn`, `project/scenes/npc_test.tscn`

**Weryfikacja:** Gracz chodzi, strzela, NPC patroluję i odpowiada ogniem; można go zabić

---

## FAZA 2 — System broni (EFT-style)
**Zależy od:** Fazy 1

Kluczowe pliki C++:
- `src/weapon/weapon_component.h/.cpp` — trzyma aktywną broń, switching
- `src/weapon/weapon_attachment_slot.h/.cpp` — gniazda (lufa, szyna, kolba, celownik)
- `src/weapon/weapon_stats.h/.cpp` — degradacja (durability), wpływ na celność/niezawodność
- `src/weapon/weapon_inspect.h/.cpp` — trigger animacji inspekcji

Animacje (Godot AnimationTree per weapon):
- reload_normal, reload_empty, inspect, equip, fire, jam_clear

**Weryfikacja:** Broń degraduje przy strzelaniu; można zamontować attachment i zobaczyć zmianę stats; inspect działa

---

## FAZA 3 — Świat i Smart Locations
**Cel:** Struktura danych świata gotowa do ALife

Kluczowe pliki C++:
- `src/world/smart_location.h/.cpp` — Resource: id, typ (camp/outpost/ruins/trader/anomaly_field), pozycja_2d, max_population, właściciel (faction_id), lista NPC_id
- `src/world/world_graph.h/.cpp` — Graf: węzły = SmartLocation, krawędzie = ścieżki z dystansem; zapytania nearest, connected
- `src/world/zone_manager.h/.cpp` — Node autoload: ładuje strefy, obsługuje seamless przejście między nimi (area trigger → load next zone async)

Sceny:
- 1 mała, debug-friendly strefa startowa z 6-10 SmartLocation i czytelnymi liniami sight/pathing
- 1 sąsiednia mikrostrefa do przetestowania seamless transition bez pełnej skali świata

**Weryfikacja:** Gracz przechodzi między strefami bez ekranu ładowania; każda SmartLocation ma właściciela widocznego w debug HUD; pierwsza strefa pozwala szybko odtwarzać bugi AI i pathingu

---

## FAZA 4 — Fundament ALife 2D
**Cel:** NPC istnieją w symulacji nawet poza zasięgiem gracza

Kluczowe pliki C++:
- `src/alife/npc_data.h` — struct: id, faction_id, squad_id, health, pozycja_2d (SmartLocation), inventory[], personality (7 traitów: aggression, greed, survival, perception, territory, discipline, social), backstory_profile, adaptation_state, needs_timestamps[]
- `src/alife/backstory_profile.h/.cpp` — pochodzenie, zawód sprzed porwania, dominujące lęki, kompetencje, moralność, tolerancja ryzyka, stosunek do przemocy, relacje startowe
- `src/alife/squad.h/.cpp` — atomowa jednostka: lista NPC, cel (target_location_id), stan (idle/moving/combat/resting)
- `src/alife/alife_manager.h/.cpp` — Singleton autoload; główna pętla symulacji 2D (co N sekund gry):
  - porusza squady po WorldGraph (czas = dystans/prędkość)
  - przy przybyciu do lokacji → trigger eventu
  - aktualizuje adaptation_state na podstawie przeżyć, ran, głodu, strat squadu i czasu w wymiarze
- `src/alife/transition_manager.h/.cpp` — zarządza 3D↔2D:
  - player_radius = 300m; NPC w promieniu → instantiate NpcAgent3D
  - NPC poza promieniem → usuń węzeł, wróć do NpcData

**Weryfikacja:** NPC poza widokiem poruszają się między lokacjami; przy zbliżeniu gracza wyskakują jako 3D; przy oddaleniu znikają i ALife kontynuuje stan

---

## FAZA 5 — Event Bus (Cause → Consequence)
**Inspiracja:** ALifePlus (reaktywne + radiant)
**Zależy od:** Fazy 4

Kluczowe pliki C++:
- `src/alife/event_bus.h/.cpp` — pub/sub: `publish(CauseType, payload)`, `subscribe(CauseType, handler_fn)`
- `src/alife/cause_types.h` — enum: DEATH, WOUND, ITEM_PICKUP, MASSACRE, SQUAD_ARRIVE, SQUAD_NEEDS_EVAL
- `src/alife/consequence_registry.h/.cpp` — rejestruje handlery; każdy handler ma 3 fazy: RULES (alignment+personality gate) → SCAN (znajdź kandydatów) → ACTION (skieruj squad)
- `src/alife/alignment.h` — tabele: które frakcje mogą wykonać który consequence
- `src/alife/personality.h` — roll prawdopodobieństwa: avg(relevant_traits) ∈ [0.10, 0.70]
- `src/alife/rate_limiter.h` — budget per tick (nie spamuj consequenceów)

Pierwsza pula consequences:
- `massacre_investigate` — ktoś zginął, allies idą sprawdzić
- `massacre_scavenge` — ciała → słabsze frakcje idą po łupy
- `ally_retaliate` — squad sojusznika zabity → odpowiedź
- `basekill_flee` — baza zaatakowana → słabi uciekają

**Weryfikacja:** Zabicie grupy NPC triggeruje investigate z sąsiednich lokacji; w logu widać CAUSE → CONSEQUENCE → ACTION

---

## FAZA 6 — Potrzeby NPC, backstory i Radiant behavior
**Zależy od:** Fazy 5

Model potrzeb (Hull's Drive Reduction: `score = weight * (elapsed/threshold)²`):
- hunger, fatigue, rest, heal, shelter, money, supply, job, social

Backstory jako modyfikator zachowań:
- pochodzenie i zawód modyfikują bazowe wagi potrzeb i kompetencji
- moralność, tolerancja ryzyka i stosunek do przemocy wpływają na alignment/personality gate
- adaptation_state częściowo nadpisuje backstory wraz z upływem czasu: NPC mogą twardnieć, paranoizować się, dziczeć albo budować więzi

Kluczowe pliki C++:
- `src/alife/needs_evaluator.h/.cpp` — co N sekund gry: oblicza score każdej potrzeby per squad, wybiera najwyższy, publikuje CAUSE (SQUAD_NEEDS_EVAL z dominant_need)
- `src/alife/adaptation_rules.h/.cpp` — reguły zmiany zachowań po ciężkich przeżyciach, długim głodzie, zdradzie, sukcesach bojowych i czasie spędzonym w świecie
- Consequences dla potrzeb:
  - `need_hunger` → idź do obozu i jedz z inventory
  - `need_heal` → wróć do bazy frakcji
  - `need_social` → idź do ogniska (campfire location)
  - `need_money` → idź do strefy anomalii / trupa po loot

Cykl dzień/noc:
- `src/world/time_manager.h/.cpp` — game time, day/night flag
- Radiant causes filtrowane przez active_period (dzień vs noc)

**Weryfikacja:** Dwa NPC z różnym backstory reagują inaczej na ten sam bodziec; nocą część zostaje przy ogniskach; po serii ciężkich zdarzeń ich adaptation_state zmienia priorytety

---

## FAZA 7 — Terytorium i dynamika frakcji
**Zależy od:** Faz 4, 5

Kluczowe pliki C++:
- `src/alife/territory_manager.h/.cpp` — Conquest: squad przybywa do pustej lokacji → przejmuje ownership; Decay: co 72h gry bez obecności → traci ownership; FIFO cap: frakcja max 50 lokacji
- `src/alife/faction_manager.h/.cpp` — dane frakcji (id, nazwa, alignment, personality_traits[]), macierz relacji (hostile/neutral/friendly), historia konfliktów
- Causes: `AREA_EMPTY_SPOTTED` (radiant: squad widzi pustą lokację w zasięgu EyeRange)
- Consequence: `area_conquer` → squad idzie, na przybyciu ustawia ownership

**Weryfikacja:** Pusta lokacja zostaje zajęta przez pobliski squad; po upływie czasu bez reinforcement wraca do neutral; debug HUD pokazuje aktualne terytorium

---

## FAZA 8 — Ekonomia, anomalie i artefakty
**Zależy od:** Faz 6, 7

- `src/economy/item_registry.h/.cpp` — definicje itemów (broń, amunicja, jedzenie, leki, artefakty/anomalia items)
- `src/economy/inventory.h/.cpp` — rzeczywisty ekwipunek per NPC/gracz
- `src/economy/trader_logic.h/.cpp` — NPC trader: kupuje/sprzedaje według popytu; ceny dynamiczne
- `src/world/anomaly_field.h/.cpp` — pole anomalii jako obiekt świata: hazard, VFX, audio, reguły spawnu artefaktów i ryzyko wejścia
- `src/world/artifact_item.h/.cpp` — artefakt ma jednocześnie wartość ekonomiczną, gameplayowy efekt i mocny podpis wizualno-dźwiękowy
- Itemizacja artefaktów: unikalne właściwości odkrywane przez eksplorację anomaly fields
- Loot z ciał: NPC nosi prawdziwy inventory (nie spawn losowego lootu)
- Decyzja projektowa: od pierwszego vertical slice anomalie i artefakty są jednocześnie mechaniczne i widowiskowe, ale w małej liczbie typów

**Weryfikacja:** Zabity NPC ma inventory odpowiednie do frakcji; trader ma ograniczone zasoby które się wyczerpują; pierwsze anomaly field jest czytelne wizualnie i daje artefakt z realnym efektem

---

## FAZA 9 — Dynamiczne frakcje (MVP: próg lidera)
**Zależy od:** Fazy 8

Prosta implementacja:
- `src/alife/faction_formation.h/.cpp` — NPC bez frakcji (`faction_id = NONE`); gdy jeden NPC zbierze ≥5 followers (NPC w tym samym squad przez ≥N godzin gry) → `FactionFormationEvent` → nowa frakcja z alignment dziedziczonym z osobowości lidera
- Schizma (późniejsza iteracja): gdy wewnątrz frakcji 2+ NPC mają konfliktujące trait dominance → split event

**Weryfikacja:** Bezfrakcyjne NPC z czasem formują grupy; nowa frakcja pojawia się w faction_manager z własnym ID

---

## FAZA 10 — Integracja gracza z systemami
**Zależy od:** Wszystkich poprzednich faz

- Reputacja gracza per frakcja (float -1..1); zmienia alignment wobec gracza
- Gracz ma własną "frakcję" (loner); może przyłączyć się do innej
- NPC gossip / news: po zdarzeniu losowy pobliski NPC może mieć dialog hint
- Lore discovery: anomaly fields i ruiny zawierają notatki/nagrania wyjaśniające tajemnicę wymiaru
- Główny wątek: kilka unikatowych lokacji (anomaly nexus) powiązanych z mechaniką wyjścia

---

## FAZA 11 — Styl wizualny i polish
- Post-processing: color grading, chromatic aberration, grain (retro feel jak Teardown bez voxeli)
- Oświetlenie: baked GI + dynamic sky, mgła wolumetryczna
- LOD dla NPC 3D; poza promieniem 3D = dane 2D
- Dźwięk: warstwy ambientu (wiatr, odległe strzały = ALife walki w 2D)
- Zapis/wczytanie: serializacja ALife state (NpcData[], SmartLocation[] ownership, FactionManager)

---

## Architektura techniczna — kluczowe decyzje

| Komponent | Technologia | Uzasadnienie |
|-----------|-------------|--------------|
| Symulacja offline | C++ struct array w ALifeManager | Zero overhead Godot nodes dla setek NPC poza zasięgiem |
| Event bus | C++ pub/sub z rate limiter | Zero polling, zero pracy gdy nic się nie dzieje (jak ALifePlus) |
| Squady jako jednostka atomowa | Squad struct, nie per-NPC | Skaluje się — 1000 NPC = 200 squadów |
| Personality gate | avg(traits) clamped [0.10,0.70] | Nawet wroga frakcja czasem zachowuje się inaczej |
| 3D↔2D transition | radius-based instantiation | NPC zawsze istnieje w symulacji; 3D to tylko "render proxy" |
| Needs scoring | Hull's Drive Reduction (score = w*(e/t)²) | Nieliniowe — krytyczna potrzeba dominuje |

## Kluczowe pliki struktury

---

## Projekt frakcji — startowe 2 frakcje

### 1. Zbieracze
Rola w świecie:
- pragmatyczni ocaleni, skupieni na przetrwaniu, handlu i odzysku
- traktują wymiar jako wrogie środowisko, ale wierzą, że da się go zrozumieć i wykorzystać
- naturalna frakcja "ludzka" dla gracza i większości cywilnych NPC

Tożsamość systemowa:
- alignment: self-preserving / pragmatic
- dominujące cechy: survival, greed, social, perception
- słabości: niska dyscyplina, umiarkowana agresja, skłonność do wycofania przy dużym ryzyku
- preferowane consequences: scavange, trade, investigate, retreat, assist allies, anomaly harvest
- niechętnie: frontal assault, territory overextension, suicidal defense

Styl gry wokół nich:
- obozy, ogniska, warsztaty, handel
- lepiej wykorzystują loot, częściej noszą jedzenie, narzędzia i części
- ich mikrohistorie najlepiej sprzedają motyw "porwani ludzie próbują się urządzić"

### 2. Strażnicy Progu
Rola w świecie:
- grupa, która uznała, że świat wymaga porządku, kontroli przejść i ograniczania chaosu
- nie są "wojskiem" z gotowym państwem w tle; to improwizowana, twardniejąca struktura władzy powstała już w tym wymiarze
- wierzą, że kontrola węzłów, bram i anomalii jest jedyną drogą do przeżycia lub odkrycia wyjścia

Tożsamość systemowa:
- alignment: principled / authoritarian
- dominujące cechy: discipline, territory, aggression, duty
- słabości: niższa elastyczność, mniejsza otwartość społeczna, skłonność do eskalacji konfliktu
- preferowane consequences: defend, conquer, retaliate, checkpoint control, armed escort, enforce tolls
- niechętnie: swobodny handel, rozproszenie, pozostawianie pustych lokacji

Styl gry wokół nich:
- checkpointy, barykady, stałe posterunki
- lepsza organizacja bojowa, gorsza improwizacja ekonomiczna
- są dobrym kontrapunktem dla Zbieraczy: porządek kontra przetrwanie przez adaptację

### Relacja między frakcjami
- startowo: napięta neutralność przechodząca w lokalne konflikty
- oś konfliktu nie jest ideologiczna wprost; dotyczy kontroli zasobów, przejść i sposobu radzenia sobie z nieznanym światem
- Zbieracze chcą ruchu, wymiany i swobody decyzji
- Strażnicy Progu chcą kontroli, hierarchii i ograniczenia ryzyka przez nadzór
- gracz może balansować między nimi bez kopiowania gotowych układów z uniwersum Stalkera

### Rozszerzalność pod późniejsze frakcje
- system frakcji ma przyjmować nowe grupy przez zmianę 4 osi: porządek, przemoc, wspólnotowość, stosunek do anomalii
- przyszłe frakcje nie muszą być "pisane ręcznie" od zera; mogą powstawać jako kombinacje tych osi plus lider i historia powstania

---

## Projekt backstory — archetypy i zasady

### Zasada
Backstory nie jest flavor textem. To zestaw startowych parametrów i relacji, które wpływają na:
- próg paniki
- tolerancję ryzyka
- preferencje broni i ekwipunku
- zaufanie do frakcji i obcych
- szybkość adaptacji do wymiaru
- dominujące potrzeby i prawdopodobieństwo określonych consequences

### Warstwy backstory NPC
1. Pochodzenie społeczne
- robotnik, technik, ratownik, lekarz, ochroniarz, przestępca, urzędnik, student, kierowca, myśliwy

2. Stan psychiczny przy porwaniu
- zaprzeczenie, szok, pragmatyzm, agresja obronna, ciekawość, religijna interpretacja, apatia

3. Kompetencje
- walka, medycyna, mechanika, handel, orientacja terenowa, gotowanie, dowodzenie

4. Wzorzec więzi
- samotnik, rodzinny, stadny, oportunista, opiekun

5. Adaptacja długoterminowa
- twardnieje, dziczeje, organizuje innych, załamuje się, staje się fanatyczny, zostaje wędrowcem

### Startowe archetypy do MVP+1
1. Były ratownik
- wysoka empatia, medycyna, umiarkowana odwaga
- częściej pomaga rannym, rzadziej dobija przeciwników, dobrze działa w obozach

2. Warsztatowiec
- mechanika, ostrożność, skłonność do zbieractwa
- preferuje loot, naprawy, broń w lepszym stanie, tworzy zapasy

3. Ochroniarz
- wysoka gotowość bojowa, dyscyplina, umiarkowana lojalność wobec silnej hierarchii
- łatwo przechodzi do Strażników Progu

4. Kombinator
- handel, oportunizm, wysoka tolerancja ryzyka, niska lojalność
- świetny kandydat do czarnego rynku, przemytu i późniejszej schizmy frakcyjnej

### Reguła implementacyjna
- archetyp = preset wag i tagów
- indywidualny NPC = archetyp + 2-3 odchyłki losowane w bezpiecznym zakresie
- adaptation_state z czasem modyfikuje preset, ale nie wymazuje całkowicie rdzenia postaci

---

## Pierwszy vertical slice — debug-friendly

### Cel
Udowodnić, że działa pętla:
- eksploracja FPS
- walka
- NPC 3D blisko gracza / 2D daleko
- dwa obozy dwóch frakcji
- jeden łańcuch emergentny od eventu do konsekwencji
- jedna anomalia i jeden artefakt

### Mapa
Mała strefa testowa podzielona na 8 punktów:
1. Obóz Zbieraczy
2. Warsztat / punkt handlu
3. Zrujnowany blok mieszkalny
4. Skrzyżowanie z wrakiem autobusu
5. Checkpoint Strażników Progu
6. Opuszczony magazyn
7. Pole anomalii
8. Kanał / przejście do mikrostrefy

Założenia:
- wszystkie punkty w zasięgu krótkiej sesji debugowej 3-7 minut
- czytelne linie sightline dla testów strzelania
- 2-3 ścieżki obchodzące centrum dla testów AI i flankowania
- mikrostrefa za przejściem służy tylko testowi streamingu i 2D→3D transition

### Minimalna obsada symulacji
- 6 NPC Zbieraczy
- 6 NPC Strażników Progu
- 2 neutralnych outsiderów bez frakcji
- 1 trader
- 1-2 wrogie byty środowiskowe lub prosty hazard anomalii

### Minimalny łańcuch emergentny do dostarczenia
1. Squad Zbieraczy idzie do pola anomalii po artefakt
2. Dochodzi do kontaktu przy checkpointcie Strażników Progu
3. Powstaje ranny lub trup
4. Event `DEATH` lub `WOUND` publikuje cause
5. Sąsiedni squad reaguje: investigate albo retaliate
6. Gracz może wejść w środek sytuacji i zmienić wynik
7. Po wszystkim ktoś wraca z lootem albo wycofuje się do obozu

To ma być pierwszy dowód, że świat "dzieje się sam".

### Zakres systemów dla vertical slice
Wchodzą:
- ruch FPS i strzelanie
- 1 broń główna + 1 zapasowa
- health i prosty damage model
- 2 frakcje
- 4 archetypy backstory
- SmartLocation + WorldGraph
- ALife 2D dla squadów
- transition 2D/3D
- Event Bus
- 4 consequences: investigate, retaliate, retreat, anomaly_harvest
- 1 anomalia + 1 artefakt
- prosty loot i podstawowy trader
- debug HUD z widokiem squadów, current goal, faction owner, event log

Nie wchodzą:
- attachmenty full EFT
- degradacja broni pełnej skali
- tworzenie nowych frakcji
- rozbudowana ekonomia
- główny wątek fabularny
- rozbudowany dialog system

### Kolejność implementacji vertical slice
1. Fundament projektu + rejestracja GDExtension
2. Player controller + jedna broń + NPC combat sandbox
3. Mała mapa testowa z 8 punktami i navmesh
4. SmartLocation + WorldGraph debug visualization

---

## Macierz frakcji — parametry startowe

### Skale cech
Skala 0.0-1.0. Wartości startowe służą do:
- personality gate
- doboru consequence handlers
- modyfikacji wag potrzeb
- relacji z graczem i innymi frakcjami

### Zbieracze
- aggression: 0.38
- greed: 0.67
- survival: 0.74
- perception: 0.58
- territory: 0.31
- discipline: 0.42
- social: 0.71
- order_axis: 0.34
- anomaly_affinity: 0.69
- violence_acceptance: 0.41

Konsekwencje z premią:
- anomaly_harvest
- scavange
- assist_ally
- investigate
- retreat_with_loot
- trade_run

Konsekwencje z karą:
- frontal_assault
- hold_position_under_losses
- checkpoint_extortion
- forced_recruitment

Startowe relacje:
- do Strażników Progu: `-0.25`
- do outsiderów: `+0.15`
- do gracza neutralnego: `+0.10`

### Strażnicy Progu
- aggression: 0.64
- greed: 0.33
- survival: 0.59
- perception: 0.61
- territory: 0.82
- discipline: 0.86
- social: 0.37
- order_axis: 0.88
- anomaly_affinity: 0.28
- violence_acceptance: 0.68

Konsekwencje z premią:
- defend_checkpoint
- retaliate
- area_conquer
- escort
- inspect_intruder
- enforce_toll

Konsekwencje z karą:
- free_trade
- risky_anomaly_harvest
- deep_exploration_without_support
- scatter

Startowe relacje:
- do Zbieraczy: `-0.25`
- do outsiderów: `-0.10`
- do gracza neutralnego: `0.00`

### Zasady relacji
- relacja `> 0.35` = skłonność do pomocy i handlu
- relacja `-0.20 do 0.35` = napięta neutralność
- relacja `< -0.20` = wysokie ryzyko prowokacji, kontroli lub konfliktu
- pojedyncze zdarzenia nie zmieniają relacji gwałtownie; preferowany model: małe delty, ale z pamięcią ostatnich 5-10 incydentów

### Reguły zachowania frakcyjnego
- Zbieracze podnoszą priorytet `money`, `social`, `supply`, gdy zapasy maleją
- Strażnicy Progu podnoszą priorytet `territory`, `job`, `retaliate`, gdy w pobliżu dojdzie do śmierci lub wtargnięcia
- anomaly_affinity wpływa na chęć wejścia w pole anomalii mimo ryzyka
- order_axis wpływa na tolerancję chaosu i gotowość do dołączenia do sztywnej hierarchii

---

## Tabela archetypów backstory — wagi implementacyjne

### Pola implementacyjne
Każdy archetyp definiuje:
- `trait_mods`
- `need_weight_mods`
- `skill_tags`
- `faction_bias`
- `starting_item_bias`
- `adaptation_bias`

### 1. Były ratownik
- trait_mods: aggression `-0.08`, survival `+0.10`, social `+0.16`, discipline `+0.05`
- need_weight_mods: heal `+0.30`, shelter `+0.15`, money `-0.05`
- skill_tags: `medical`, `calm_under_pressure`, `field_recovery`
- faction_bias: Zbieracze `+0.18`, Strażnicy Progu `+0.04`
- starting_item_bias: bandage, medkit, flashlight, food
- adaptation_bias: `caretaker_to_hardened`
- widoczny efekt: częściej pomaga rannym i wraca po sojusznika zamiast dobijać przeciwnika

### 2. Warsztatowiec
- trait_mods: greed `+0.09`, survival `+0.08`, perception `+0.04`, aggression `-0.06`
- need_weight_mods: supply `+0.28`, money `+0.18`, social `-0.04`
- skill_tags: `mechanics`, `repair`, `salvage`
- faction_bias: Zbieracze `+0.22`, Strażnicy Progu `-0.02`
- starting_item_bias: tools, scrap, sidearm, weapon_parts
- adaptation_bias: `hoarder_builder`
- widoczny efekt: częściej zbiera części, wybiera drogę do warsztatu i utrzymuje zapasy

### 3. Ochroniarz
- trait_mods: aggression `+0.12`, discipline `+0.18`, territory `+0.11`, social `-0.05`
- need_weight_mods: job `+0.20`, shelter `+0.08`, money `-0.02`

---

## Godot 4 — podział odpowiedzialności (Node vs czyste C++)

### Zasada ogólna
W Godot 4 tylko to, co musi istnieć w SceneTree, być serializowane jako scena/resource, albo rozmawiać bezpośrednio z silnikiem render/physics/navigation, powinno być `Node`, `Resource` albo `RefCounted` expose'owane do Godota.
Reszta ma być zwykłym C++.

### Robić jako Godot `Node`
- `PlayerController` — bo korzysta z `CharacterBody3D`, kamery, inputu i kolizji
- `NpcAgent3D` — bo korzysta z `CharacterBody3D`, `NavigationAgent3D`, animacji i percepcji w świecie 3D
- `ZoneManager` — bo zarządza ładowaniem scen stref i obecnością ich rootów w drzewie
- `TransitionManager` — bo obserwuje pozycję gracza i spawnuje/despawnuje reprezentacje 3D
- `DebugOverlay` / debug HUD — bo rysuje informacje i reaguje na input debugowy
- `AnomalyFieldNode` — gdy pole anomalii ma trigger, VFX, audio i collider w świecie

### Robić jako Godot `Resource`
- `SmartLocationResource` — definicja punktu świata, łatwa edycja w Inspectorze
- `FactionDefinitionResource` — dane frakcji, kolory, zakresy cech, nastawienia bazowe
- `BackstoryArchetypeResource` — archetypy NPC do strojenia bez rekompilacji
- `WeaponConfigResource` — statystyki broni, sloty attachmentów, anim sets
- `ArtifactDefinitionResource` — efekt, wartość, VFX tagi, ryzyko pola anomalii

### Robić jako czyste C++
- `NpcData`
- `Squad`
- `WorldGraph`
- `EventBus`
- `ConsequenceRegistry`
- `RateLimiter`
- `NeedsEvaluator`
- `FactionRuntimeState`
- `RelationshipMemory`
- `OfflineCombatResolver`
- `AdaptationRules`

Powód:
- te obiekty mają być tanie, masowe i niezależne od SceneTree
- nie potrzebują `_process()` ani serializacji jako node
- mają działać dla setek NPC bez kosztu drzewa scen

### Robić jako `RefCounted` lub cienkie klasy mostkujące
- `ALifeManager` jako Godot singleton bridge z wewnętrznym czystym runtime
- `WorldStateSnapshot`
- `DebugCommandService`

Praktyczny wzorzec:
- warstwa Godot: odbiera sygnały, input, sceny, pozycje 3D
- warstwa runtime C++: liczy symulację, decyzje i eventy
- mostek: tłumaczy runtime state na spawn/despawn node'ów i odwrotnie

---

## Godot 4 — rekomendowana architektura 2D↔3D transition

### Główna zasada
NPC nie "staje się" obiektem 3D. NPC zawsze istnieje jako rekord runtime (`NpcData`).
W pobliżu gracza pojawia się tylko jego reprezentacja 3D (`NpcAgent3D`).

### Stan źródłowy
Źródłem prawdy zawsze jest runtime:
- pozycja logiczna
- health
- inventory
- squad
- current goal
- combat state
- backstory/adaptation

`NpcAgent3D` jest tylko wykonawcą lokalnej symulacji wysokiej rozdzielczości.

### Kiedy spawn 3D
Warunki wejścia online:
- NPC znajduje się w aktywnej strefie
- odległość od gracza < promień aktywacji
- istnieje bezpieczny punkt odtworzenia na navmesh / smart markerze
- squad nie jest w stanie, który wymaga pozostania wyłącznie offline (np. uproszczona walka bardzo daleko w mikrostrefie)

### Kiedy despawn 3D
Warunki wyjścia offline:
- NPC oddalił się poza promień dezaktywacji
- nie jest bezpośrednio obserwowany przez gracza lub nie trwa krytyczna akcja first-person
- jego stan może zostać bezpiecznie zredukowany do runtime snapshot

### Histereza
Nie używać jednego promienia.
- `online_radius = 120-160m`
- `offline_radius = 170-220m`

To zapobiega migotaniu spawn/despawn przy granicy.

### Pipeline wejścia online
1. `TransitionManager` wykrywa kwalifikację NPC.
2. Pobiera `NpcData` z runtime.
3. Tworzy `NpcAgent3D` z odpowiedniej sceny prefab.
4. Wstrzykuje snapshot: hp, wyposażenie, aktualny target, stance, frakcja, archetyp.
5. Rejestruje mapowanie `npc_id -> node instance`.
6. Runtime oznacza NPC jako `online_simulated`.

### Pipeline wyjścia offline
1. `TransitionManager` pobiera końcowy snapshot z `NpcAgent3D`.
2. Aktualizuje `NpcData`.
3. Jeśli NPC był w walce, redukuje stan do offline combat ticket lub finalnego wyniku.
4. Usuwa node z `SceneTree`.
5. Runtime oznacza NPC jako `offline_simulated`.

### Ważne ograniczenia Godot 4
- nie robić spawn/despawn setek node'ów w jednej klatce; używać budżetu na frame
- `call_deferred()` i kolejka aktywacji pomogą uniknąć spike'ów
- unikać ciężkiego `_process()` w każdym `NpcAgent3D`; preferować tick manager lub rzadsze aktualizacje percepcji
- animation state po wejściu online powinien zaczynać od prostego stanu bazowego, nie próbować idealnie odtwarzać każdej klatki offline

### Offline combat w Godot 4
Daleko od gracza walka nie powinna używać node'ów 3D.
Zamiast tego:
- `OfflineCombatResolver` liczy starcie matematycznie w krokach czasu
- gdy gracz się zbliży, można zmaterializować aktualny stan starcia: trupy, ranni, resztki squadu, pozycje przy cover markerach

To jest dużo ważniejsze dla skali niż "uczciwe" trzymanie wszystkich NPC jako node'ów.

---

## Godot 4 — organizacja scen, zasobów i katalogów

### Cel
Utrzymać projekt czytelny, mimo że logika jest w C++, a świat i tuning w Godocie.

### Rekomendowany layout
`project/`
- `scenes/characters/` — `player.tscn`, `npc_agent_3d.tscn`, warianty wizualne
- `scenes/weapons/` — sceny broni pierwszoosobowych i pickupów
- `scenes/world/` — strefy, checkpointy, obozy, anomaly fields
- `scenes/ui/` — HUD, debug overlay, inventory screens
- `resources/factions/` — `FactionDefinitionResource`
- `resources/backstories/` — `BackstoryArchetypeResource`
- `resources/weapons/` — `WeaponConfigResource`
- `resources/artifacts/` — `ArtifactDefinitionResource`
- `resources/world/` — `SmartLocationResource`, połączenia grafu, spawn sets
- `scripts/` — cienkie glue scripts GDScript
- `autoload/` — bootstrapy i lekkie integracje editor/runtime

### Zasada prefabów
- jeden bazowy `npc_agent_3d.tscn`
- warianty wizualne przez mesh/material loadout, nie osobne sceny per archetyp
- jedna scena `anomaly_field_base.tscn` z Resource definiującym typ
- broń: config resource + wspólna scena bazowa, a nie osobna logika na każdą sztukę od początku

### Zasada danych świata
Nie kodować świata w C++ na sztywno.
- SmartLocation i graf połączeń mają być assetami/Resource
- strefa ma root scene plus powiązany zestaw resource'ów opisujących logiczne punkty
- dzięki temu można szybko iterować bez rekompilacji C++

### Zasada debugowej edycji
Do vertical slice potrzebne są edytowalne w Inspectorze:
- promienie transition
- liczebność squadów
- relacje frakcyjne
- cechy archetypów
- parametry anomalii
- progi consequence handlers

Jeśli coś wymaga ciągłego strojenia, nie powinno być zakopane w kodzie jako stała kompilacyjna.

### Zasada scen stref
Każda strefa powinna mieć:
- `ZoneRoot`
- markery SmartLocation
- markery cover / patrol / spawn
- `NavigationRegion3D`
- punkty wejścia/wyjścia do sąsiednich stref
- lokalny ambient i światło

### Zasada bootstrapu
Autoloady Godot 4 minimalne:
- `GameBootstrap`
- `ZoneManager`
- `ALifeBridge`
- `DebugServices`

Nie robić z autoloadów całej gry. To mają być koordynatory, nie wielkie obiekty-godziny policyjne.

---

## Godot 4 — konkretne zalecenia wykonawcze

### Rejestracja GDExtension
- każda klasa expose'owana do Godota musi mieć jasny powód istnienia w API
- nie wystawiać całego runtime jako klas edytorowych
- runtime może siedzieć za jedną lub dwiema klasami bridge

### Physics i ticks
- logika strzelania, ruchu i percepcji 3D: `_physics_process`
- logika ALife offline: osobny tick czasowy w managerze, np. co 0.2-1.0 s czasu rzeczywistego lub przelicznik game time
- nie mieszać pełnej symulacji offline do `_physics_process` każdego node'a

### Navigation
- lokalna nawigacja 3D tylko dla online NPC
- strategiczna nawigacja offline po `WorldGraph`, nie po navmesh całej mapy
- to rozdzielenie jest krytyczne

### Save/load
- serializować runtime state, nie całe node'y 3D
- node'y online po wczytaniu mają być odtworzone z runtime snapshotu
- Godot 4 scene serialization nie powinna być głównym mechanizmem save systemu dla ALife

### UI debugowe
W Godot 4 warto od początku mieć:
- panel z listą NPC online/offline
- panel event logu
- podgląd relacji frakcji
- podgląd aktualnego celu squadu
- komendy testowe z poziomu UI, nie tylko przez konsolę

---

## Dodatkowe decyzje projektowe pod Godot 4

1. Pierwszy vertical slice nie powinien używać proceduralnego generowania stref.
Ręcznie zbudowana strefa będzie szybsza do debugowania w edytorze Godot 4.

2. Pierwsza implementacja broni nie powinna zależeć od pełnego systemu attachmentów.
W Godot 4 szybciej dowieziesz solidny feeling jednej broni niż modularność całego arsenału.

3. Visual scripting i nadmiar GDScriptu nie powinny przejmować logiki ALife.
GDScript ma spinać UI, sceny i wygodne iterowanie, ale ciężar systemowy ma zostać w C++.

- skill_tags: `combat`, `formation`, `checkpoint`
- faction_bias: Zbieracze `-0.03`, Strażnicy Progu `+0.26`
- starting_item_bias: rifle, armor_piece, ammo, knife
- adaptation_bias: `enforcer`
- widoczny efekt: częściej trzyma pozycję, mniej chętnie się wycofuje, łatwiej przechodzi pod rozkazy

### 4. Kombinator
- trait_mods: greed `+0.18`, perception `+0.10`, discipline `-0.10`, social `+0.06`
- need_weight_mods: money `+0.34`, supply `+0.12`, job `-0.10`
- skill_tags: `trade`, `deception`, `route_memory`
- faction_bias: Zbieracze `+0.07`, Strażnicy Progu `-0.12`
- starting_item_bias: cash_equivalent, pistol, stash_map, contraband
- adaptation_bias: `smuggler_splitter`
- widoczny efekt: częściej ryzykuje dla zysku, omija checkpointy, dobrze nadaje się do późniejszych rozłamów frakcyjnych

### Reguły generacji NPC
- bazowy profil = frakcja + archetyp
- finalny NPC = bazowy profil + losowe odchylenie `[-0.06, +0.06]` dla 2-3 cech
- jedna cecha dominująca może mieć bonus `+0.10`, jeśli wspiera archetyp
- bias frakcyjny nie jest blokadą: NPC może trafić do "nieoptymalnej" frakcji, ale powinno to tworzyć tarcie i potencjał fabularny

### Minimalne przypadki testowe do vertical slice
1. Ratownik Zbieraczy reaguje na rannego sojusznika szybciej niż Warsztatowiec.
2. Ochroniarz Strażników Progu utrzymuje checkpoint dłużej niż Kombinator.
3. Kombinator częściej wybiera artefakt lub loot mimo zagrożenia.
4. Warsztatowiec częściej wraca z częściami do warsztatu niż do walki.

---

## Sprint plan — 4 tygodnie do pierwszego vertical slice

### Założenie
Jedna osoba lub mały zespół 1-2 devów. Celem nie jest content, tylko działający rdzeń grywalnego eksperymentu.

### Tydzień 1 — FPS sandbox + narzędzia bazowe
Cel tygodnia:
- mieć grywalny prototyp strzelania i zabijania NPC na małej mapie testowej

Zakres:
1. Skonfigurować projekt Godot 4 + GDExtension + SCons.
2. Zaimplementować `player_controller` z ruchem, sprintem, crouchem i kamerą.
3. Zaimplementować `weapon_base` dla jednej broni hitscan.
4. Zaimplementować `health_component` i `npc_agent_3d` z prostym combat loop.
5. Zbudować surową mapę testową z navmesh i osłonami.
6. Dodać prosty HUD: HP, ammo, crosshair.

Exit criteria:
- gracz może zabić NPC
- NPC potrafi wykryć gracza i odpowiedzieć ogniem
- build debug przechodzi stabilnie

### Tydzień 2 — Świat, lokacje i 2D model danych
Cel tygodnia:
- mieć małą strefę z punktami świata i działającym modelem offline NPC

Zakres:
1. Zaimplementować `SmartLocation` i `WorldGraph`.
2. Rozrysować 8 punktów vertical slice i ich połączenia.
3. Zaimplementować `NpcData`, `Squad`, `ALifeManager` bez eventów.
4. Dodać debug visualization grafu i squad goals.
5. Przygotować mikrostrefę do testu seamless transition.

Exit criteria:
- squad offline zmienia lokację w czasie
- debug HUD pokazuje aktualny target i stan squadu
- dane nie są oparte na node'ach 3D poza promieniem aktywacji

### Tydzień 3 — Transition 2D/3D + frakcje + archetypy
Cel tygodnia:
- mieć wiarygodne przełączanie symulacji i pierwsze różnice zachowań

Zakres:
1. Zaimplementować `transition_manager`.
2. Dodać dwie frakcje z macierzą relacji.
3. Dodać 4 archetypy backstory i generator NPC.
4. Spiąć backstory z decyzjami zachowania na poziomie prostych modyfikatorów.
5. Dodać overlay debugowy: faction, archetype, current state, 2D/3D mode.

Exit criteria:
- NPC przechodzi 2D→3D→2D bez utraty stanu
- zachowanie co najmniej 2 archetypów daje się odróżnić w praktyce
- dwa obozy frakcyjne funkcjonują równolegle na mapie

### Tydzień 4 — Event bus + emergent chain + anomalia
Cel tygodnia:
- dostarczyć pierwszy realny łańcuch emergentny

Zakres:
1. Zaimplementować `event_bus`, `cause_types`, `consequence_registry`.
2. Dodać 4 consequences: `investigate`, `retaliate`, `retreat`, `anomaly_harvest`.
3. Zaimplementować jedno `anomaly_field` i jeden artefakt.
4. Dodać prostego tradera i podstawowy loot z ciał.
5. Dodać komendy debugowe do wymuszania eventów.
6. Zbalansować pierwszy łańcuch między polem anomalii a checkpointem.

Exit criteria:
- w 10 minut testu pojawia się spontaniczny konflikt
- log pokazuje pełny łańcuch cause→consequence
- gracz może wpłynąć na wynik konfliktu
- artefakt stanowi realną nagrodę za ryzyko

### Ryzyka i cięcia zakresu
Jeśli sprint się nie domyka, ciąć w tej kolejności:
1. trader i ekonomię
2. mikrostrefę seamless
3. złożoność combat AI
4. liczbę archetypów z 4 do 2

Nie ciąć:
- transition 2D/3D
- event bus
- debug HUD
- dwie frakcje
bo to jest rdzeń tezy projektowej.

---

## Następny poziom szczegółu do wykonania
Gdy zacznie się implementacja, plan powinien zostać rozbity jeszcze na:
- checklistę klas i metod dla Fazy 0-1
- kolejność rejestracji klas w `register_types.cpp`
- format danych dla `NpcData`, `BackstoryProfile`, `FactionDefinition`, `SmartLocation`

5. NpcData + Squad + ALifeManager bez eventów
6. Transition 2D↔3D
7. Dwie frakcje i 4 archetypy backstory
8. Event Bus + 4 consequences
9. Pole anomalii + artefakt + trader
10. Debug HUD i narzędzia do wymuszania zdarzeń
11. Balans pierwszego emergent chain

### Narzędzia debugowe wymagane od początku
- overlay z ID NPC, frakcją, archetypem, aktualnym stanem i targetem
- podgląd grafu lokacji 2D
- przycisk / komenda do wymuszenia `DEATH`, `WOUND`, `SQUAD_ARRIVE`
- przełącznik wizualizacji promienia aktywacji 3D
- log ostatnich 20 eventów cause/consequence

### Kryteria akceptacji vertical slice
1. Gracz w 10 minut jest w stanie zobaczyć co najmniej jeden spontaniczny konflikt między frakcjami.
2. Co najmniej jeden NPC zmienia stan z 2D na 3D i z powrotem bez utraty ciągłości symulacji.
3. Backstory wpływa na zachowanie co najmniej w dwóch widocznych przypadkach.
4. Anomalia jest czytelna jako zagrożenie i nagroda.
5. Debug HUD pozwala wyjaśnić, dlaczego dane zdarzenie zaszło.

---

## Rekomendowana kolejność produkcyjna po vertical slice
1. Rozszerzyć system broni do docelowego gunplay.
2. Dodać potrzeby i cykl dobowy.
3. Wprowadzić terytorium i dłuższe łańcuchy konsekwencji.
4. Dopiero potem wejść w ekonomię pełnej skali i dynamiczne frakcje.


```
src/
├── player/       player_controller, health_component
├── weapon/       weapon_base, weapon_component, attachment_slot, weapon_stats
├── npc/          npc_agent_3d, hitbox
├── alife/        alife_manager, npc_data, squad, event_bus, cause_types,
│                 consequence_registry, alignment, personality, rate_limiter,
│                 needs_evaluator, territory_manager, faction_manager, faction_formation,
│                 transition_manager
├── world/        smart_location, world_graph, zone_manager, time_manager
├── economy/      item_registry, inventory, trader_logic
└── register_types.cpp/.h
```


---

## Godot 4 — klasy GDExtension dla Fazy 0-1 (ready-to-implement)

### Cel
Ustalić minimalny, konkretny zestaw klas i odpowiedzialności, żeby od razu wejść w implementację bez przepisywania architektury po tygodniu.

### Moduł `src/core/`

#### `game_bootstrap.h/.cpp` (`Node`)
Odpowiedzialność:
- punkt wejścia runtime po starcie sceny głównej
- inicjalizuje kolejność usług: `ALifeBridge`, `ZoneManager`, `DebugServices`
- ładuje profile debug/production

Public API (expose do Godot):
- `void set_debug_mode(bool enabled)`
- `bool is_debug_mode() const`
- `void start_new_game()`

#### `debug_services.h/.cpp` (`CanvasLayer` lub `Node`)
Odpowiedzialność:
- rejestr komend debugowych
- log ostatnich eventów systemowych
- bridge do debug HUD (GDScript UI)

Public API:
- `void push_log_line(const String &line)`
- `Array get_recent_logs() const`
- `void run_debug_command(const String &cmd)`

### Moduł `src/player/`

#### `player_controller.h/.cpp` (`CharacterBody3D`)
Odpowiedzialność:
- ruch gracza (walk/sprint/crouch/jump jeśli potrzebny)
- look input i podstawowa kamera first-person
- interakcja z aktywną bronią

Public API:
- `void set_input_enabled(bool enabled)`
- `bool is_input_enabled() const`
- `Vector3 get_velocity_local() const`
- `Transform3D get_camera_transform() const`

Sygnaly:
- `player_died`
- `player_took_damage(amount)`

#### `health_component.h/.cpp` (`Node` lub `RefCounted`)
Odpowiedzialność:
- hp, damage, heal, death state
- jednolity kontrakt obrażeń dla gracza i NPC

Public API:
- `void set_max_health(float value)`
- `float get_health() const`
- `void apply_damage(float amount, int source_id)`
- `void heal(float amount)`
- `bool is_dead() const`

Sygnaly:
- `damaged(amount, source_id)`
- `died(source_id)`

### Moduł `src/weapon/`

#### `weapon_base.h/.cpp` (`Node3D`)
Odpowiedzialność:
- strzał hitscan
- ammo i reload
- podstawowy recoil oraz spread
- odpalanie animacji fire/reload/inspect

Public API:
- `bool can_fire() const`
- `void trigger_fire(bool pressed)`
- `void trigger_reload()`
- `void trigger_inspect()`
- `int get_ammo_in_mag() const`
- `int get_ammo_reserve() const`
- `void set_weapon_config(const Ref<Resource> &config)`

Sygnaly:
- `fired(hit_success, target_id, hit_position)`
- `reloaded(new_mag, reserve)`
- `empty_trigger`

#### `weapon_config_resource.h/.cpp` (`Resource`)
Odpowiedzialność:
- dane balansu i ustawień broni
- strojenie bez rekompilacji

Pola (export):
- `weapon_id: StringName`
- `display_name: String`
- `damage_body: float`
- `damage_head_multiplier: float`
- `rpm: float`
- `spread_deg: float`
- `recoil_vertical: float`
- `recoil_horizontal: float`
- `mag_size: int`
- `reload_time_sec: float`
- `range_meters: float`
- `allowed_ammo_tags: PackedStringArray`
- `animation_set_id: StringName`

### Moduł `src/npc/`

#### `npc_agent_3d.h/.cpp` (`CharacterBody3D`)
Odpowiedzialność:
- online zachowanie NPC blisko gracza
- ruch po navmesh (`NavigationAgent3D`)
- podstawowe stany: idle, patrol, investigate, combat, flee
- integracja z `HealthComponent` i bronią

Public API:
- `void initialize_from_snapshot(const Dictionary &snapshot)`
- `Dictionary export_snapshot() const`
- `void set_target_position(const Vector3 &world_pos)`
- `void set_combat_target_node(Node3D *target)`
- `int get_npc_id() const`

Sygnaly:
- `npc_died(npc_id, source_id)`
- `npc_state_changed(npc_id, new_state)`

#### `hitbox_component.h/.cpp` (`Area3D`)
Odpowiedzialność:
- mnożniki trafień (head/body/limb)
- przekazanie obrażeń do `HealthComponent`


---

## Fazy 2-3 — plan wykonawczy dzień po dniu

### Zakres tych faz
- Faza 2: system broni (inspekcja, podstawowe attachmenty, degradacja, jam)
- Faza 3: świat i SmartLocations (strefy, graf lokacji, seamless przejścia)

Założenie: Faza 1 dowieziona i stabilna.

### Definicja ukończenia Fazy 2
1. Co najmniej 2 bronie działają na wspólnym `WeaponBase` + `WeaponConfigResource`.
2. Działają inspect, reload empty/normal i podstawowy jam/unjam.
3. Działa minimalny system attachmentów (2 sloty: optic + muzzle) z realnym wpływem na staty.
4. Działa degradacja durability i wpływ na niezawodność.

### Definicja ukończenia Fazy 3
1. Są 2 strefy: główna debug + mikrostrefa.
2. SmartLocationResource opisuje logiczne punkty świata.
3. WorldGraph działa i zwraca koszt przejścia między lokacjami.
4. ZoneManager robi przejście strefowe bez twardego ekranu ładowania.

---

## Sprint A (7 dni) — Faza 2: Broń

### Dzień A1
Cel:
- ustanowić finalny kontrakt danych broni

Taski:
1. Zamrozić schema `WeaponConfigResource` (pola, walidacje, domyślne wartości).
2. Dodać enum/tagi attachment slotów (`optic`, `muzzle`) i ammo tags.
3. Utworzyć 2 przykładowe zasoby broni (karabin + pistolet).
4. Ustawić logikę fallbacków, gdy asset audio/anim jest brakujący.

Weryfikacja:
- resource ładuje się bez błędów
- inspektor pokazuje wszystkie pola i waliduje zakresy

### Dzień A2
Cel:
- podpiąć inspect i rozdzielić reload normal/empty

Taski:
1. W `WeaponBase` dodać stany: `idle`, `firing`, `reload_normal`, `reload_empty`, `inspect`, `jammed`.
2. Dodać trigger inspect i blokady wejścia (np. brak fire podczas inspect).
3. Rozdzielić reload empty od normal przez stan magazynka.
4. Dodać sygnały do HUD (stan broni).

Weryfikacja:
- inspect i oba reloady odpalają poprawne animacje
- brak konfliktów stanów (np. inspect + reload jednocześnie)

### Dzień A3
Cel:
- wprowadzić degradację i jam

Taski:
1. Dodać durability runtime per egzemplarz broni.
2. Każdy strzał zmniejsza durability o `durability_loss_per_shot`.
3. Dodać bazowy wzór jam chance:
   - `jam_chance = jam_base_chance + (1 - durability_norm) * jam_wear_factor`
4. Dodać akcję `unjam` z krótką animacją.

Weryfikacja:
- w debug logu widać spadek durability
- przy niskiej trwałości występują jamy
- unjam przywraca możliwość strzału

### Dzień A4
Cel:
- dodać minimalny system attachmentów

Taski:
1. Dodać `WeaponAttachmentSlot` runtime dla `optic` i `muzzle`.
2. Wprowadzić `AttachmentResource` z modyfikatorami statów.
3. Podpiąć finalne staty broni: `final = base + sum(modifiers)`.
4. Dodać prosty UI debug do przepinania attachmentów.

Weryfikacja:
- podpięcie optyki/muzzle zmienia spread/recoil/range zgodnie z danymi
- zmiany widoczne natychmiast bez restartu sceny

### Dzień A5
Cel:
- balans i feeling broni

Taski:
1. Dostroić recoil, spread, rpm i damage dla 2 broni.
2. Dodać basic recoil recovery curve.
3. Dodać camera kick i subtelny feedback audio.
4. Test scenariuszy: krótkie starcie, długi spray, pusty mag, jam w walce.

Weryfikacja:
- obie bronie mają czytelną tożsamość
- jam i degradacja są odczuwalne, ale nie frustrujące

### Dzień A6
Cel:
- integracja z NPC i lootem

Taski:
1. NPC używa tej samej logiki `WeaponBase` (nie osobnego skrótu).
2. Broń NPC zachowuje trwałość i stan magazynka.
3. Po śmierci NPC dropi egzemplarz z aktualnym durability.
4. Dodać sanity-check dla sync stanu broni w snapshotach.

Weryfikacja:
- broń przejęta po NPC zachowuje stan zużycia
- brak desync ammo po przejęciu broni

### Dzień A7
Cel:
- stabilizacja Fazy 2

Taski:
1. Testy regresji stanów broni (kolejki akcji, przerwanie animacji, edge-cases).
2. Naprawy krytyczne i drobny refactor tylko lokalnie.
3. Aktualizacja debug overlay o durability/jam state.

Weryfikacja:
- 30 min testu bez softlocków stanu broni
- brak crashy przy szybkiej sekwencji inputów

---

## Sprint B (7 dni) — Faza 3: Świat i SmartLocations

### Dzień B1
Cel:
- przygotować zasoby świata i schema stref

Taski:
1. Zamrozić schema `SmartLocationResource` i walidacje.
2. Utworzyć zasób listy lokacji dla strefy głównej (8 punktów).
3. Dodać typy lokacji: camp, trader, checkpoint, ruins, anomaly.
4. Wprowadzić narzędzie debug do podglądu lokacji z Resource.

Weryfikacja:
- wszystkie lokacje ładują się z resource bez null reference
- walidacje wykrywają błędne neighbor/travel costs

### Dzień B2
Cel:
- zbudować `WorldGraph`

Taski:
1. Implementacja runtime grafu z lokacji resource.
2. API: pobierz sąsiadów, koszt przejścia, najbliższą lokację dla pozycji 3D.
3. Dodać debug render krawędzi i ID w świecie.
4. Dodać szybkie testy poprawności (spójność krawędzi, brak osieroconych węzłów).

Weryfikacja:
- graf poprawnie zwraca trasy dla prostych zapytań
- debug render pokazuje zgodne połączenia

### Dzień B3
Cel:
- osadzić strefę główną jako debug-friendly vertical slice map

Taski:
1. Uporządkować scenę strefy głównej z markerami anchor dla SmartLocations.
2. Dodać navmesh i markerowe punkty cover/patrol.
3. Przypisać `world_anchor_node` dla każdej lokacji.
4. Test line-of-sight dla kluczowych punktów walki.

Weryfikacja:
- wszystkie lokacje mają poprawne anchory
- NPC i gracz poruszają się po navmesh bez krytycznych blokad

### Dzień B4
Cel:
- dodać mikrostrefę i przejście

Taski:
1. Utworzyć mikrostrefę z 2-3 lokacjami pomocniczymi.
2. Zdefiniować gate/punkt przejścia między strefami.
3. Dodać sygnały przejścia i podstawowy preload.
4. Zapewnić zachowanie pozycji gracza przy wejściu/wyjściu.

Weryfikacja:
- przejście działa płynnie
- brak twardego freeze i brak utraty inputu po przejściu

### Dzień B5
Cel:
- ustabilizować `ZoneManager`

Taski:
1. Kolejka operacji load/unload i blokada wielokrotnych requestów.
2. Bezpieczny timeout/fallback, gdy strefa nie ładuje się poprawnie.
3. Podpiąć eventy do debug HUD (`transition_started/finished`).
4. Zredukować piki CPU/GPU przy przejściu (prewarm minimalnych assetów).

Weryfikacja:
- 20 przejść strefowych pod rząd bez błędu
- log pokazuje pełny cykl transition eventów

### Dzień B6
Cel:
- integracja Fazy 3 z ALife runtime (na poziomie lokacji)

Taski:
1. ALife runtime korzysta z `location_id` i `WorldGraph`, nie z pozycji 3D jako źródła strategicznego.
2. Snapshot NPC zawiera `current_location_id` i `target_location_id`.
3. Dodać mapowanie lokacja logiczna -> anchor 3D dla wejścia online.
4. Test: squad zmienia lokacje logicznie, a online NPC pojawia się przy poprawnym anchorze.

Weryfikacja:
- zgodność stanu logicznego i wizualnego
- brak teleportów do złej strefy po transition

### Dzień B7
Cel:
- stabilizacja i gotowość do Fazy 4-5

Taski:
1. Regresja przejść strefowych + grafu + anchorów.
2. Naprawa krytycznych edge-case'ów (brak anchora, niedostępny neighbor, zerowy koszt).
3. Uporządkowanie komunikatów błędów pod debug workflow.
4. Finalny checklist handoff do Fazy ALife event-driven.

Weryfikacja:
- świat ma stabilny fundament danych i przejść
- brak blockerów dla wdrażania event bus i transition managera pełnej skali

---

## Krytyczne zależności między Fazami 2 i 3

1. Faza 2 może iść równolegle z większością Fazy 3.
2. Punkt styku: Dzień A6 (integracja broni z NPC) wymaga stabilnego anchor/navmesh z B3.
3. ALife integracja (B6) powinna ruszyć dopiero po stabilnym B2-B5.
4. Nie łączyć finalnego balansu broni z niestabilną mapą strefową, bo metryki będą fałszywe.

---

## Metryki jakości po Fazach 2-3

### Broń
- czas do pierwszego strzału od inputu: cel < 80 ms
- softlock stanów broni: 0 na 30 min testu
- jam frequency przy durability > 80%: niska (tuningowa)
- jam frequency przy durability < 30%: wyraźna, ale grywalna

### Świat
- czas przejścia między strefami: bez twardego stop klatki > 300 ms
- nieudane transition requesty: 0 w serii 20 przejść
- błędne mapowanie SmartLocation->anchor: 0
- osierocone węzły grafu: 0

---

## Scope guard (żeby nie rozlać produkcji)

W Fazach 2-3 NIE robić:
- pełnego systemu attachmentów (więcej niż 2 sloty)
- zaawansowanej balistyki (penetracja, ricochet, fizyczne pociski)
- proceduralnego generatora stref
- pełnego UI inventory
- dynamicznego tworzenia frakcji

W Fazach 2-3 MUSI powstać:
- stabilny kontrakt danych broni
- stabilny kontrakt danych świata
- działające przejścia strefowe
- gotowy fundament pod event-driven ALife

Public API:
- `void set_damage_multiplier(float value)`
- `float get_damage_multiplier() const`

### Moduł `src/world/`

#### `zone_manager.h/.cpp` (`Node`)
Odpowiedzialność:
- ładowanie/unload stref
- utrzymanie aktywnej strefy i mikrostref sąsiednich
- emitowanie sygnałów przejścia strefowego

Public API:
- `void load_initial_zone(const String &zone_scene_path)`
- `void request_zone_transition(const StringName &gate_id)`
- `StringName get_current_zone_id() const`

Sygnaly:
- `zone_loaded(zone_id)`
- `zone_unloaded(zone_id)`
- `zone_transition_started(from_id, to_id)`
- `zone_transition_finished(from_id, to_id)`

#### `smart_location_resource.h/.cpp` (`Resource`)
Pola (export):
- `location_id: int`
- `zone_id: StringName`
- `location_type: int` (camp/outpost/trader/anomaly/checkpoint)
- `world_anchor_node: NodePath`
- `max_population: int`
- `faction_owner_id: int`
- `cover_markers: Array[NodePath]`
- `patrol_markers: Array[NodePath]`
- `neighbors: PackedInt32Array`

### Moduł `src/alife/` (bridge + runtime dla Fazy 0-1)

#### `alife_bridge.h/.cpp` (`Node`)
Odpowiedzialność:
- most między SceneTree i czystym runtime
- tick offline symulacji w stałym interwale
- API dla debug UI

Public API:
- `void set_simulation_enabled(bool enabled)`
- `bool is_simulation_enabled() const`
- `void force_tick(int ticks)`
- `Array get_online_npcs() const`
- `Array get_offline_npcs() const`

Sygnaly:
- `alife_tick_completed(game_time_sec)`
- `alife_event_emitted(event_type, payload)`

#### `transition_manager.h/.cpp` (`Node`)
Odpowiedzialność:
- 2D↔3D activation budget
- histereza promieni i kolejka spawn/despawn

Public API:
- `void set_online_radius(float meters)`
- `void set_offline_radius(float meters)`
- `void set_spawn_budget_per_frame(int count)`

#### `npc_data.h` (czyste C++)
Pola minimum:
- `npc_id`
- `faction_id`
- `backstory_archetype_id`
- `health`
- `current_location_id`
- `squad_id`
- `flags_online`
- `current_goal`
- `weapon_id`

#### `squad.h/.cpp` (czyste C++)
Pola minimum:
- `squad_id`
- `member_ids`
- `state`
- `source_location_id`
- `target_location_id`
- `eta_game_time`

### Moduł `src/register_types.*`

Kolejność rejestracji na start:
1. Resource configs (`WeaponConfigResource`, `SmartLocationResource`, później `FactionDefinitionResource`, `BackstoryArchetypeResource`)
2. Core services (`GameBootstrap`, `DebugServices`, `ALifeBridge`, `ZoneManager`, `TransitionManager`)
3. Gameplay (`HealthComponent`, `HitboxComponent`, `WeaponBase`, `NpcAgent3D`, `PlayerController`)

Powód:
- edytor ma znać Resource zanim sceny zaczną ich używać
- menedżery i bridge muszą być gotowe, zanim gameplay zacznie emitować sygnały

---

## Schematy danych `Resource` — Godot 4 Inspector-first

### `FactionDefinitionResource`
Cel:
- trzyma pełną definicję frakcji i domyślne parametry zachowania

Pola:
- `faction_id: int`
- `faction_key: StringName`
- `display_name: String`
- `ui_color: Color`
- `description_short: String`
- `aggression: float`
- `greed: float`
- `survival: float`
- `perception: float`
- `territory: float`
- `discipline: float`
- `social: float`
- `order_axis: float`
- `anomaly_affinity: float`
- `violence_acceptance: float`
- `default_relationships: Dictionary` (`other_faction_id -> float`)
- `preferred_consequences: PackedStringArray`
- `avoided_consequences: PackedStringArray`
- `starting_loadout_tags: PackedStringArray`

Walidacje:
- cechy clamp do `[0.0, 1.0]`
- wymagane unikalne `faction_id` i `faction_key`

### `BackstoryArchetypeResource`
Cel:
- preset postaci używany przez generator NPC

Pola:
- `archetype_id: int`
- `archetype_key: StringName`
- `display_name: String`
- `origin_role: StringName`
- `mental_state: StringName`
- `bond_pattern: StringName`
- `trait_mods: Dictionary` (`trait_key -> float`)
- `need_weight_mods: Dictionary` (`need_key -> float`)
- `skill_tags: PackedStringArray`
- `faction_bias: Dictionary` (`faction_id -> float`)
- `starting_item_bias: PackedStringArray`
- `adaptation_bias: StringName`

Walidacje:
- modyfikatory trait i potrzeb w bezpiecznym zakresie `[-1.0, +1.0]`
- `archetype_id` i `archetype_key` unikalne

### `WeaponConfigResource`
Cel:
- parametry pierwszego gunplay i późniejsze rozszerzenie pod attachmenty

Pola:
- `weapon_id: StringName`
- `display_name: String`
- `weapon_class: StringName` (rifle/smg/pistol/shotgun)
- `damage_body: float`
- `damage_head_multiplier: float`
- `rpm: float`
- `spread_deg: float`
- `recoil_vertical: float`
- `recoil_horizontal: float`
- `mag_size: int`
- `reload_time_sec: float`
- `range_meters: float`
- `durability_loss_per_shot: float`
- `jam_base_chance: float`
- `allowed_attachment_slots: PackedStringArray`
- `allowed_ammo_tags: PackedStringArray`
- `animation_set_id: StringName`
- `audio_fire: AudioStream`
- `audio_reload: AudioStream`

Walidacje:
- wszystkie wartości bojowe dodatnie
- `mag_size > 0`
- `rpm` i `reload_time_sec` w sensownych zakresach

### `SmartLocationResource`
Cel:
- logiczny punkt świata dla ALife i nawigacji strategicznej

Pola:
- `location_id: int`
- `location_key: StringName`
- `zone_id: StringName`
- `location_type: StringName` (camp, trader, checkpoint, anomaly, ruins)
- `world_anchor_node: NodePath`
- `max_population: int`
- `faction_owner_id: int`
- `danger_level: float`
- `loot_tier: int`
- `supports_campfire: bool`
- `supports_trade: bool`
- `supports_medical: bool`
- `neighbor_location_ids: PackedInt32Array`
- `travel_costs: PackedFloat32Array` (indeksowo zgodne z neighbor list)

Walidacje:
- `location_id` unikalne w obrębie świata
- długość `neighbor_location_ids` == długość `travel_costs`
- brak ujemnych kosztów przejścia

---

## Faza 0-1 — checklista implementacyjna (dzień po dniu)

### Dzień 1
- uruchomić bazę GDExtension i SCons
- dodać `register_types.*`
- zarejestrować `GameBootstrap`
- postawić `main.tscn` z `GameBootstrap` i pustym HUD

### Dzień 2
- dodać `PlayerController`
- dodać input map (move/look/fire/reload/crouch/sprint)
- podstawowy movement i kamera

### Dzień 3
- dodać `HealthComponent`
- dodać `WeaponConfigResource` + `WeaponBase`
- podpiąć fire/reload + prosty hitscan

### Dzień 4
- dodać `NpcAgent3D` + `HitboxComponent`
- prosty detection + response fire
- pierwsza arena testowa z navmesh

### Dzień 5
- dodać `DebugServices` i log debugowy
- dopiąć HUD: HP, ammo, liczba NPC online
- testy ręczne i naprawy błędów Fazy 1

### Dzień 6-7 (bufor)
- stabilizacja i tuning feelu broni
- poprawa podstawowego AI i cover behavior
- przygotowanie pod wejście w Fazy 2-3

Kryterium końca Fazy 1:
- stabilne 60 FPS na małej mapie testowej
- gracz może wejść do walki 1v3 i ją wygrać/przegrać bez błędów krytycznych
- debug log pokazuje obrażenia, śmierci i najważniejsze przejścia stanu NPC
