---
name: ss-version-aware
description: Keeps SilverStripe code on the project's exact major version (SS3, SS4, SS5, SS6) and never mixes APIs across versions. It detects the version from composer.lock or framework/, loads the verified API reference for that major, checks vendor/ for anything the reference does not cover, and runs 4→5 and 5→6 upgrades with a re-scannable checklist. Use it for any SilverStripe/Silverstripe PHP, YAML or .ss template work, including writing or reviewing a DataObject, Extension, Controller/PageController, GridField, ModelAdmin, BuildTask, Elemental BaseElement, module code, form, config or template. Use it for SS upgrades and migrations (upgrade 5→6, nadogradnja, migracija na SS6), when the ss-version-aware block in CLAUDE.md shows a ⚠ line, and when the user says "postavi ss-version-aware" (setup). Trigger words (bs/en) — SilverStripe, Silverstripe, SS3, SS4, SS5, SS6, DataObject, Extension, GridField, Elemental, BaseElement, modul, module, template .ss, upgrade, nadogradnja, postavi ss-version-aware.
---

# ss-version-aware

Goal: every SilverStripe API you write or suggest exists in **this** project's major version. Your memory of SilverStripe is not reliable here, because it mixes SS4/5/6 and above all SS5 and SS6. The references and the project's source code are reliable.

Paths: scripts live in `${CLAUDE_PLUGIN_ROOT}/scripts/` and references in `${CLAUDE_PLUGIN_ROOT}/skills/ss-version-aware/references/`. In this file, `references/...` means that folder. Run every script from the project root, or pass the root as the last argument.

## 1. Know the version (always first)

- **A block is in context** (between `<!-- ss-version-aware:start -->` and `<!-- ss-version-aware:end -->` in `CLAUDE.md` or `CLAUDE.local.md`). Compare its `lock:` line with `git hash-object composer.lock`, or with `nolock` when there is no `composer.lock`. If they differ, or if `composer.json` was edited in this session (e.g. a constraint bump that starts upgrade mode), run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/block.sh" refresh` and re-read the block.
- **The block has a `⚠` line** (`⚠ Verzija promijenjena (A → B) — pokreni ss-version-aware.`), or the session context says `ss-version-aware: verzija promijenjena`. Before any other work:
  1. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/block.sh" refresh`.
  2. Tell the user in one line. Major change: "Verzija projekta je promijenjena A → B; od sada koristim SSB referencu." Mode-only change (e.g. `normal → upgrade`): "Režim projekta je promijenjen: normal → upgrade (cilj SS6)." with the real modes and target. This notice must reach the user in your reply. Write it as text before you call `ack`, and keep it in the final reply too.
  3. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/block.sh" ack`, which removes the `⚠` line. Run it only after you have told the user.
  4. Load the new reference (§2). If the mode changed to `upgrade`, offer the upgrade workflow (§7).
- **No block.** Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/detect.sh"`. It prints `KEY=value` lines and always exits 0. The keys you use are `SS_PROJECT` (`project`/`module`/`none`), `SS_VERSION`, `SS_MAJOR`, `SS_MODE` (`normal`/`upgrade`/`compat`), `SS_TARGET_MAJOR`, `SS_COMPAT_MAJORS`, `SS_VENDOR_MISMATCH` and `LOCK_HASH`. Then see §4.

Re-check the version once per session and whenever `composer.lock` may have changed. Never assume it.

## 2. Which reference to read

Read each `ss<N>.md` whole before writing code. They are ≤350 lines and list only what differs between versions. The migration maps are longer. Do not read them whole: read the `## Rector` section, plus each entry by its ID (`### M56-015`), which the checklist links to.

| Mode | Read |
|---|---|
| `normal`, SS 3 | `references/ss3.md` (no map exists below 4→5) |
| `normal`, SS 4 | `references/ss4.md` |
| `normal`, SS 5 | `references/ss5.md` |
| `normal`, SS 6 | `references/ss6.md` |
| `compat` (module, e.g. `^5 \|\| ^6`) | **every** `references/ss<N>.md` for N in `SS_COMPAT_MAJORS`. The map between those majors (`references/migrations/5-to-6.md` for 5+6, `references/migrations/4-to-5.md` for 4+5) shows exactly what differs. |
| `upgrade` X → Y | the **target** reference `references/ss<Y>.md` for all new code, plus every map in the chain: `references/migrations/4-to-5.md` (4→5), `references/migrations/5-to-6.md` (5→6). Read `ss<X>.md` only to understand old code. |
| `SS_MAJOR=unknown` (e.g. `dev-main`) | no reference yet. Tell the user the major is unknown and ask which one it is. You may also read the `branch-alias` in `vendor/silverstripe/framework/composer.json`. Never default to the newest version. |
| `SS_PROJECT=none` | no reference. This is not a SilverStripe root. Ask for the project root, or run `detect.sh <dir>` on the right subfolder. |

