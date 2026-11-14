# YouWillLikeIT – Claude Skills (private)

Private [Claude Code plugin marketplace](https://code.claude.com/docs/en/plugins/host-marketplace) with the skills YouWillLikeIT uses for client delivery and its own products.

## Install (Claude Code / VS Code extension, inside WSL)

Prerequisite: `git clone git@github.com:you-will-like-it/claude-skills.git` must work on the machine (SSH key or `gh auth login`). Claude Code uses those existing git credentials, non-interactively.

```text
/plugin marketplace add you-will-like-it/claude-skills
/plugin install ywli-site-optimizer@ywli-skills
```

Update later with `/plugin marketplace update ywli-skills`.

## Skills

| Plugin | Version | What it does |
|---|---|---|
| [ywli-site-optimizer](plugins/ywli-site-optimizer/README.md) | 0.1.0 | SilverStripe 6 audit and optimization: technical + content SEO (DE/BS/HR/SR), Lighthouse ≥90, WCAG 2.2 AA. Report → approval → PR + CMS drafts → verification. |

## Repository layout

```
.claude-plugin/marketplace.json      catalog (marketplace name: ywli-skills)
plugins/<plugin>/
  .claude-plugin/plugin.json         name, version, description
  README.md                          purpose, prerequisites, usage, changelog
  skills/<skill>/SKILL.md            instructions loaded by Claude
  skills/<skill>/scripts/            executable helpers
  skills/<skill>/templates/          files copied into client projects
```

## Adding a new skill

1. Create `plugins/<name>/` with `.claude-plugin/plugin.json`, `README.md` and `skills/<name>/SKILL.md`.
2. Add an entry to `.claude-plugin/marketplace.json` and a row to the table above.
3. Validate: `claude plugin validate .`
4. Bump `version` in both `plugin.json` and `marketplace.json` on every change, and add a changelog line in the plugin README.

## Rules

- No credentials, client data or audit results in this repo. Those live in `~/ywli-optimizer/clients/` on the working machine.
- Skills must not write to production or publish CMS content without a human step.
