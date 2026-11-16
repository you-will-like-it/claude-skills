# ss-version-aware Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Claude Code plugin `youwilllikeit-dev` with skill `ss-version-aware`. The skill detects a project's SilverStripe version and mode (normal / upgrade / compat), writes a short version block into a local memory file, keeps that block fresh with a SessionStart hook, and supplies sourced per-version references and upgrade maps with a re-scannable checklist.

**Architecture:** Pure bash scripts carry the logic: detection, writing the block, the hook, and the upgrade scanner. They share one library and print `KEY=value` lines. The skill's `SKILL.md` tells Claude when to run them and which reference to read. The references are markdown files. Each upgrade map also has a machine-readable `.patterns` file that drives the scanner. The repo is both the marketplace and the plugin source.

**Tech Stack:** bash (compatible with 3.2), POSIX utilities (`grep -E`, `sed`, `awk`), git, Claude Code plugin system (`.claude-plugin/*.json`, `hooks/hooks.json`, `skills/*/SKILL.md`).

**Spec:** `docs/superpowers/specs/2026-11-14-ss-version-aware-design.md`

## Global Constraints

- Runs on macOS (bash 3.2, BSD utils) and WSL/Linux (GNU utils). No associative arrays, `mapfile`, `${v,,}`, `sed -i` without suffix, `grep -P`, or `readlink -f`.
- Runtime scripts must not depend on PHP, jq or python on the host. `ddev exec` is allowed only as an explicit fallback; detection itself never needs it.
- Never modify git-tracked files or `.gitignore` in a target project. The only git-level write allowed is to the file returned by `git rev-parse --git-path info/exclude`.
- Block markers are exactly `<!-- ss-version-aware:start -->` and `<!-- ss-version-aware:end -->`. The block is at most 15 lines between the markers.
- Block target: `CLAUDE.md` if it is untracked or absent; `CLAUDE.local.md` if `CLAUDE.md` is tracked. Whichever file is used goes into info/exclude.
- Upgrade checklist path: `.claude/ss-upgrade-checklist.md`. It goes into info/exclude by default.
- Every reference/map entry carries a link to an official source (docs.silverstripe.org, github.com/silverstripe/*, github.com/silverstripe/silverstripe-*/…). No unsourced claims.
- Release gate: Đorđe reviews all references before the plugin is installed for real use.
- Vendor/namespace: `YouWillLikeIT`; repo `youwilllikeit/claude-skills`; plugin name `youwilllikeit-dev`.
- Scanner excludes `vendor/`, `node_modules/`, `public/_resources/`, `resources/`, `.git/`.

## Review Focus

1. **Version strings in non-standard formats** (`v5.4.3`, `5.x-dev`, `dev-main`, `6.0.0-beta1`): the major is read from the first digit run. `dev-main` with no digits gives `SS_MAJOR=unknown`, not a crash. Tested in Task 2.
2. **Projects that require a recipe instead of the framework** (`silverstripe/recipe-cms: ^5`, or the SS4-era `^1.x` recipes): the recipe major maps to the SS major, with recipe 1 → 4. Tested in Task 2/3.
3. **Hook running in a non-SS repo, in a repo that is not set up, or outside git**: exits 0 silently and writes nothing. Tested in Task 5.
4. **Hook context dropped in VS Code** (known bug: plugin SessionStart `additionalContext` is not delivered): a major-version change must also be written into the block itself as a `⚠` line, so the next load shows it without the hook message. Tested in Task 5.
5. **CRLF line endings / Windows-edited files** in `composer.json`, `composer.lock` and the existing `CLAUDE.md`: parsing strips `\r`, and rewriting the block keeps the user's text outside the markers byte-for-byte. Tested in Task 2 and Task 4.

---

## File Structure