If `SS_VENDOR_MISMATCH=1`, the installed `vendor/` major (`SS_MAJOR`) differs from the lock (`SS_TARGET_MAJOR`). Code runs against `vendor/`, so tell the user. Usually they need `composer install`, or the project is mid-upgrade.

Map entries have IDs such as `M56-015` and `M45-078`. Each `### M56-015` heading in the map holds the old and new form and the source.

## 3. Hard rules while writing code

1. **Use only what the loaded reference shows.** Check every `use` line, base class, hook name, method signature, YAML key and template feature against the reference for this major. In compat mode, check against every reference listed.
2. **Anything not in the reference must be checked in source before you use it.** Grep for the class or method:
   ```bash
   grep -rnw "class GridFieldConfig_Base" vendor/silverstripe/
   grep -rn "function addFieldsToTab" vendor/silverstripe/framework/src/
   ```
   An SS3 project without Composer has its core in `framework/ cms/` at the project root, not in `vendor/`, so grep there: `grep -rn "class SS_HTTPRequest" framework/ cms/`.
   Use the API only if the grep finds it with the signature you need.
3. **`vendor/` is missing**, or the SS3 `framework/` has no such class. Say so plainly: "`vendor/` ne postoji, pa ne mogu provjeriti `X` u izvoru." Ask whether to run `composer install` (`ddev composer install` under DDEV), or offer an alternative that the reference covers. You may still write the parts the reference covers, but name every unverified API explicitly. Never use one silently.
4. **Trust the reference and the source over the docs and over memory.** The references were checked against the source. The upstream docs on docs.silverstripe.org have known errors: docs-5 says `or`/`and` work in template conditions, but the parser rejects them, so use `||`/`&&`. When the docs, your memory and the reference disagree, the reference and `vendor/` win.
5. **Before you finish, self-check the diff.** Go through the "Česte greške" section of each loaded reference and grep your changed files for every "Ne:" form. Never write a "Ne:" form into a changed file, not even in a comment or docblock (e.g. no "replaces DataExtension"). The self-check grep must return zero hits. Typical leaks:
   - into SS5/SS4: `SilverStripe\Model\`, `Core\Validation\`, `Forms\Validation\`, `BuildTask::execute()`
   - into SS6: `SilverStripe\ORM\ArrayList`, `ORM\ValidationResult`, `Forms\RequiredFields`, `DataExtension`
   - into SS3: any `namespace`/`use SilverStripe\`, `PageController`, `protected function init()`
6. **Compat mode:** use only APIs that exist with the same name and namespace in every listed major. If that cannot work, write version-conditional code with `class_exists(...)`/`method_exists(...)` and both FQCNs. Where a hook was renamed, implement both hook names, e.g. `validate()` for 5 and `updateValidate()` for 6, with an untyped parameter. Say in the reply that the code targets all listed majors.
7. Never edit `vendor/`, `composer.lock`, or any core directory such as `framework/` or `cms/`.

## 4. Project not set up (no block)

Use the `detect.sh` result for this session only. Write nothing. Do not run `block.sh init`, and do not create or edit `CLAUDE.md`, `CLAUDE.local.md` or `.git/info/exclude`. At the end of your reply, add one line, once per session:

> Projekat nije uključen u ss-version-aware — reci "postavi ss-version-aware" da upišem lokalni blok (ne ide u git).

## 5. Setup ("postavi ss-version-aware")

Do this only when the user asks explicitly. Run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/block.sh" init`. Then report in one or two lines the version and the `TARGET=` file it printed:

