# ywli-dev

Plugin `ywli-dev` iz marketplace-a `ywli-skills` (YouWillLikeIT): alati za SilverStripe razvoj.
Prvi skill je `ss-version-aware`.

## Šta radi `ss-version-aware`

- Prepoznaje tačnu SilverStripe verziju projekta (SS3–SS6) iz `composer.lock`, `vendor/composer/installed.json`, `composer.json` ili `framework/` (SS3 bez Composera) i režim: `normal`, `upgrade` (lock i constraint se razlikuju, ili je `vendor/` zastario) ili `compat` (modul sa `^5 || ^6`).
- Učitava provjerenu API referencu za tu verziju (`references/ss3.md` … `ss6.md`) i sve što referenca ne pokriva provjerava u `vendor/` prije upotrebe. Nikad ne miješa API-je različitih verzija.
- Upisuje kratak blok (≤ 15 linija) u lokalni `CLAUDE.md` ili `CLAUDE.local.md`, koji ne ide u git. SessionStart hook ga osvježava kad se promijeni `composer.lock`.
- Vodi upgrade 4→5 i 5→6 kroz checklistu koja se može ponovo skenirati (`scan-upgrade.sh`).

## Preduslovi

- Samo `git` i `bash` (uz standardne `awk`, `sed`, `grep`). PHP, `jq` i python na hostu nisu potrebni; DDEV nije obavezan.
- Podržano: macOS (bash 3.2, BSD alati) i Linux/WSL (GNU alati). Nativni Windows (cmd/PowerShell bez WSL-a) nije podržan.

## Instalacija

```
/plugin marketplace add you-will-like-it/claude-skills
/plugin install ywli-dev@ywli-skills
```

- Repo je privatan: `git` na mašini mora imati pristup (SSH ključ ili credential helper za GitHub).
- Automatsko ažuriranje u pozadini je za ovaj marketplace isključeno dok ga ne uključiš (`/plugin` → Marketplaces → Enable auto-update). Za privatni repo pozadinska provjera radi samo preko git kredencijala: SSH ključ u `ssh-agent`-u ili sačuvani HTTPS kredencijal (`gh auth login`, pa `gh auth setup-git`). Token u okruženju sam po sebi nije dovoljan. Opcionalno `CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1` zadržava postojeću kopiju ako provjera ne uspije.
- Ručno ažuriranje: `/plugin marketplace update ywli-skills`, pa `claude plugin update ywli-dev@ywli-skills` (ili `/reload-plugins` / restart sesije).
- Verzija je fiksirana u `plugin.json` (`0.1.0`): novi commitovi stižu do korisnika tek kad se verzija podigne.

## Uključivanje u projektu (init)

U projektu reci Claudeu **"postavi ss-version-aware"**. Ili ručno, iz korijena projekta:

```
bash <plugin>/scripts/block.sh show   # samo prikaže blok, ništa ne piše
bash <plugin>/scripts/block.sh init   # upiše blok
```

`<plugin>` je instalirani direktorij plugina (`${CLAUDE_PLUGIN_ROOT}` unutar Claude Code).

- **Koji fajl:** `CLAUDE.md` ako nije u gitu (ili ne postoji); `CLAUDE.local.md` ako je `CLAUDE.md` praćen u gitu. Praćeni fajlovi se nikad ne mijenjaju (izlaz 3 ako su oba praćena).
- **Git:** korišteni fajl se dodaje u `$(git rev-parse --git-path info/exclude)`, a ne u `.gitignore`. `git status` ostaje čist. Izvan gita init ispisuje `NOTE=no-git` i ništa se ne isključuje.
- **AGENTS.md:** ako init **pravi novi** `CLAUDE.md`, a projekat ima `AGENTS.md` (ili `.claude/AGENTS.md`) i nema `CLAUDE.md`, `.claude/CLAUDE.md` ni `CLAUDE.local.md`, prva linija novog fajla je `@AGENTS.md` (odnosno `@.claude/AGENTS.md`). Bez toga bi Claude Code prestao čitati `AGENTS.md`. Init tada ispisuje `NOTE=agents-md-imported`. Postojeći fajl nikad ne dobija import.
- **⚠ linija:** kad hook vidi promjenu majora ili režima, upisuje `⚠ Verzija promijenjena (A → B) — pokreni ss-version-aware.` u sam blok i vraća poruku kroz `additionalContext`. VS Code ekstenzija trenutno ne isporučuje `additionalContext` iz plugin SessionStart hooka, pa je ⚠ linija u bloku rezervni kanal: vidi se pri sljedećem učitavanju memorije. Skill obavijesti korisnika i pokrene `block.sh ack`, koji uklanja liniju.

## Upgrade

```
bash <plugin>/scripts/scan-upgrade.sh --from 5 --to 6 [--dir <projekat>] [--checklist <putanja>] [--no-exclude]
```

