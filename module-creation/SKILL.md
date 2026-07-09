---
name: module-creation
description: Use this skill when the user wants to create a brand-new hydra-genetics module from scratch and populate it with one or more rules — e.g. "create a module for X", "make a new hydra-genetics module with rules for samtools and picard", "scaffold a qc module". This is distinct from pipeline-creation (which builds an end-to-end pipeline meant to import modules) and from rule-development (which this skill hands off to for each rule once the module exists). A module is scaffolded with the exact same CLI command and folder structure as a pipeline — see pipeline-creation for that shared detail — but the intent and what happens immediately afterward differ.
---

# Creating a hydra-genetics Module from Scratch

## Same scaffold as a pipeline

A module is scaffolded with the identical command and template as a pipeline — see the `pipeline-creation` skill for the full command reference, required flags, folder structure, and the mandatory `Snakefile`/`common.smk`/schema shape. Don't duplicate that content here; the scaffold step is the same:

```bash
hydra-genetics create-pipeline -n <name> -d "<description>" -a "<author>" -e <email> -g <git_user> [OPTIONS]
```

(Yes, the command is literally `create-pipeline` even when building a module — the CLI's own `short_help` describes it as creating a "bare bone project, pipeline or module". Don't guess a different command name.)

Never invent the required flag values (name, description, author, email, git-user) — ask the user.

## What's different for a module

A **module** is a focused collection of rules for one tool-domain (e.g. `alignment`, `qc`, `snv_indels`, `annotation`, `cnv_sv`) meant to be imported by pipelines via Snakemake's `module:` mechanism — not run end-to-end on its own in production. This changes what matters after scaffolding:

**1. Module naming** — short, lowercase, underscore-separated, and describing the tool-domain rather than a specific disease/use-case (contrast with a pipeline name like a cancer-panel name). Confirm the name with the user if it's ambiguous whether they mean a module or a pipeline — the scaffold is identical, so getting this label right is about intent, not mechanics.

**2. The generated `rule all` / `compile_output_file_list` mainly serves the module's own standalone testing** (e.g. its `.tests/integration` run), not consumption by pipelines. When a pipeline later imports this module, it typically does:

```python
module <module_name>:
    snakefile:
        github(
            "hydra-genetics/<module_name>",
            path="workflow/Snakefile",
            tag="<version>",
        )
    config:
        config

use rule * from <module_name> as <module_name>_*
```

— which pulls in the module's individual rules, **not** its `rule all`. So the module's own `rule all`/output-file plumbing doesn't need to anticipate every possible downstream pipeline; it just needs to validate that the module's rules work end-to-end in isolation.

**3. Immediately after scaffolding, hand off to `rule-development` for each rule the user wants.** This skill doesn't duplicate rule-writing logic — once the bare module exists, adding rules (and their `rules.schema.yaml`/`config.schema.yaml`/`resources.schema.yaml`/`softwares.md`/DAG entries) is exactly the `rule-development` skill's job, called once per rule:

```bash
hydra-genetics create-rule -c <command> -t <tool> -m <module_name> -a <author> -e <email>
```

If the user asked for "a module with rules for samtools sort and samtools stats," that's: one `create-pipeline` scaffold call, then two passes through `rule-development` (one per rule) — don't try to write the rules directly in this skill.

**4. README's usage snippet should reflect the real module name.** The scaffolded `README.md` includes a generic "Usage" section showing how another pipeline would import this module (the `module:`/`use rule *` block above, with a placeholder name) — update it with the module's actual name once known, and keep the "Output files" table in the README in sync with whatever rules get added (this table should list the module's actual output files, not stay as the generated `{{ short_name }}/PATH/FILE` / `DESCRIPTION` placeholder row).

## Checklist

- [ ] Required scaffold flags (name, description, author, email, git-user) confirmed with the user, not guessed
- [ ] Module name reflects a tool-domain, not a disease/pipeline use-case — confirm with the user if ambiguous
- [ ] **(verify against the actual output directory)** Scaffold produced the expected structure — check the filesystem, don't assume from command syntax
- [ ] For each rule the user wants in the module, `rule-development` was invoked separately — rules were not hand-written inline in this skill
- [ ] README's "Usage" module-import snippet uses the real module name, not the generated placeholder
- [ ] README's "Output files" table reflects the module's actual rules/outputs once added, not the generated placeholder row
- [ ] Git remote add/push only performed after explicit user confirmation