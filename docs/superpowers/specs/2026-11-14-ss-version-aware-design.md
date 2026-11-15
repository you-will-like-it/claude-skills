# ss-version-aware — dizajn

Datum: 2026-11-14 · Status: za odobrenje

## 1. Namjera i zašto

Claude u VS Code-u (Claude Code plugin) redovno miješa SilverStripe API između verzija, najčešće SS5 i SS6. Đorđe radi paralelno na projektima SS3, SS4, SS5 i SS6 (firma: Bitbucket, macOS; privatno: Git, Windows/WSL; oba DDEV), i povremeno radi upgrade (najčešće 5→6, ponekad 4→6, rijetko 3→6).

Cilj: Claude u svakoj sesiji tačno zna koja je verzija projekta i piše kod isključivo za nju; tokom upgrade-a zna da je kod u prelaznom stanju i vodi migraciju kroz checklistu.

## 2. Ciljevi, ne-ciljevi, anti-ciljevi

**Ciljevi**
- Automatska detekcija verzije SilverStripe-a (i ključnih modula) po projektu.
- Kratak, uvijek-učitan kontekst u projektu (blok u `CLAUDE.md`) + teška referenca u skill-u.
- Reference API-ja za SS3, SS4, SS5, SS6 — sve jednako provjerene (Đorđe piše novi kod u svim verzijama).
- Upgrade režim: mape `4→5` i `5→6` kao lanac, checklista mjesta za izmjenu, perzistentna kroz sesije.
- Radi identično na macOS-u i Windows/WSL-u.

**Ne-ciljevi (v1)**
- Mapa `3→4` (dolazi kasnije kao zaseban posao, uz analizu konkretnog velikog SS3 projekta; arhitektura mora dozvoliti da se doda kao još jedna karika lanca).
- Automatsko prepravljanje koda (skill predlaže i vodi; izmjene radi Claude u normalnom toku, uz pregled).
- Deploy, zaštita lokalnih fajlova, Trello/Mantis integracija — zasebni budući skill-ovi.

**Anti-ciljevi (neuspjeh i ako "radi")**
- Skill ili generisani fajlovi završe u firminom Bitbucket repou ili smetaju kolegama (MAMP, bez Claude-a).
- Reference sadrže izmišljene/neprovjerene API tvrdnje — tada skill pogoršava problem koji rješava.
- Blok u `CLAUDE.md` naraste i troši kontekst u svakoj sesiji.
- Zastarjeli blok (npr. nakon `composer update` na novu major verziju) tiho navodi pogrešnu verziju.

## 3. Ograničenja

