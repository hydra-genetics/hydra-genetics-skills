# hydra-genetics-skills

Agentic skills for AI-assisted development on [hydra-genetics](https://github.com/hydra-genetics) —
a Snakemake-based multi-repository framework for building genomic analysis pipelines.

Each skill lives in its own directory with a `SKILL.md` and, optionally, a `references/`
subfolder for material that would otherwise bloat the main file.

## Skills

| Skill | Use when | Depends on |
|---|---|---|
| [`pipeline-creation`](./pipeline-creation/SKILL.md) | Scaffolding a brand-new pipeline from scratch — `Snakefile`, `common.smk`, all schema files | — |
| [`module-creation`](./module-creation/SKILL.md) | Scaffolding a new module | `pipeline-creation` (shared scaffold step) |
| [`rule-development`](./rule-development/SKILL.md) | Adding a single rule to an existing module — `.smk` skeleton, schema sync, `softwares.md`, DAG regen | `rule-development` is invoked per rule after `module-creation` |

## Structure

```
hydra-genetics-skills/
├── README.md
├── pipeline-creation/
│   └── SKILL.md
├── module-creation/
│   └── SKILL.md
└── rule-development/
    └── SKILL.md
```

## Usage

### Claude Code

**Project-wide (recommended for this repo)** — shared with anyone who clones a hydra-genetics repo alongside these skills:

```bash
mkdir -p .claude/skills
cp -r pipeline-creation module-creation rule-development .claude/skills/
```

**Personal (available across all your projects)**:

```bash
mkdir -p ~/.claude/skills
cp -r pipeline-creation module-creation rule-development ~/.claude/skills/
```

Or clone straight into the skills directory rather than copying after the fact:

```bash
git clone https://github.com/hydra-genetics/hydra-genetics-skills.git ~/.claude/skills/hydra-genetics-skills
```

Note this nests each skill one level deeper (`~/.claude/skills/hydra-genetics-skills/rule-development/SKILL.md`); some setups require skills directly inside the skills folder, so copying the three subfolders individually is the safer default.

Start a new session afterward — Claude Code picks up new skills at session start, not mid-session. Verify with `claude skills list` or by asking "what skills do you have available?"

Project skills (`.claude/skills/`) take precedence over personal skills (`~/.claude/skills/`) if the same skill name exists in both.

### Claude.ai

Go to **Settings → Capabilities → Skills → Upload skill**, and upload either a single `SKILL.md` or a zipped skill folder. Enterprise/Team owners can instead provision these org-wide from **Organization settings → Skills**, so every member gets them without a manual upload.

### Keeping skills up to date

Since these are copied rather than installed as a package, updates aren't automatic:

```bash
cd hydra-genetics-skills && git pull
cp -r pipeline-creation module-creation rule-development ~/.claude/skills/   # re-copy to refresh
```

## Roadmap

- `core/` — shared scaffolding knowledge, once a third skill needs what
  `pipeline-creation` currently provides to `module-creation`
- `modules/alignment/`, `modules/qc/`, etc. — per-module conventions
- `pipeline-composition/` — wiring existing modules together into a pipeline
- Cross-cutting CI/release and troubleshooting skills

## Conventions

- Never guess wrapper paths/versions, module tag versions, author/email
  values, container names, or resource defaults — always ask the user.
- Verify checklist items against real files on disk rather than assuming;
  hydra-genetics docs are occasionally stale relative to the `develop` branch.
- Validate each new or edited skill with a test prompt before considering it done.
