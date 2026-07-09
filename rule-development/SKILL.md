---
name: rule-development
description: Use for writing, reviewing, or scaffolding a Snakemake rule (.smk file) for a hydra-genetics module, or for the schema files (rules/config/resources.schema.yaml), softwares.md, or DAG files (docs/images/*.dot,*.svg) that accompany a rule. Trigger on "make/add a rule", "write a .smk file", scaffold a pipeline step, `hydra-genetics create-rule`, updating rule/config/resources schemas or the DAG, or reviewing a rule for hydra-genetics compliance — even without "hydra-genetics" named explicitly. Rules must always follow the full skeleton (input, output, params, log, benchmark, threads, resources, container, conda, message, one of wrapper/script/shell/run) — flag any missing section. Every new rule also needs matching entries in the three schema files, a softwares.md stub, and an updated DAG — treat a rule missing these as incomplete too.
---

# Writing hydra-genetics Rules (.smk)

## Why the skeleton matters

hydra-genetics modules are composed together into pipelines and run across very different environments (local, HPC clusters, cloud). Every rule needs to be independently configurable, benchmarkable, and reproducible without editing the rule itself — all configuration should flow through `config.yaml`, not be hardcoded. That's why every section below is mandatory, not optional boilerplate: skipping `benchmark`, for example, breaks the project's performance-tracking conventions across modules; skipping the `config.get(...)` fallback pattern in `resources` breaks portability across clusters with different default resources.

Treat the skeleton as a contract. When writing or reviewing a rule, check off every section below — an incomplete rule should be called out, not silently accepted.

## The skeleton

```python
rule example_rule:
    input:
        in_="module/example_rule/{sample}_{type}.suffix1",
    output:
        out=temp("module/example_rule/{sample}_{type}.suffix2"),
    params:
        extra=config.get("example_rule", {}).get("extra", ""),
    log:
        "module/example_rule/{sample}_{type}.suffix2.log",
    benchmark:
        repeat(
            "module/example_rule/{sample}_{type}.suffix2.benchmark.tsv",
            config.get("example_rule", {}).get("benchmark_repeats", 1),
        )
    threads: config.get("example_rule", {}).get("threads", config["default_resources"]["threads"])
    resources:
        mem_mb=config.get("example_rule", {}).get("mem_mb", config["default_resources"]["mem_mb"]),
        mem_per_cpu=config.get("example_rule", {}).get("mem_per_cpu", config["default_resources"]["mem_per_cpu"]),
        partition=config.get("example_rule", {}).get("partition", config["default_resources"]["partition"]),
        threads=config.get("example_rule", {}).get("threads", config["default_resources"]["threads"]),
        time=config.get("example_rule", {}).get("time", config["default_resources"]["time"]),
    container:
        config.get("example_rule", {}).get("container", config["default_container"])
    conda:
        "../envs/example_tool.yaml"
    message:
        "{rule}: Do stuff on {input.in_}"
    wrapper:
        "some wrapper path or command"
```

> Note: `in` is a reserved word in Python, so the input keyword in real rules is usually written as `in_` (as above) or given a more descriptive name (e.g. `bam=`). Flag plain `in=` as a likely typo if you see it in a rule.

> Note: When `hydra-genetics create-rule` starts a **new** `.smk` file (the first rule for a given tool), it also prepends an author/copyright/email/license header:
> ```python
> __author__ = "{{ author }}"
> __copyright__ = "Copyright {{ year }}, {{ author }}"
> __email__ = "{{ email }}"
> __license__ = "GPL-3"
> ```
> If you're **adding another rule to an existing `.smk` file** (e.g. a second samtools rule in `samtools.smk`), don't repeat this header — only the first rule in each file carries it. If you're unsure whether the target `.smk` file already exists, check before deciding whether to include the header.

## Section-by-section guide

**`input` / `output`** — Follow the `module/rule_name/{sample}_{type}.suffix` path convention. `{sample}` and `{type}` are the standard wildcards used throughout hydra-genetics; don't invent new wildcard names for concepts these already cover. Wrap intermediate files that shouldn't persist in `output` with `temp(...)`.

**`params`** — Every tunable parameter must be read via `config.get("<rule_name>", {}).get("<param>", <default>)`. This is the fallback pattern: if the user hasn't set anything in `config.yaml` under this rule's name, the rule still runs with a sane default.

**`log`** — One log file per rule invocation, following the same path convention as `output` with a `.log` suffix.

**`benchmark`** — Always use `repeat(path, n)`, where `n` comes from `config.get("<rule_name>", {}).get("benchmark_repeats", 1)`. This keeps benchmarking consistent and user-configurable across every rule in every module.

**`threads`** — Read from config with a fallback to `config["default_resources"]["threads"]`. This value should match the `threads` entry duplicated inside `resources` below (Snakemake requires `threads` at the top level, but hydra-genetics convention also mirrors it into `resources` for schedulers that read resource dicts).

**`resources`** — Five keys are standard: `mem_mb`, `mem_per_cpu`, `partition`, `threads`, `time`. Each follows the same two-level fallback: rule-specific config, then `config["default_resources"]`. Don't drop any of the five even if a rule seems simple — schedulers on HPC clusters expect all of them to be present.

**`container`** — Falls back to `config["default_container"]` if the rule doesn't specify its own. Only override this when the rule needs a tool not present in the default container.

**`conda`** — Points to a `.yaml` env file, conventionally at `../envs/<tool_name>.yaml` relative to the rule file. One env file per tool, named for the tool, not the rule.

**`message`** — A short, human-readable status line, conventionally `"{rule}: <what it does> on {input.<key>}"`. This is what streams to the console during a run, so keep it terse.

**`wrapper` / `script` / `shell` / `run`** — Exactly one of these four. Preference order in hydra-genetics is generally: use `wrapper` if a suitable Snakemake wrapper exists, `script` for custom Python/R logic that's more than a one-liner, `shell` for a direct command line, and `run` only rarely (it can't be distributed/cached the way the others can).

**Choosing which directive to use:** Never guess a wrapper path or version. If the user hasn't specified which wrapper to use, ask them directly which wrapper (and version) they want — don't invent a `snakemake-wrappers` path/version from memory, since these change over time and a wrong guess silently breaks the rule. If the user doesn't know of a suitable wrapper or says there isn't one, default to `shell` as the sensible fallback rather than leaving it unresolved or fabricating a `script`/`wrapper` path.

## Keeping schemas in sync

Every new rule needs matching entries in three schema files plus a docs stub — not just the `.smk` rule itself. The real `hydra-genetics create-rule` CLI generates all of this automatically; when writing or reviewing a rule by hand (or simulating what the CLI would do), reproduce the same four artifacts:

**1. `workflow/schemas/rules.schema.yaml`** — one entry per rule, keyed by rule name, with placeholder `input`/`output` property blocks:

```yaml
  <rule_name>:
    type: object
    description: input and output parameters for <rule_name>
    properties:
      input:
        type: object
        description: list of inputs
        properties:
          input1:
            type: string
            description: description input1
      output:
        type: object
        description: list of outputs
        properties:
          output1:
            type: string
            description: description output1
```

The generated `input1`/`output1` keys are placeholders — **always rename them to match the actual keys used in the rule's `input:`/`output:` block** (e.g. `bam`, `vcf`) and write a real one-line description for each. Leaving `input1`/`output1` in place is a sign the schema wasn't finished.

**2. `workflow/schemas/config.schema.yaml`** — one entry per rule with the three standard overridable params:

```yaml
  <rule_name>:
    type: object
    description: parameters for <rule_name>
    properties:
      benchmark_repeats:
        type: integer
        description: set number of times benchmark should be repeated
      container:
        type: string
        description: name or path to docker/singularity container
      extra:
        type: string
        description: parameters that should be forwarded
```

If the rule's `params:` block defines anything beyond `extra` (a rule-specific tunable), add a matching property here by hand — the CLI only pre-populates the three standard ones.

**3. `workflow/schemas/resources.schema.yaml`** — one entry per rule with the five standard resource keys (`mem_mb`, `mem_per_cpu`, `partition`, `threads`, `time`), mirroring `default_resources`. This one rarely needs manual edits beyond confirming it was added.

**4. `docs/softwares.md`** (or the module's equivalent) — a doc stub per tool:

```markdown
## [<name>](url_to_tool)
Introduction to <name>

### :snake: Rule
#SNAKEMAKE_RULE_SOURCE__<file>_<rule_name>#

#### :left_right_arrow: input / output files
#SNAKEMAKE_RULE_TABLE__<file>_<rule_name>#

### :wrench: Configuration
#### Software settings (`config.yaml`)
#CONFIGSCHEMA__<rule_name>#

#### Resources settings (`resources.yaml`)
#RESOURCESSCHEMA__<rule_name>#
```

The `#...#` tags are placeholders resolved at doc-build time by pulling live from the rule source and the schema files above — meaning the descriptions you write into the schemas are what actually shows up in the rendered docs. Fill in `url_to_tool` and the tool introduction by hand; the tags themselves shouldn't be edited.

**Ordering:** all three schema files are appended to, not inserted alphabetically. Every generated entry carries the comment `# Entry added using Hydra-Genetics CLI - please move it into alphabetically sorted order` — treat that as a literal to-do, not decoration. Move the new entry into alphabetical position among existing rule entries before considering the schema update done. This requires opening the actual schema file and looking at what's already there — a generated entry can't be judged "correctly ordered" in isolation.

**5. `docs/images/*.dot` and `docs/images/*.svg`** — the rule graph (DAG) files. A new rule adds a node to the pipeline's DAG, so the `.dot` source and its rendered `.svg` (e.g. `images/rulegraph.svg`) need to be regenerated to include it — typically via `snakemake --rulegraph | dot -Tsvg > images/rulegraph.svg` (or the module's equivalent target). Don't forget these just because they're diagrams rather than code: a rule that's wired into `common.smk`/`Snakefile` but missing from the DAG is a stale-docs bug, and it's easy to miss since nothing fails at runtime if it's skipped.

## Checklist before submitting a rule

Several items below can't be confirmed from the generated text alone — they require looking at the actual files in the repo. Don't check them off by assumption; open the real file and verify.

- [ ] All 11 sections present (input, output, params, log, benchmark, threads, resources, container, conda, message, and one of wrapper/script/shell/run)
- [ ] Every tunable value uses the `config.get("<rule_name>", {}).get(...)` fallback pattern — nothing hardcoded
- [ ] `resources` includes all five standard keys, each with a `default_resources` fallback
- [ ] `benchmark` uses `repeat(...)` with a configurable repeat count
- [ ] Exactly one of `wrapper` / `script` / `shell` / `run` is set — wrapper path/version confirmed with the user, not guessed; `shell` used if no wrapper is known
- [ ] `conda` env file follows the `../envs/<tool_name>.yaml` convention
- [ ] Wildcards used are the standard `{sample}`, `{type}` unless there's a documented reason for a new one
- [ ] **(verify against the actual `.tests/` directory)** Rule has at least one corresponding test — check what's actually there, don't assume it exists because the rule does
- [ ] `rules.schema.yaml` has an entry for this rule, with `input1`/`output1` placeholders renamed to the real input/output keys and real descriptions written
- [ ] `config.schema.yaml` has an entry for this rule; any custom `params` beyond `extra` have matching properties added by hand
- [ ] `resources.schema.yaml` has an entry for this rule
- [ ] `softwares.md` has a doc stub for this tool, with `url_to_tool` and the introduction filled in
- [ ] **(verify against the actual DAG files)** `docs/images/*.dot` and the rendered `*.svg` have been regenerated to include the new rule as a node in the pipeline graph
- [ ] **(verify against the actual schema files)** New entries in all three schema files are moved into alphabetical order relative to the *existing* entries in each file — this can't be confirmed without opening the real files, since a freshly generated entry always looks correct in isolation

## Worked example

A rule that sorts a BAM file with samtools, following the skeleton. (In practice, confirm the wrapper path/version with the user first — the one below is illustrative.)

```python
rule samtools_sort:
    input:
        bam="alignment/samtools_sort/{sample}_{type}.bam",
    output:
        bam=temp("alignment/samtools_sort/{sample}_{type}.sorted.bam"),
    params:
        extra=config.get("samtools_sort", {}).get("extra", ""),
    log:
        "alignment/samtools_sort/{sample}_{type}.sorted.bam.log",
    benchmark:
        repeat(
            "alignment/samtools_sort/{sample}_{type}.sorted.bam.benchmark.tsv",
            config.get("samtools_sort", {}).get("benchmark_repeats", 1),
        )
    threads: config.get("samtools_sort", {}).get("threads", config["default_resources"]["threads"])
    resources:
        mem_mb=config.get("samtools_sort", {}).get("mem_mb", config["default_resources"]["mem_mb"]),
        mem_per_cpu=config.get("samtools_sort", {}).get("mem_per_cpu", config["default_resources"]["mem_per_cpu"]),
        partition=config.get("samtools_sort", {}).get("partition", config["default_resources"]["partition"]),
        threads=config.get("samtools_sort", {}).get("threads", config["default_resources"]["threads"]),
        time=config.get("samtools_sort", {}).get("time", config["default_resources"]["time"]),
    container:
        config.get("samtools_sort", {}).get("container", config["default_container"])
    conda:
        "../envs/samtools.yaml"
    message:
        "{rule}: Sort {input.bam}"
    wrapper:
        "v1.21.0/bio/samtools/sort"
```

When reviewing or generating a rule, walk through the checklist above explicitly rather than eyeballing it — missing sections are easy to miss on a quick read.