```
.claude-plugin/marketplace.json            marketplace listing one plugin (source ./plugins/youwilllikeit-dev)
plugins/youwilllikeit-dev/
  .claude-plugin/plugin.json               plugin manifest
  hooks/hooks.json                         SessionStart → scripts/session-start.sh
  scripts/lib.sh                           shared parsing functions (sourced)
  scripts/detect.sh                        prints KEY=value detection result
  scripts/block.sh                         renders + writes block, maintains info/exclude
  scripts/session-start.sh                 hook entry point
  scripts/scan-upgrade.sh                  builds/merges upgrade checklist
  skills/ss-version-aware/SKILL.md
  skills/ss-version-aware/references/ss3.md ss4.md ss5.md ss6.md
  skills/ss-version-aware/references/migrations/4-to-5.md  4-to-5.patterns
  skills/ss-version-aware/references/migrations/5-to-6.md  5-to-6.patterns
tests/lib.sh                               assert helpers
tests/run.sh                               runs every tests/test_*.sh, non-zero on failure
tests/test_*.sh
tests/fixtures/<name>/                     minimal project trees (see Task 1)
tests/evals.md                             behavioural eval scenarios (Task 11)
```

---

### Task 1: Repo skeleton, test harness, fixtures

**Files:**
- Create: `.claude-plugin/marketplace.json`, `plugins/youwilllikeit-dev/.claude-plugin/plugin.json`, `tests/lib.sh`, `tests/run.sh`, `tests/test_harness.sh`, `README.md`
- Create fixtures under `tests/fixtures/`:
  - `ss6/`: `composer.json` requires `"silverstripe/recipe-cms": "^6.0"`; `composer.lock` with packages `silverstripe/framework` `6.1.2`, `silverstripe/cms` `6.1.0`, `dnadesign/silverstripe-elemental` `6.0.1`; `vite.config.js`; `.ddev/config.yaml` with `php_version: "8.3"`
  - `ss5/`: framework `5.4.3`, `"silverstripe/framework": "^5"`; `webpack.config.js`; `.ddev/config.yaml` `php_version: "8.2"`
  - `ss4-recipe1/`: `"silverstripe/recipe-cms": "1.3.0"` in composer.json; lock framework `4.3.2`
  - `ss4/`: framework `4.13.10`
  - `ss3-composer/`: lock framework `3.7.6`
  - `ss3-nocomposer/`: `framework/core/Core.php`, `framework/silverstripe_version` containing `3.6.1`, `cms/` dir, no composer files
  - `upgrade-5-6/`: composer.json `"silverstripe/recipe-cms": "^6"`; lock framework `5.4.3`
  - `vendor-stale/`: lock framework `6.0.0`; `vendor/composer/installed.json` framework `5.4.3`
  - `module-compat/`: composer.json `"type": "silverstripe-vendormodule"`, `"silverstripe/framework": "^5 || ^6"`, no lock
  - `notss/`: composer.json requiring only `laravel/framework`
  - `crlf-ss5/`: copy of `ss5` converted to CRLF
  - `versions-odd/`: lock framework `v5.4.3`; a sibling `versions-dev/` with lock framework `dev-main`

**Interfaces:**
- Produces: `tests/lib.sh` → `assert_eq <expected> <actual> <msg>`, `assert_contains <haystack> <needle> <msg>`, `assert_not_contains`, `assert_file_contains <file> <needle>`, `assert_exit <code> <cmd...>`, and `make_git_fixture <fixture-name>`, which copies the fixture to a temp dir, runs `git init` and commits everything, and echoes the path. `tests/run.sh` returns non-zero if any test fails.

- [ ] **Step 1:** Write `tests/test_harness.sh`. It asserts `assert_eq a a` passes, that `make_git_fixture ss5` returns a dir containing `composer.lock` with a clean `git status --porcelain`, and that `marketplace.json` and `plugin.json` contain `"name": "youwilllikeit-dev"`.
- [ ] **Step 2:** Run `bash tests/run.sh`. Expected: FAIL (files missing).
- [ ] **Step 3:** Create the harness, the manifests and the fixtures. `plugin.json`: `{"name":"youwilllikeit-dev","version":"0.1.0","description":"SilverStripe dev tools by YouWillLikeIT","author":{"name":"YouWillLikeIT"}}`. `marketplace.json`: name `youwilllikeit`, owner `YouWillLikeIT`, one plugin with `"source": "./plugins/youwilllikeit-dev"`.
- [ ] **Step 4:** Run `bash tests/run.sh`. Expected: PASS. If the `claude` CLI is available, also run `claude plugin validate .` and expect no errors.
- [ ] **Step 5:** Commit `chore: plugin skeleton, test harness, fixtures`.

---

### Task 2: lib.sh: version parsing primitives

**Files:**
- Create: `plugins/youwilllikeit-dev/scripts/lib.sh`, `tests/test_lib.sh`