- `TARGET=CLAUDE.md`: `CLAUDE.md` was untracked or absent. The block is in it and the file is added to `.git/info/exclude`.
- `TARGET=CLAUDE.local.md`: `CLAUDE.md` is tracked (shared), so it was left untouched. The block went to `CLAUDE.local.md`, which is excluded the same way.
- `NOTE=no-git`: this is not a git repo, so nothing was excluded. Mention this.
- `NOTE=agents-md-imported`: the repo has `AGENTS.md` (or `.claude/AGENTS.md`) and no `CLAUDE.md`. A new `CLAUDE.md` would stop Claude Code from reading `AGENTS.md`, so init wrote `@AGENTS.md` as its first line. Mention this. An existing file is never given the import.

Do not paste the block or the reference into the reply. From then on, the SessionStart hook refreshes the block whenever `composer.lock` changes.

`block.sh show` prints the block without writing anything. Use it when the user only wants to see it.

## 6. Exit codes of block.sh

| Exit | Meaning | What to do |
|---|---|---|
| 0 | done. `refresh`/`ack` with no block is a silent no-op. | continue |
| 2 | not a SilverStripe project (`show`/`init`), or no such directory | tell the user; check that you are in the project root; do not retry blindly |
| 3 | the target file is tracked by git, so the write was refused | never edit or untrack the tracked file yourself. Explain, and let the user decide, e.g. remove it from git themselves or work without a block. |
| 64 | usage error | fix the command |

## 7. Upgrade workflow (X → Y)

You are in this workflow when the block or `detect.sh` shows `režim: upgrade` / `SS_MODE=upgrade`, or when the user says something like "radim upgrade 5→6". Write new code only for Y. Change old code according to the map.

1. **Rector first, and only if the map lists it.** At the very start, check the `## Rector` section of each map in the chain. If one exists, offer it in one line as an optional first pass. Write the offer as assistant text BEFORE your first `scan-upgrade.sh` call; an offer only in the final reply does not count. `references/migrations/5-to-6.md` lists `wernerkrauss/silverstripe-rector` (`SilverstripeLevelSetList::UP_TO_SS_6_0`). `references/migrations/4-to-5.md` has no Rector section, so offer nothing for 4→5. Never install or run Rector without consent. If the user has explicitly asked you to work the checklist, do not wait for an answer: make the offer and continue with step 2 in the same turn. The checklist still governs.
2. **Scan:** `bash "${CLAUDE_PLUGIN_ROOT}/scripts/scan-upgrade.sh" --from 5 --to 6`. Use the real X and Y. For 4→6 it is one checklist in two phases, and the 5→6 phase unlocks when the lock shows 5.x. The script writes `.claude/ss-upgrade-checklist.md`, which is git-excluded and regenerated on every scan, so do not keep notes in it. Add `--no-exclude` only if the user wants the checklist committed (private projects). Each item shows the matched line after the map link. While the checklist has unticked items, the block shows `Upgrade checklista: N otvorenih stavki (+M za ručni pregled)`. Stdout ends with `MANUAL=<n>` and then `OPEN=<n>`, which is always the last line. Exit 0 means no open items, 1 means open items, 2 means a usage or map error. `MANUAL` never affects the exit code.
3. **Work the checklist.** Each item has a map ID. Read that `### M..-...` entry in the map and apply the new form from the map and the target reference. Map entries without a grep pattern are listed per phase under `## Ručni pregled (nema grep obrasca)`. They are not counted in `OPEN`. In your reply, report the `MANUAL=` count and tell the user those items need a manual check, which they tick by hand (the tick survives rescans). Tick one yourself only once you have verified it in the code.
4. **Re-scan after each batch of edits.** An item is closed only when the scan no longer finds it. Report the new `OPEN=` count.
5. **Never declare the upgrade done while `OPEN>0`, or while `composer.lock` still shows X.** `composer update` belongs to the user (`ddev composer update` under DDEV). Do not hand-edit `composer.lock`. Ask before changing the constraint in `composer.json`.
6. **Finish:** once the lock shows Y and a re-scan gives `OPEN=0`, run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/block.sh" refresh`. The block returns to `režim: normal` for Y, and because the major changed it gets a `⚠` line: tell the user (§1 notice), then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/block.sh" ack`. From then on use only `references/ss<Y>.md`.

Upgrades from SS3 are not covered, because there is no 3→4 map. Say so, and do not invent mappings.
