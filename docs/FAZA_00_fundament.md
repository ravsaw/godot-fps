# Faza 0 — Fundament

> **Cel:** Działające środowisko developerskie, ustalone konwencje projektu i gotowy pipeline build.

---

## 📋 Zadania

| # | Zadanie | Trudność | Czas |
|---|---------|----------|------|
| 0.1 | Instalacja Godot 4, SCons, kompilator C++ (MSVC/GCC/Clang) | 🟢 | 1 dzień |
| 0.2 | Konfiguracja GDExtension — szablon projektu C++ + hot-reload | 🟡 | 2–3 dni |
| 0.3 | Struktura folderów projektu (scenes, assets, scripts, extensions) | 🟢 | 1 dzień |
| 0.4 | Git + `.gitignore` dla Godot + C++ | 🟢 | 1 dzień |

---

## 🔍 Opis zadań

### 0.1 — Instalacja środowiska

Wymagane narzędzia:

- **Godot 4** (wersja `4.x` — pobierz z [godotengine.org](https://godotengine.org/download))
- **SCons** — system budowania używany przez GDExtension (`pip install scons`)
- **Kompilator C++:**
  - Windows: MSVC (Visual Studio 2022 Build Tools) lub MinGW-w64
  - Linux: GCC lub Clang (`sudo apt install build-essential`)
  - macOS: Clang przez Xcode Command Line Tools

Weryfikacja:
```bash
godot --version
scons --version
g++ --version   # lub cl (MSVC) / clang++
```

---

### 0.2 — Konfiguracja GDExtension

GDExtension pozwala pisać klasy Godot w czystym C++ bez modyfikowania silnika.

**Kroki:**
1. Sklonuj `godot-cpp` (bindingi C++):
   ```bash
   git submodule add https://github.com/godotengine/godot-cpp.git extensions/godot-cpp
   cd extensions/godot-cpp
   git checkout godot-4.x  # dopasuj do wersji silnika
   ```

2. Skompiluj bindingi:
   ```bash
   cd extensions/godot-cpp
   scons platform=windows target=template_debug  # lub linux/macos
   ```

3. Minimalny plik `SConstruct` dla wtyczki:
   ```python
   env = SConscript("extensions/godot-cpp/SConstruct")
   env.Append(CPPPATH=["extensions/src/"])
   sources = Glob("extensions/src/*.cpp")
   library = env.SharedLibrary("bin/libgodotfps{}{}".format(
       env["suffix"], env["SHLIBSUFFIX"]
   ), source=sources)
   Default(library)
   ```

4. Plik `.gdextension` (np. `bin/godotfps.gdextension`):
   ```ini
   [configuration]
   entry_symbol = "godotfps_library_init"
   compatibility_minimum = "4.1"

   [libraries]
   windows.debug.x86_64 = "res://bin/libgodotfps.windows.template_debug.x86_64.dll"
   linux.debug.x86_64   = "res://bin/libgodotfps.linux.template_debug.x86_64.so"
   ```

**Hot-reload:** Godot automatycznie przeładuje wtyczkę po ponownym skompilowaniu `.dll`/`.so` bez restartu edytora (dostępne od Godot 4.2).

---

### 0.3 — Struktura folderów projektu

```
godot-fps/
├── project.godot              — plik projektu Godot
├── README.md
├── docs/                      — dokumentacja faz
│
├── scenes/
│   ├── world/                 — sceny poziomów i terenu
│   ├── player/                — scena gracza (CharacterBody3D)
│   ├── npc/                   — sceny NPC
│   ├── weapons/               — sceny broni
│   └── ui/                    — interfejs użytkownika
│
├── assets/
│   ├── models/                — pliki GLTF/GLB
│   ├── textures/              — tekstury (minimalne — flat shading)
│   ├── audio/                 — dźwięki broni, kroków, otoczenia
│   └── fonts/                 — czcionki UI
│
├── scripts/
│   ├── player/                — GDScript kontrolera gracza
│   ├── npc/                   — GDScript zachowań NPC
│   ├── weapons/               — GDScript systemu broni
│   ├── world/                 — GDScript regionów, POI
│   └── autoload/              — singletony (GameManager, etc.)
│
├── extensions/
│   ├── godot-cpp/             — submodule (bindingi C++)
│   └── src/                   — kod źródłowy C++ wtyczek
│
└── bin/                       — skompilowane .dll/.so (gitignore)
```

---

### 0.4 — Git + `.gitignore`

Przykładowy minimalny `.gitignore` dla Godot 4 + C++:

```gitignore
# Godot
.godot/
*.translation
export_presets.cfg

# Godot C++ GDExtension — skompilowane binaria
bin/*.dll
bin/*.so
bin/*.dylib

# SCons — pliki tymczasowe buildu
.sconsign.dblite
extensions/godot-cpp/bin/
extensions/godot-cpp/.sconsign.dblite

# C++ — pliki obiektowe
*.o
*.obj
*.a
*.lib

# OS
.DS_Store
Thumbs.db

# Edytory
.vscode/
.idea/
*.swp
```

---

## ✅ Rezultat fazy

- [ ] `godot --version` wypisuje wersję 4.x
- [ ] `scons` kompiluje wtyczkę C++ bez błędów
- [ ] Godot otwiera projekt i widzi klasę zdefiniowaną w C++
- [ ] Struktura folderów założona w repozytorium
- [ ] `.gitignore` wyklucza pliki binarne i tymczasowe
- [ ] Hot-reload działa — zmiana w C++ ładuje się bez restartu Godota