**Interfaces:**
- Produces (all print to stdout, return 0 even when nothing is found):
  - `ssva_strip_cr <file>`: cat with `\r` removed
  - `ssva_lock_version <lockfile> <package>`: version string of the first `"name": "<package>"` entry, e.g. `5.4.3`, or empty
  - `ssva_major <version>`: first digit run (`v5.4.3`→`5`, `5.x-dev`→`5`, `dev-main`→empty)
  - `ssva_require_constraint <composer.json> <package>`: constraint string from `require`/`require-dev`, or empty
  - `ssva_constraint_majors <constraint>`: space-separated, ascending, unique majors (`^5 || ^6`→`5 6`, `~5.4`→`5`, `6.*`→`6`, `>=4.13 <6`→`4`)
  - `ssva_recipe_to_ss_major <recipe-major>`: `1`→`4`, else identity
  - `ssva_installed_version <installed.json> <package>`: same as `ssva_lock_version`

- [ ] **Step 1:** Write `tests/test_lib.sh` with one assertion per example above. Add: `ssva_lock_version` on `crlf-ss5/composer.lock` → `5.4.3`; on `versions-odd` → `v5.4.3`; `ssva_major dev-main` → empty; `ssva_constraint_majors "^5 || ^6"` → `5 6`; `ssva_require_constraint ss6/composer.json silverstripe/recipe-cms` → `^6.0`.
- [ ] **Step 2:** Run `bash tests/run.sh`. Expected: FAIL.
- [ ] **Step 3:** Implement with `awk`/`sed` over `ssva_strip_cr` output. Lock parsing: find the `"name": "<pkg>"` line, then the next `"version":` line in the same object.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5:** Commit `feat: version parsing primitives`.

---

### Task 3: detect.sh

**Files:**
- Create: `plugins/youwilllikeit-dev/scripts/detect.sh`, `tests/test_detect.sh`

**Interfaces:**
- Consumes: Task 2 functions.
- Produces: `detect.sh [project_dir]` (default `$PWD`), exit 0, prints these lines in this order:
  ```
  SS_PROJECT=project|module|none
  SS_VERSION=<full or 3.x or unknown>
  SS_MAJOR=<n|unknown>
  SS_MODE=normal|upgrade|compat
  SS_TARGET_MAJOR=<n or empty>
  SS_COMPAT_MAJORS=<"5 6" or empty>
  SS_VENDOR_MISMATCH=0|1
  SS_MODULES=<pkg=ver,pkg=ver>        # cms, admin, assets, versioned, elemental, fluent, whichever exist
  PHP_VERSION=<from .ddev/config.yaml or empty>
  BUILD_TOOL=vite|webpack|none
  DDEV=0|1
  LOCK_HASH=<git hash-object composer.lock, or "nolock">
  ```
- Rules:
  - `none` when there is no framework in the lock, no constraint on framework/recipe-cms/recipe-core, and no `framework/core/Core.php`.
  - SS3 without Composer: `SS_VERSION` from `framework/silverstripe_version`, else `3.x`.
  - Module (`"type": "silverstripe-vendormodule"`, or no lock and a constraint present): `SS_MODE=compat` if the constraint has more than one major, otherwise `normal` with that major.
  - Project: `upgrade` when the constraint majors (via the recipe mapping) do not contain the lock major. Then `SS_TARGET_MAJOR` = highest constraint major. `upgrade` also when the installed.json major ≠ the lock major (`SS_VENDOR_MISMATCH=1`, target = lock major, `SS_MAJOR` = installed major). A minor-only mismatch stays `normal`.