- Okruženje: Claude Code (VS Code ekstenzija) na macOS i u WSL-u (VS Code Remote-WSL — Claude Code, hookovi i skripte rade unutar Linuxa). Jedna bash skripta za oba sistema; mora raditi i s macOS-ovim bash 3.2. Projekti u DDEV-u. PHP na hostu nije garantovan (macOS ga nema po defaultu) — detekcija ne smije zavisiti od PHP/jq/python na hostu. Dozvoljen fallback kroz `ddev exec`.
- Firmeni repoi su dijeljeni: ništa iz ovog skill-a ne smije mijenjati praćene (tracked) fajlove niti `.gitignore`.
- Izvor istine za reference: zvanična dokumentacija (docs.silverstripe.org changelogovi i upgrade vodiči, GitHub repoi silverstripe/*), te lokalni `vendor/` projekta. Ne memorija modela.

## 4. Pristupi (razmatrani)

| | Pristup | Trade-off |
|---|---|---|
| A | Samo skill, detekcija svaki put, bez fajla u projektu | Ništa u repou; ali kad se skill ne aktivira (usputne izmjene), problem ostaje |
| B | Skill generiše pun `CLAUDE.md` s cijelom referencom | Uvijek u kontekstu; ali velik, troši kontekst, reference se ažuriraju po projektu |
| **C** | **Hibrid: kratak blok u `CLAUDE.md` + teška referenca u skill-u** | **Izabrano.** Verzija uvijek u kontekstu, referenca na jednom mjestu |

Odabrao: Đorđe — C. Razlog: miješanje verzija se dešava baš kad se skill ne aktivira; kratak uvijek-učitan blok to pokriva bez troška konteksta.

Upgrade mape: lanac koraka (`4→5`, `5→6`) umjesto direktnih (`4→6`) — manje i tačnije mape, i projekat se može pokrenuti/testirati između koraka. (Đorđe se složio.)

## 5. Šta je odlučeno

### 5.1 Distribucija
Privatni Git repo kao Claude Code plugin (marketplace u istom repou), instalacija/ažuriranje istom komandom na oba računara. Ovaj skill je prvi u pluginu; budući skill-ovi (deploy, zaštita lokalnih fajlova…) idu u isti plugin. *(Moj prijedlog, Đorđe prihvatio uz obim.)*

### 5.2 Detekcija
- Verzija frameworka iz `composer.lock` (`silverstripe/framework`), plus verzije ključnih modula (minimalno: `silverstripe/cms`, `silverstripe/admin`, `silverstripe/assets`, `silverstripe/versioned`, `dnadesign/silverstripe-elemental`, `tractorcow/silverstripe-fluent` ako postoje).
- SS3 (sa ili bez Composera) mora se pouzdano prepoznati: `composer.lock` ako postoji, inače `framework/` folder u rootu i verzija iz njegovih fajlova; testirati na stvarnom SS3 projektu iz firme.
- Dodatno se detektuje: build alat (`vite.config.*` / `webpack.config.*`, `package.json`), DDEV (`.ddev/config.yaml`, PHP verzija iz njega).
- Monorepo/modul bez projekta: ako je root sam modul (type `silverstripe-vendormodule`), verzija se čita iz `require` ograničenja u njegovom `composer.json`.

### 5.3 Upgrade režim
Ulazi se kad:
- major verzija iz `composer.json` ograničenja ≠ major iz `composer.lock`, ili
- `vendor/` nije usklađen s lock-om, ili
- korisnik kaže ("radim upgrade 5→6").

U upgrade režimu:
- Blok u `CLAUDE.md` navodi izvor → cilj i pravilo: novi kod isključivo za cilj; postojeći mijenjati prema migracijskoj mapi.
- Skill na zahtjev skenira `app/`, `src/`, `themes/`, vlastite module (ne `vendor/`) i generiše checklistu (fajl:linija, stara upotreba, zamjena, link na izvor u mapi).
- Za 4→6: jedna checklista s dvije faze (4→5, pa 5→6); druga faza se otključava kad lock pokaže 5.x.
- Izlaz iz režima: lock pokazuje ciljnu verziju i checklista nema otvorenih stavki → blok se vraća u normalni režim.
- Ako postoje održavana Rector pravila za dati korak, skill ih predlaže kao prvi prolaz; checklista pokriva ostatak.

### 5.4 Fajlovi u projektu
- Blok u `CLAUDE.md` omeđen markerima (`<!-- ss-version-aware:start -->` / `:end`). Ako `CLAUDE.md` postoji, mijenja se samo blok.
- Sadržaj bloka ≤ ~15 linija: framework verzija, ključni moduli, PHP (DDEV), build alat, režim (normal/upgrade X→Y), hash `composer.lock`-a iz kojeg je generisan, i pravilo: *prije upotrebe bilo kojeg SS API-ja konsultuj `ss-version-aware` referencu za ovu verziju; ako stavka nije u referenci, provjeri u `vendor/`.*
- Ako `CLAUDE.md` NIJE praćen u Gitu: kreira se/ažurira i dodaje u `.git/info/exclude`.
- Ako `CLAUDE.md` JESTE praćen (dijeljen u repou): ne dira se; blok ide u alternativni lokalni fajl koji Claude Code automatski učitava, isključen kroz `.git/info/exclude`.
- Checklista upgrade-a: lokalni fajl (npr. `.claude/ss-upgrade-checklist.md`), po defaultu u `.git/info/exclude`; opcija da se commita na privatnim projektima.

### 5.5 Svježina
- Hash `composer.lock`-a u bloku se poredi s trenutnim pri svakoj aktivaciji skill-a; razlika → ponovna detekcija i osvježavanje bloka.
- Dodatno, plugin registruje hook na početku sesije koji radi isto poređenje (jeftino, bez mreže), tako da blok ne zastari ni kad se skill ne aktivira.

### 5.6 Reference
- Po jedan fajl po verziji: `ss3.md`, `ss4.md`, `ss5.md`, `ss6.md`; mape `migrations/4-to-5.md`, `migrations/5-to-6.md`.
- Format: tabele i kratke liste, ne proza. Za verzije: ključni namespace-ovi/klase, tipični potpisi koji se razlikuju među verzijama, config/YAML konvencije, template sintaksa specifična za verziju, PHP minimum. Za mape: stari → novi, uklonjeno → zamjena, config i template promjene.
- Svaka stavka mape ima link na zvanični izvor. Ono što nije potvrđeno izvorom ne ulazi u referencu.
- Redoslijed izrade: reference i mape se pišu PRVE i Đorđe ih pregleda prije nego što skill ide u upotrebu. Kod (detekcija, hook, blok, checklista) može se raditi paralelno, ali release čeka pregled.
- Reference se drže fokusiranim na ono što se razlikuje među verzijama (mjesta gdje model griješi), ne na kompletan API.

### 5.7 Aktivacija po projektu *(moja odluka)*
- Projekat se uključuje eksplicitno: Đorđe pokrene skill ("postavi ss-version-aware") → detekcija, blok, `.git/info/exclude`. Marker uključenosti = postojanje bloka.
- Kad se skill aktivira u neuključenom SS projektu: detektuje verziju i koristi je u sesiji bez pisanja fajlova, uz ponudu u jednoj liniji da uključi projekat.
- Hook na početku sesije radi samo u uključenim projektima; u ostalim (firmeni bez uključenja, ne-SS repoi) ne radi ništa.
- Hook pri promjeni lock hash-a tiho prepiše blok. Detekcija je čisto parsiranje teksta `composer.lock`-a, bez `ddev exec`, pa je brza. Ako se pri tome promijeni major verzija, hook to javi Claude-u u sesiji.

### 5.8 Checklista — zatvaranje stavki *(moja odluka)*
- Svaka stavka čuva obrazac za ponovnu pretragu (klasa/metoda/config ključ), ne samo `fajl:linija`.
- Claude označava stavke dok radi izmjene; ponovni sken potvrđuje. Stavka je zatvorena tek kad sken više ne nalazi staru upotrebu.
- Upgrade režim se završava samo nakon skena bez nalaza.

### 5.9 Ograničenja preko više major verzija *(moja odluka)*
- Kad `require` modula pokriva više majora (npr. `^5 || ^6`): režim "kompatibilno", gdje blok navodi obje verzije.
- Pravilo u tom režimu: koristi samo API koji postoji u obje verzije, ili verzijski uslovljen kod (`class_exists` / interface provjera) kad drugačije ne ide. Čitaju se obje reference.
- Razlika samo u minor verziji između `vendor/` i lock-a znači ponovnu detekciju, ne upgrade režim.

## 6. Prepušteno builderu

- Jezik/implementacija skripte za detekciju (u okviru ograničenja iz §3).
- Tačan naziv i mehanizam alternativnog lokalnog fajla iz §5.4 — provjeriti u aktuelnoj Claude Code dokumentaciji šta se automatski učitava.
- Struktura plugin repoa. Naziv: namespace/vendor `YouWillLikeIT` (repo npr. `youwilllikeit/claude-skills`) — odluka Đorđe.
- Tačan obim modula u referencama mimo onih navedenih u §5.2.
- Postojanje i izbor Rector pravila za 4→5 i 5→6.
- Testiranje: fixture `composer.lock` fajlovi za SS3/4/5/6 i upgrade stanja; eval scenariji (isti zadatak na SS5 i SS6 projektu, npr. GridField, DataObject s `has_many`, Extension, template s petljom) gdje se provjerava da generisani kod koristi API prave verzije.