- `--from`/`--to`: majori (npr. `4 6`). `--dir`: korijen projekta (zadano: trenutni direktorij). `--checklist`: druga putanja (zadano: `.claude/ss-upgrade-checklist.md`). `--no-exclude`: ne dodaje checklistu u `info/exclude` (ako je želiš commitati na privatnom projektu).
- Izlaz: `CHECKLIST=<putanja>`, `MANUAL=<n>` (neoznačene stavke za ručni pregled, bez grep obrasca) i `OPEN=<n>` (otvorene stavke iz obrazaca, uvijek zadnja linija).
- Exit kod: `0` = nema otvorenih stavki, `1` = ima otvorenih stavki, `2` = greška u upotrebi, mapi ili regexu. `MANUAL` ne utiče na exit kod.
- Svaka stavka ima ID mape (`M56-015`), datoteku i liniju te pronađeni kod. Stavka se zatvara (`[x]`) tek kad je ponovni scan više ne nađe. Ručne stavke označavaš sam; oznaka preživljava ponovni scan.
- Checklista se regeneriše pri svakom scanu: ne piši bilješke u nju.
- 4→6 je jedna checklista u dvije faze. Faza 5→6 je zaključana dok lock (ili instalirani `vendor/`) ne pokaže 5.x.
- Dok checklista ima neoznačenih stavki, blok prikazuje `Upgrade checklista: N otvorenih stavki (+M za ručni pregled)`.
- Rector: mapa 5→6 u sekciji `## Rector` navodi `wernerkrauss/silverstripe-rector` kao opcioni prvi prolaz; mapa 4→5 nema Rector sekciju. Skill ga nikad ne instalira bez pristanka.
- Mape 3→4 nema: upgrade sa SS3 nije pokriven.
- Skenirani direktoriji isključuju `vendor`, `node_modules`, `_resources`, `resources`, `.git`, `lang`, `.claude`, `silverstripe-cache` i `.ddev`.

## Deinstalacija

1. `/plugin uninstall ywli-dev@ywli-skills`
2. U svakom projektu: obriši blok između `<!-- ss-version-aware:start -->` i `<!-- ss-version-aware:end -->` u `CLAUDE.md` / `CLAUDE.local.md`. Ako je init napravio taj fajl (uključujući `@AGENTS.md` import), obriši cijeli fajl.
3. Iz `$(git rev-parse --git-path info/exclude)` ukloni linije `/CLAUDE.md`, `/CLAUDE.local.md` i `/.claude/ss-upgrade-checklist.md` (u poddirektoriju repoa s prefiksom, npr. `/sub/CLAUDE.md`).
4. Obriši `.claude/ss-upgrade-checklist.md`, ako postoji.

## Testovi

```
bash tests/ywli-dev/run.sh
```

- Na macOS-u pokreni bez izmjena: sistemski `/bin/bash` je 3.2, pa je to test za bash 3.2 i BSD alate. Ako je `bash` u PATH-u Homebrew bash 5, pokreni `/bin/bash tests/ywli-dev/run.sh`.
- `SSVA_BASH=/putanja/do/bash bash tests/ywli-dev/run.sh` pokreće testove i sve skripte plugina pod tim bashom. Zadano je bash koji pokreće `run.sh`.
- `test_skill.sh` pokreće i `claude plugin validate`, ako je `claude` CLI dostupan (`SSVA_SKIP_PLUGIN_VALIDATE=1` ga preskače).

## Release gate

Reference čekaju Đorđev pregled prije stvarne upotrebe. Broj stavki (bullet + red tabele, odnosno `### M..` unosi u mapama):

| Fajl | Stavki |
|---|---|
| `references/ss3.md` | 97 |
| `references/ss4.md` | 92 |
| `references/ss5.md` | 87 |
| `references/ss6.md` | 88 |
| `references/migrations/4-to-5.md` | 100 unosa (80 sa grep obrascem) |
| `references/migrations/5-to-6.md` | 123 unosa (99 sa grep obrascem) |

## Poznata ograničenja

- Markeri bloka unutar code fencea u `CLAUDE.md` tretiraju se kao pravi blok.
- Ako fajl ima više blokova, ažurira se samo prvi potpuni; ostali ostaju netaknuti.
- Neki grep obrasci ne nalaze potpise razbijene u više linija (npr. parametri metode u novim redovima); takve slučajeve pokriva ručni pregled i self-check.
- Zvanična dokumentacija ima poznate greške (npr. docs-5 tvrdi da `or`/`and` rade u template uslovima); reference ih navode i prednost imaju izvorni kod i reference.
- Detekcija pretpostavlja `composer.json`/`composer.lock` formatirane kao što ih piše Composer (jedan ključ po liniji).

## Changelog

- 0.1.0 — prvi skill `ss-version-aware`: detekcija SS3–SS6, blok u `CLAUDE.md`/`CLAUDE.local.md`, SessionStart hook, reference ss3–ss6, mape 4→5 (100) i 5→6 (123) sa skenerom za upgrade.