- [ ] **Step 1:** Write `tests/test_detect.sh` with expected key lines per fixture:
  - `ss6`: `SS_MAJOR=6`, `SS_MODE=normal`, `BUILD_TOOL=vite`, `PHP_VERSION=8.3`, `DDEV=1`, `SS_MODULES` contains `dnadesign/silverstripe-elemental=6.0.1`
  - `ss5`: `SS_MAJOR=5`, `BUILD_TOOL=webpack`
  - `ss4-recipe1`: `SS_MAJOR=4`, `SS_MODE=normal`
  - `ss3-nocomposer`: `SS_VERSION=3.6.1`, `SS_MAJOR=3`, `LOCK_HASH=nolock`
  - `ss3-composer`: `SS_MAJOR=3`
  - `upgrade-5-6`: `SS_MODE=upgrade`, `SS_MAJOR=5`, `SS_TARGET_MAJOR=6`
  - `vendor-stale`: `SS_MODE=upgrade`, `SS_VENDOR_MISMATCH=1`, `SS_MAJOR=5`, `SS_TARGET_MAJOR=6`
  - `module-compat`: `SS_PROJECT=module`, `SS_MODE=compat`, `SS_COMPAT_MAJORS=5 6`
  - `notss`: `SS_PROJECT=none`
  - `crlf-ss5`: identical output to `ss5`, except `LOCK_HASH`
  - `versions-dev`: `SS_MAJOR=unknown`, exit 0
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement `detect.sh` by sourcing `lib.sh` via `$(dirname "$0")`.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat: detect.sh`.

---

### Task 4: block.sh: render and write the block

**Files:**
- Create: `plugins/youwilllikeit-dev/scripts/block.sh`, `tests/test_block.sh`

**Interfaces:**
- Consumes: `detect.sh` output.
- Produces:
  - `block.sh init [dir]`: detect, choose the target file, write the block, add the target to info/exclude. Prints `TARGET=<file>`. Exit 2 with a message if `SS_PROJECT=none`.
  - `block.sh refresh [dir]`: no-op (exit 0, no output) if neither `CLAUDE.md` nor `CLAUDE.local.md` holds the start marker. Otherwise re-detect and rewrite the block in the file that holds it. Prints `CHANGED=0|1` and `MAJOR_CHANGED=<old>-><new>` when the major or mode changed.
  - `block.sh show [dir]`: prints the rendered block without writing.
- Block content (between markers, ≤15 lines, Bosnian). Required lines:
  - `SilverStripe <SS_VERSION> (major <SS_MAJOR>) — režim: <mode>`, plus `→ <target>` for upgrade or `kompatibilno: <majors>` for compat
  - modules line, `PHP <v> (DDEV)` line, `Build: <tool>`
  - the rule line: `Prije upotrebe bilo kojeg SilverStripe API-ja koristi skill ss-version-aware (referenca za ovu verziju); ako stavka nije u referenci, provjeri u vendor/.`
  - for upgrade: `Novi kod piši isključivo za SS<target>; postojeći mijenjaj prema mapi migracije i .claude/ss-upgrade-checklist.md.`
  - for compat: `Koristi samo API koji postoji u SS<a> i SS<b>, ili verzijski uslovljen kod.`
  - `lock: <LOCK_HASH>` as the last line
  - when `refresh` sees a major or mode change: a line `⚠ Verzija promijenjena (<old> → <new>) — pokreni ss-version-aware.`, kept until the next `init` or a refresh with no change

- [ ] **Step 1:** Write tests on git fixtures:
  - `init` on `ss5` with no `CLAUDE.md` → creates `CLAUDE.md`; info/exclude contains `CLAUDE.md`; `git status --porcelain` is empty.
  - `init` when `CLAUDE.md` is committed → `TARGET=CLAUDE.local.md`; the committed `CLAUDE.md` is byte-identical (`git diff --exit-code`); info/exclude contains `CLAUDE.local.md`.
  - an existing untracked `CLAUDE.md` with user text above and below → after `init`, both texts are unchanged and exactly one start marker exists. Running `init` twice → still one block, and no duplicate line in info/exclude.
  - CRLF `CLAUDE.md` → the text outside the markers is byte-identical after `init`.
  - the block line count between markers is ≤15 for the `upgrade-5-6` and `module-compat` fixtures.
  - `refresh` on a fixture with no block → no output, exit 0, no files created.
  - `refresh` after the lock changes from 5.4.3 to 6.1.2 → `MAJOR_CHANGED=5->6`, and the block contains `⚠ Verzija promijenjena (5 → 6)` and the new `lock:` hash.
  - `init` on `notss` → exit 2.
  - git worktree: `init` writes to the file from `git rev-parse --git-path info/exclude`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Replace the block via awk into a temp file plus `mv`. Never `sed -i`.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat: block.sh`.

---

### Task 5: SessionStart hook

**Files:**
- Create: `plugins/youwilllikeit-dev/hooks/hooks.json`, `plugins/youwilllikeit-dev/scripts/session-start.sh`, `tests/test_hook.sh`

