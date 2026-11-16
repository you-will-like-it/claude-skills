# ss-version-aware — behavioural evals

The controller runs these. Each scenario runs in two ways: a **baseline** run without the plugin, to record the failures, and a run **with the skill**, where 9/9 must pass.

**How to run one scenario**
1. Copy the fixture to a fresh temp dir. Run `git init`, then commit everything, the same way `make_git_fixture` in `tests/lib.sh` does it. Then do the **Setup** steps there. `$P` means `plugins/ywli-dev` in this repo, which is `${CLAUDE_PLUGIN_ROOT}` for the skill.
2. Start a fresh session with its cwd in the temp dir. Load the skill (`$P/skills/ss-version-aware/SKILL.md`) and send **Prompt** exactly as written.
3. Record the full run log: every shell command, every Read-tool call (path, offset/limit), and all assistant text, including text written between tool calls, in order. A log of shell commands and the final reply alone is not enough. The "read reference" and ordering criteria cannot be graded without it.
4. Grade the log and the resulting tree (`git status`, `git diff`, new files) against **Pass criteria**. Every box must hold. "Does NOT contain X" applies to code in every PHP, YAML and `.ss` file the run created or changed. Code means `use` lines, `extends`/`implements`, calls, signatures, YAML keys and values, and template code. PHP comments and docblocks are excluded. The skill itself forbids such forms in comments (SKILL.md §3.5), but that is not graded here.

None of the fixtures has `vendor/`. Any API that the loaded reference does not show therefore cannot be verified in source. The run must say so, and must not use such an API silently.

Every class and namespace in the criteria comes from the reference cited next to it, in the form (file § section).

---

## E1a: GridField + validator on SS5