**Interfaces:**
- Consumes: `block.sh refresh`.
- Produces: `hooks.json` registers `SessionStart` with matcher `startup|resume|clear|compact` and command `bash "${CLAUDE_PLUGIN_ROOT}/scripts/session-start.sh"`, timeout 10.
- `session-start.sh` behaviour:
  - Uses `$CLAUDE_PROJECT_DIR`, falling back to `$PWD`.
  - Exits 0 silently if the dir is not inside a git work tree, or if `block.sh refresh` prints nothing.
  - On `MAJOR_CHANGED`, prints `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"ss-version-aware: verzija promijenjena <old> → <new>; blok osvježen."}}`.
  - Never exits non-zero.

- [ ] **Step 1:** Write tests:
  - non-git temp dir → exit 0, empty stdout
  - `notss` git fixture → exit 0, empty, no files created
  - `ss5` without init → empty, no files created
  - `ss5` after init, then the lock is swapped to 6.x → stdout parses as the exact JSON shape above (string compare), and the block shows the ⚠ line
  - `CLAUDE_PROJECT_DIR` unset → falls back to `$PWD`
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement. Escape `"` and `\` in the message.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat: SessionStart refresh hook`.

---

### Task 6: scan-upgrade.sh and the patterns format

**Files:**
- Create: `plugins/youwilllikeit-dev/scripts/scan-upgrade.sh`, `tests/test_scan.sh`, `tests/fixtures/scan/` (small `app/src/*.php`, `app/_config/*.yml`, `themes/x/templates/*.ss`, plus a `vendor/` copy that must be ignored), `tests/fixtures/scan/test.patterns`

**Interfaces:**
- Patterns file format (one rule per line, TAB-separated, `#` comments):
  `ID<TAB>grep -E regex<TAB>globs (comma list, e.g. *.php,*.yml)<TAB>short replacement hint`
  - IDs are `M45-NNN` for the 4→5 map and `M56-NNN` for the 5→6 map, matching the anchors `### M56-NNN` in the map `.md`.
- `scan-upgrade.sh --from <a> --to <b> [--dir d] [--checklist path]`:
  - Default checklist: `.claude/ss-upgrade-checklist.md`, added to info/exclude.
  - The chain uses each `migrations/<n>-to-<n+1>.patterns` for n = a … b-1.
  - Phase k+1 is listed only if the current lock major ≥ a+k. Otherwise the checklist shows `## Faza <n>→<n+1> (zaključano dok lock ne pokaže <n>.x)`.
  - Checklist line format: `- [ ] <ID> \`<relpath>:<line>\` — <hint> (mapa: references/migrations/<n>-to-<n+1>.md#<id-lowercase>)`
  - Merge: a key is `<ID>|<relpath>|<trimmed matched line text>`, not the line number. A previously listed key that no longer matches → `- [x]`. New findings → `- [ ]`.
  - Exit 0 if no `- [ ]` in unlocked phases, otherwise 1. The last line printed is `OPEN=<count>`.
  - `--patterns <file>` overrides the chain (tests only).
  - `--no-exclude`: does not add the checklist to info/exclude (for private repos where Đorđe wants to commit it). Test: with this flag the exclude file has no checklist line.

- [ ] **Step 1:** Write tests using `test.patterns` (e.g. `T-001	ArrayData	*.php	use ArrayData replacement`):
  - first scan → `OPEN=` equals the number of fixture occurrences; nothing from `vendor/` appears
  - after deleting one occurrence and adding a blank line above another → the deleted one becomes `[x]`, the shifted one stays `[ ]` (same key), and `OPEN` drops by 1
  - after all are fixed → exit 0, `OPEN=0`
  - `--from 4 --to 6` with lock major 4 → phase 5→6 shows the locked header and no items
  - the checklist file is in info/exclude
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3:** Implement with `grep -rnE` plus `--include` per glob and `--exclude-dir` for the Global Constraints list.
- [ ] **Step 4:** Run. Expected: PASS.
- [ ] **Step 5:** Commit `feat: upgrade scanner with re-scannable checklist`.

---

### Task 7: Migration map 5→6 (reference + patterns)

**Files:**
- Create: `skills/ss-version-aware/references/migrations/5-to-6.md`, `5-to-6.patterns`, `tests/test_references.sh`

**Interfaces:**
- Consumes: the patterns format from Task 6.
- Produces: a map whose entries each look like:
  ```
  ### M56-001
  **Staro:** `SilverStripe\...\X` · **Novo:** `SilverStripe\...\Y` · **Vrsta:** premješteno|uklonjeno|promijenjen potpis|config|template
  Izvor: <official URL>
  ```

- [ ] **Step 1:** Write `tests/test_references.sh`, which applies to all `references/**/*.md`:
  - every `### M..-NNN` and every table row in a version reference has an `Izvor:`/source URL on an allowed host (`docs.silverstripe.org`, `github.com/silverstripe`, `api.silverstripe.org`)
  - every ID in a `.patterns` file has a matching heading in the `.md`, and the reverse is checked as a warning, not a failure
  - every regex compiles (`grep -E "<re>" /dev/null`; exit 2 means failure)
- [ ] **Step 2:** Run. Expected: FAIL (no files).
- [ ] **Step 3:** Research the official 6.0 changelog and upgrade guide (docs.silverstripe.org/en/6/changelogs/6.0.0 and the linked pages), plus 6.1. Write entries only for changes the sources state: moved and renamed classes, removed APIs and their replacements, config and template changes, PHP minimum. Write a pattern line for every entry that is greppable. Also check whether maintained Rector rules for 5→6 exist. If they do, add a `## Rector` section with the source link.
- [ ] **Step 4:** Run `bash tests/run.sh`. Expected: PASS. Run `scan-upgrade.sh --from 5 --to 6` on a real SS5 project as a smoke test, with no errors.
- [ ] **Step 5:** Commit `docs: 5→6 migration map`.

---

### Task 8: Migration map 4→5

**Files:**
- Create: `references/migrations/4-to-5.md`, `4-to-5.patterns`

**Interfaces:**
- Consumes: the format from Task 7, the tests from Task 7 (they cover the new files automatically).

- [ ] **Step 1:** Run `bash tests/run.sh` with an empty `4-to-5.patterns` committed. Expected: PASS. This confirms the test picks the file up.
- [ ] **Step 2:** Research docs.silverstripe.org/en/5/changelogs/5.0.0 and the upgrade guide. Write the entries and patterns in the same way as Task 7.
- [ ] **Step 3:** Run tests. Expected: PASS. Run `scan-upgrade.sh --from 4 --to 6` on an SS4 project or fixture. Expected: phase 2 is locked.
- [ ] **Step 4:** Commit `docs: 4→5 migration map`.

---

### Task 9: Version references SS6 and SS5

**Files:**
- Create: `references/ss6.md`, `references/ss5.md`

**Interfaces:**
- Produces: the same section order in every version reference, so SKILL.md can point to sections:
  1. `## Osnovno`: PHP minimum, framework/cms/admin versions, install layout (`app/`, `public/`, `.env`)
  2. `## Namespace-ovi i klase`: table `Klasa | Namespace | Izvor`, limited to classes that moved between 4/5/6 or that the model commonly confuses
  3. `## Potpisi i obrasci`: DataObject, Extension, Controller, GridField, Form, Validation, typical snippets with a source link
  4. `## Config/YAML`
  5. `## Templati`
  6. `## Česte greške`: what not to use in this version, with the correct form

- [ ] **Step 1:** Extend `test_references.sh`: each `ss*.md` has all six headings in order. Run. Expected: FAIL.
- [ ] **Step 2:** Write `ss6.md` from the official 6.x docs and API. Where a snippet needs confirming, check the signatures against an actual `vendor/silverstripe/framework` of 6.1 (`composer create-project silverstripe/installer` in a temp dir, or a DDEV project).
- [ ] **Step 3:** Write `ss5.md` the same way against 5.4.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5:** Commit `docs: SS6 and SS5 references`.

---

### Task 10: Version references SS4 and SS3

**Files:**
- Create: `references/ss4.md`, `references/ss3.md`

**Interfaces:**
- Consumes: the six-heading structure from Task 9. In SS3, `## Namespace-ovi i klase` documents the global, unnamespaced class names, the `_config.php` / `_config/*.yml` split and `$db`/`$has_one` statics as SS3 uses them. Sources: docs.silverstripe.org/en/3/ and github.com/silverstripe/silverstripe-framework branch `3`.