**Fixture:** `tests/fixtures/ss5` (framework 5.4.3; contains `app/src/Model/Project.php`)
**Setup:** `bash $P/scripts/block.sh init` (the block goes to the untracked `CLAUDE.md`).
**Prompt:** Projektu (app/src/Model/Project.php) dodaj has_many Tasks — napravi i Task DataObject (Title, has_one Project). U CMS-u prikaži Tasks u GridFieldu s GridFieldConfig_RecordEditor, 20 po stranici, na tabu Tasks. Title projekta neka bude obavezan u CMS formi (validator), a validate() neka odbije Title kraći od 3 znaka.
**Pass criteria:**
- [ ] Ran `detect.sh`, or compared the block's `lock:` with `git hash-object composer.lock`, before writing code. Read `references/ss5.md`.
- [ ] Uses `SilverStripe\Forms\GridField\GridField` and `SilverStripe\Forms\GridField\GridFieldConfig_RecordEditor` with `GridFieldConfig_RecordEditor::create(20)` (ss5.md § Namespace-ovi i klase; § Potpisi i obrasci "GridField").
- [ ] The required field goes through `getCMSCompositeValidator()` with `SilverStripe\Forms\CompositeValidator` and `SilverStripe\Forms\RequiredFields` (ss5.md § Namespace-ovi i klase; § Potpisi i obrasci "CMS validator").
- [ ] If `ValidationResult` is named anywhere, it is `SilverStripe\ORM\ValidationResult` (ss5.md § Namespace-ovi i klase).
- [ ] Does NOT contain `SilverStripe\Forms\Validation\`, `SilverStripe\Core\Validation\`, `RequiredFieldsValidator` or `SilverStripe\Model\` (ss5.md § Česte greške; these are SS6 classes).
- [ ] Does NOT override `getCMSValidator()` (ss5.md § Česte greške, M56-050).
- [ ] `Task` has `private static $table_name` and `has_one` `'Project' => Project::class`. `Project` has `has_many` `'Tasks' => Task::class` (ss5.md § Potpisi i obrasci "DataObject").
- [ ] `CLAUDE.md` still has exactly one `<!-- ss-version-aware:start -->` block, and the run made no edits to it.

## E1b: GridField + validator on SS6

**Fixture:** `tests/fixtures/ss6` (framework 6.1.2; contains `app/src/Model/Project.php`)
**Setup:** `bash $P/scripts/block.sh init`
**Prompt:** Projektu (app/src/Model/Project.php) dodaj has_many Tasks — napravi i Task DataObject (Title, has_one Project). U CMS-u prikaži Tasks u GridFieldu s GridFieldConfig_RecordEditor, 20 po stranici, na tabu Tasks. Title projekta neka bude obavezan u CMS formi (validator), a validate() neka odbije Title kraći od 3 znaka.
**Pass criteria:**
- [ ] Ran `detect.sh`, or compared the block's `lock:` with `git hash-object composer.lock`. Read `references/ss6.md`.
- [ ] Uses `SilverStripe\Forms\GridField\GridField` and `SilverStripe\Forms\GridField\GridFieldConfig_RecordEditor` (ss6.md § Namespace-ovi i klase; § Potpisi i obrasci "GridField").
- [ ] Uses `SilverStripe\Forms\Validation\RequiredFieldsValidator` and `SilverStripe\Forms\Validation\CompositeValidator` in `getCMSCompositeValidator(): CompositeValidator` (ss6.md § Namespace-ovi i klase; § Potpisi i obrasci "CMS validator").
- [ ] `public function validate(): ValidationResult` with `use SilverStripe\Core\Validation\ValidationResult;` (ss6.md § Potpisi i obrasci "DataObject"; § Česte greške, M56-057).
- [ ] Does NOT contain `use SilverStripe\Forms\RequiredFields;`, `SilverStripe\Forms\CompositeValidator;` or `SilverStripe\ORM\ValidationResult` (ss6.md § Česte greške, M56-015, M56-016, M56-009).
- [ ] Does NOT contain `getCMSValidator` (ss6.md § Česte greške, M56-050).
- [ ] `Task` has `$table_name` and `has_one` `'Project' => Project::class` (ss6.md § Potpisi i obrasci "DataObject").

## E2: DataObject with has_many + CMS field on SS4 (project not set up)

**Fixture:** `tests/fixtures/ss4` (framework 4.13.10; contains `app/src/Page.php`)
**Setup:** none. No block exists, so the project is not set up.
**Prompt:** Napravi DataObject Event (Title, Summary kao textarea u CMS-u) koji ima has_many Speakers — napravi i Speaker (Name, has_one Event). Speakers prikaži u CMS-u kroz GridField. validate() neka traži Title.
**Pass criteria:**
- [ ] Ran `detect.sh` (it reports `SS_MAJOR=4`) and read `references/ss4.md`.
- [ ] Wrote no `CLAUDE.md` and no `CLAUDE.local.md`, did not change `.git/info/exclude`, and did not run `block.sh init`. Offered setup in at most one line that mentions "postavi ss-version-aware".
- [ ] Classes are namespaced (`namespace App\...`) and use `use SilverStripe\ORM\DataObject;`. Both classes have `private static $table_name` (ss4.md § Potpisi i obrasci "DataObject").
- [ ] `has_many` `'Speakers' => Speaker::class`, and `Speaker` has `has_one` `'Event' => Event::class` (ss4.md § Potpisi i obrasci "DataObject").
- [ ] Summary uses `SilverStripe\Forms\TextareaField` (ss4.md § Potpisi i obrasci "DataObject"). If the GridField is explicit, it uses `SilverStripe\Forms\GridField\GridField` and `SilverStripe\Forms\GridField\GridFieldConfig_RecordEditor` (ss4.md § Namespace-ovi i klase).
- [ ] `public function validate()` (not `protected`) returns the result of `parent::validate()` and uses `addFieldError`/`addError`. Any `ValidationResult` is `SilverStripe\ORM\ValidationResult` (ss4.md § Potpisi i obrasci "DataObject"; § Česte greške).
- [ ] Does NOT contain `SilverStripe\Core\Validation\`, `SilverStripe\Model\`, `class_description`, `scaffold_cms_fields_settings` or `orderBy(` (ss4.md § Potpisi i obrasci, napomena; § Česte greške).

## E3: Extension on SS3 without Composer (project not set up)

**Fixture:** `tests/fixtures/ss3-nocomposer` (`framework/silverstripe_version` = 3.6.1; contains `mysite/code/Page.php`, `mysite/_config/config.yml` and `mysite/_config.php`)
**Setup:** none. There is no `composer.json`, no `vendor/` and no block.
**Prompt:** Dodaj Member-u polje JobTitle preko extensiona, prikaži ga u CMS-u i validiraj da nije duže od 50 znakova.
**Pass criteria:**
- [ ] Ran `detect.sh` (it reports `SS_MAJOR=3`, `SS_VERSION=3.6.1`) and read `references/ss3.md`.
- [ ] Wrote no `CLAUDE.md` and no `CLAUDE.local.md`. The setup offer is at most one line.
- [ ] The new class is in `mysite/code/` and declares `class ... extends DataExtension`. The file has no `namespace` line and no `use ` line (ss3.md § Namespace-ovi i klase, intro; § Potpisi i obrasci "DataExtension").
- [ ] `public function updateCMSFields(FieldList $fields)` and `public function validate(ValidationResult $validationResult)`. The error goes through `->error(`, not `addFieldError`/`addError` (ss3.md § Potpisi i obrasci "DataExtension"; § Česte greške).
- [ ] Gets the owner through `$this->owner` (ss3.md § Potpisi i obrasci "DataExtension").
- [ ] Registers the extension as a bare class name, either in `mysite/_config/*.yml` under `Member:` → `extensions:` or with `Member::add_extension('...')` in `mysite/_config.php` (ss3.md § Config/YAML).
- [ ] Does NOT contain `SilverStripe\`, `protected function`, `$table_name`, `getCMSCompositeValidator`, `.env` or `Environment::getEnv` (ss3.md § Česte greške).
- [ ] Mentions `dev/build` with `flush=1`, because SS3 needs a flush to find a new class (ss3.md § Osnovno).
- [ ] If it checked an API in source, it searched `framework/` or `cms/`, not `vendor/`, or it said that no source is available to check.

## E4: Template loop + pagination on SS6

**Fixture:** `tests/fixtures/ss6`
**Setup:** `bash $P/scripts/block.sh init`
**Prompt:** Napravi ProjectsPage tip stranice koji lista Project zapise sa statusom Active ili Featured, 10 po stranici. U templatu: prvi element dobije klasu "first", zadnji "last", ispiši redni broj, uz svaki projekat i naslov stranice, i oznaku "Istaknuto" ako je Status Active ili Featured. Dodaj i paginaciju.
**Pass criteria:**
- [ ] Read `references/ss6.md`.
- [ ] The controller is `...\ProjectsPageController`, with no `ProjectsPage_Controller` (ss6.md § Osnovno). If it has `init()`, that method is `protected` and calls `parent::init()` (ss6.md § Potpisi i obrasci "PageController").
- [ ] Uses `SilverStripe\Model\List\PaginatedList` and does NOT contain `SilverStripe\ORM\PaginatedList` (ss6.md § Namespace-ovi i klase; § Česte greške, M56-006).
- [ ] The template uses `$IsFirst` and `$IsLast`. It does NOT match `grep -E '\$(First|Last)\b'` (ss6.md § Templati).
- [ ] The Status condition uses `||` or two separate `<% if %>` blocks. It does NOT match `grep -E '<% *(if|else_if) [^%]*\b(or|and)\b'` (ss6.md § Templati).
- [ ] The row number uses `$Pos`. The page title inside the loop uses `$Up.Title` or `$Top.Title` (ss6.md § Templati).
- [ ] The run names the pagination template methods it uses (for example `MoreThanOnePage`, `PrevLink`, `NextLink`, `Pages`). These are not in ss6.md, so the run explicitly flags them as unverified because `vendor/` is missing, or it asks. It does not use them silently.

## E5: Module change in compat mode (^5 || ^6)

**Fixture:** `tests/fixtures/module-compat` (`silverstripe-vendormodule`, `"silverstripe/framework": "^5 || ^6"`; contains `src/Model/Widget.php`)
**Setup:** `bash $P/scripts/block.sh init`. The block reads `režim: compat` and `kompatibilno: 5 6`.
**Prompt:** U modulu dodaj extension za Member: polje Nickname (max 30 znakova, s validacijom), CMS polje za njega, i metodu WidgetTitles() koja vraća ArrayList s naslovima svih Widget-a za template.
**Pass criteria:**
- [ ] Read both `references/ss5.md` and `references/ss6.md` (compat mode).
- [ ] The extension class `extends SilverStripe\Core\Extension`, and `DataExtension` does not appear in any `use` line, `extends` clause or YAML (ss5.md and ss6.md § Namespace-ovi i klase; ss6.md § Česte greške, M56-036).
- [ ] Has no unconditional `use SilverStripe\ORM\ArrayList;`, `use SilverStripe\Model\List\ArrayList;`, `use SilverStripe\View\ArrayData;` or `use SilverStripe\Model\ArrayData;`. If the code needs either class, it picks the FQCN behind `class_exists(...)` (ss5.md vs ss6.md § Namespace-ovi i klase). Avoiding the class is also a pass, but only if the run states the reason.
- [ ] Validation runs on both majors: it has a `validate(...)` hook (5) and an `updateValidate(...)` hook (6). The `ValidationResult` parameter is either untyped or typed through a version-conditional alias, never a single-version FQCN such as `SilverStripe\ORM\ValidationResult` or `SilverStripe\Core\Validation\ValidationResult` (ss5.md § Potpisi i obrasci "Extension"; ss6.md § Potpisi i obrasci "Extension", M56-059).
- [ ] Uses `updateCMSFields(FieldList $fields)` with `SilverStripe\Forms\FieldList` and `SilverStripe\Forms\TextField`, which are the same in 5 and 6 (ss5.md, ss6.md § Potpisi i obrasci "Extension").
- [ ] Does NOT contain `SilverStripe\Forms\Validation\`, `SilverStripe\Forms\RequiredFields` or `BuildTask` APIs.
- [ ] The reply says that the code targets both SS5 and SS6.

## E6: "postavi ss-version-aware" with a committed CLAUDE.md

**Fixture:** `tests/fixtures/ss6`
**Setup:** Create `CLAUDE.md` containing `# Team notes` and `Koristi PSR-12.`, then `git add CLAUDE.md && git commit -m notes`.
**Prompt:** postavi ss-version-aware
**Pass criteria:**
- [ ] Ran `bash ${CLAUDE_PLUGIN_ROOT}/scripts/block.sh init` (or the same command with the resolved path).
- [ ] Reported `TARGET=CLAUDE.local.md`, meaning that the block went to `CLAUDE.local.md` because `CLAUDE.md` is tracked.
- [ ] `git diff --exit-code CLAUDE.md` exits 0, so the committed file is untouched.
- [ ] `git status --porcelain` is empty, because `CLAUDE.local.md` is in `.git/info/exclude`. No `.gitignore` was created or changed.
- [ ] `CLAUDE.local.md` contains `<!-- ss-version-aware:start -->` and `(major 6)`.
- [ ] The reply is short. It reports the detected version (SS 6.1.2) and the target file, and does not paste reference content.

## E7: Upgrade 5 → 6

**Fixture:** `tests/fixtures/upgrade-5-6` (`composer.json` `recipe-cms ^6`, lock framework 5.4.3; SS5 code in `app/src/Model/Project.php` and `app/src/Extension/MemberProfileExtension.php`)
**Setup:** `bash $P/scripts/block.sh init`. The block reads `režim: upgrade → 6`.
**Prompt:** Radim upgrade 5→6 na ovom projektu. Skeniraj i odradi stavke iz checkliste; composer update ću pokrenuti ja.
**Pass criteria:**
- [ ] Read `references/ss6.md` and `references/migrations/5-to-6.md`.
- [ ] Offered `wernerkrauss/silverstripe-rector` (`SilverstripeLevelSetList::UP_TO_SS_6_0`, listed in 5-to-6.md § Rector) in one line, as assistant text logged before the first `scan-upgrade.sh` call (an offer only in the final reply fails). Because the prompt asks for the checklist to be worked, it continued in the same turn without waiting. It did not install or run Rector, and did not recommend `cambis/silverstripe-rector`.
- [ ] Ran `bash ${CLAUDE_PLUGIN_ROOT}/scripts/scan-upgrade.sh --from 5 --to 6` and reported the first count (`OPEN=9`; the scan also prints `MANUAL=24`). `.claude/ss-upgrade-checklist.md` exists and `git status --porcelain` does not list it.
- [ ] Edited the code to the map/ss6 forms: `SilverStripe\Model\List\ArrayList` (M56-002), `SilverStripe\Model\ArrayData` (M56-010), `SilverStripe\Core\Validation\ValidationResult` (M56-009), `SilverStripe\Forms\Validation\RequiredFieldsValidator` (M56-015), `SilverStripe\Forms\Validation\CompositeValidator` (M56-016), `extends Extension` with `SilverStripe\Core\Extension` (M56-036), the hook `validate` renamed to `updateValidate` (M56-059), and `public function validate(): ValidationResult` in `Project` (M56-057).
- [ ] Re-ran `scan-upgrade.sh` after the edits and reported the new `OPEN=` count.
- [ ] Did NOT declare the upgrade finished. The lock still shows 5.4.3, so it said that `composer update` comes next, followed by a re-scan, and that `block.sh refresh` runs only once the lock shows 6.x and `OPEN=0`.
- [ ] The reply reports the `MANUAL=` count and points the user to the `## Ručni pregled (nema grep obrasca)` section of `.claude/ss-upgrade-checklist.md` (e.g. M56-123, scaffolded relation fields) as items needing a manual check. It does not tick them without having verified them.
- [ ] Did not edit `composer.lock`, did not create `vendor/`, and did not run `composer update`.

## E8: ⚠ block at session start (hook context lost)

**Fixture:** `tests/fixtures/ss5`
**Setup:** Run `bash $P/scripts/block.sh init`. In `composer.json`, change `"^5"` to `"^6"`. In `composer.lock`, change the framework `"version": "5.4.3"` to `"6.1.2"`. Commit both. Then run `bash $P/scripts/block.sh refresh`, standing in for the SessionStart hook whose message the client did not deliver. `CLAUDE.md` now contains `⚠ Verzija promijenjena (5 → 6) — pokreni ss-version-aware.` and `(major 6)`.
**Prompt:** Napravi BuildTask koji briše Project zapise sa statusom Draft starije od 30 dana.
**Pass criteria:**
- [ ] Noticed the `⚠` line before writing code and ran `block.sh refresh`.
- [ ] The reply tells the user in one or two lines that the version changed 5 → 6.
- [ ] Ran `block.sh ack`. `CLAUDE.md` no longer contains `⚠` and still shows `(major 6)`.
- [ ] Read `references/ss6.md`, not ss5.md, for the code.
- [ ] `execute(InputInterface $input, PolyOutput $output): int` uses `SilverStripe\PolyExecution\PolyOutput` and `Symfony\Component\Console\Input\InputInterface`, returns `Command::SUCCESS` or another `Command::` constant, and declares `protected static string $commandName` and `protected static string $description` (ss6.md § Potpisi i obrasci "BuildTask"; § Namespace-ovi i klase).
- [ ] Does NOT contain `public function run(`, `private static $segment` or `protected $description` (ss6.md § Česte greške, M56-071, M56-078, M56-072).
- [ ] If it mentions how to run the task, it uses `sake tasks:<name>` or `/dev/tasks/<name>`, not `sake dev/tasks/...` (ss6.md § Osnovno; § Česte greške, M56-109).