- [ ] **Step 1:** Run tests. Expected: FAIL (files missing). The heading test from Task 9 already requires them.
- [ ] **Step 2:** Write `ss4.md` (target 4.13) and `ss3.md` (target 3.7). Every entry must be equally sourced. SS3 is not "lite".
- [ ] **Step 3:** Run tests. Expected: PASS.
- [ ] **Step 4:** Commit `docs: SS4 and SS3 references`.

---

### Task 11: SKILL.md and behavioural evals

**Files:**
- Create: `skills/ss-version-aware/SKILL.md`, `tests/evals.md`

**Interfaces:**
- Consumes: the CLIs `detect.sh`, `block.sh init|refresh|show`, `scan-upgrade.sh`, and the reference paths and section names.
- SKILL.md frontmatter:
  - `name: ss-version-aware`
  - `description` triggers on: any SilverStripe/Silverstripe PHP, YAML or `.ss` work, writing or reviewing DataObject/Extension/Controller/GridField/template code, "postavi ss-version-aware", upgrades between SS majors
- SKILL.md body (instructions to Claude), covering:
  1. Run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/detect.sh`, or compare the block's `lock:` with `git hash-object composer.lock`. On mismatch, run `block.sh refresh`.
  2. Read `references/ss<MAJOR>.md`. In compat mode read both. In upgrade mode read the target reference and the chain maps.
  3. Hard rule: never use an API not shown in the reference without checking `vendor/silverstripe/...` (grep for the class or method). If `vendor/` is missing, say so and ask.
  4. Not set up: use the detection in-session, offer `block.sh init` in one line, write nothing.
  5. Setup request → `block.sh init`, then report `TARGET`.
  6. Upgrade: offer Rector if the map lists it; run `scan-upgrade.sh --from X --to Y`; work through the checklist; re-scan after edits; never declare the upgrade done while `OPEN>0`; after the target lock is installed and `OPEN=0`, run `block.sh refresh`.
  7. If the block shows a `⚠` line, run `block.sh refresh` first and tell the user.
- `tests/evals.md`: eight scenarios. Each has a fixture, a prompt and pass criteria:
  - GridField config on `ss5` vs `ss6`
  - a DataObject with `has_many` and a CMS field on `ss4`
  - an Extension on `ss3-nocomposer`
  - a template loop on `ss6`
  - a module change on `module-compat` (must avoid single-version APIs)
  - "postavi ss-version-aware" on a repo with a committed `CLAUDE.md`
  - an upgrade request on `upgrade-5-6`
  - a `⚠` block on startup

  Pass criteria name the specific class or namespace that must or must not appear, taken from the references.

- [ ] **Step 1:** Write `tests/evals.md`. Run each scenario once without the plugin and record the failures. That is the baseline.
- [ ] **Step 2:** Write SKILL.md.
- [ ] **Step 3:** Run all scenarios with the plugin installed locally (`/plugin marketplace add <repo path>`, `/plugin install youwilllikeit-dev@youwilllikeit`) via fresh Claude Code sessions or subagents. Expected: 8/8 pass. Iterate on SKILL.md, not on the references, unless a reference is factually missing an entry.
- [ ] **Step 4:** Run `bash tests/run.sh`. Expected: PASS.
- [ ] **Step 5:** Commit `feat: ss-version-aware skill + evals`.

---

### Task 12: Review gate and installation on both machines

**Files:**
- Modify: `README.md` (install, `init`, upgrade usage, uninstall: remove the block and the exclude line)

- [ ] **Step 1:** Hand Đorđe the review list: `references/ss3–6.md` and `migrations/*.md`, with the entry count per file. Stop until he approves. Apply his corrections and re-run `bash tests/run.sh`.
- [ ] **Step 2:** Push to the private repo `youwilllikeit/claude-skills`. Tag `v0.1.0`.
- [ ] **Step 3:** On macOS (firm machine) and on WSL, run `bash tests/run.sh` (this covers bash 3.2 and BSD utils on the Mac). Expected: PASS on both.
- [ ] **Step 4:** Install on both machines, run `init` on one real project per available major (including the big SS3 firm project), and check:
  - `git status` is clean
  - the block shows the correct version
  - a new VS Code session shows the block in `/memory`
- [ ] **Step 5:** Commit README and tag.
