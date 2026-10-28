---
name: pipeline-creation
description: Use this skill when the user wants to create a brand-new hydra-genetics pipeline from scratch — scaffolding the folder structure, the mandatory Snakefile/common.smk shape, schemas, and docs, then optionally wiring in existing modules. Trigger on requests like "create a new pipeline", "start a new hydra-genetics pipeline", "scaffold a pipeline for X", or "run hydra-genetics create-pipeline". This is distinct from creating a module (see module-creation) and from adding a single rule (see rule-development). A freshly scaffolded pipeline is not complete just because the CLI ran — the Snakefile, common.smk, and schemas must match the mandatory shape described here, and module imports should only be added if the user has specified which modules/rules to import; otherwise the Snakefile stays at its minimal default shape.
---

# Creating a hydra-genetics Pipeline from Scratch

## Check for existing modules before scaffolding

Before creating any new rule, module, or custom script as part of a pipeline build,
**check whether an existing hydra-genetics module already provides that functionality.**
This applies especially at the "create a pipeline from scratch" stage, where there is
no local repo to grep — the relevant module may live in a completely different
hydra-genetics repository that isn't in front of you.

### Steps

1. **Identify the tool/functionality being requested.** Extract the concrete keywords
   from the user's request (tool names, file formats, output types — e.g. "cnvkit",
   "html report", "bwa", "cram"). Don't just match on the literal words used; also
   consider synonyms and the underlying purpose (e.g. "coverage report" and "QC
   summary" may point to the same module).

2. **Check the hydra-genetics GitHub org for a matching module** before writing
   anything. Use:
```bash
   git clone --depth 1 https://github.com/hydra-genetics/hydra-genetics.git
```
   and inspect the module list / compatible-modules documentation, or list the org's
   repos directly (`gh repo list hydra-genetics` or the GitHub API) to check for a
   repo name or description matching the requested functionality.
   Do not rely on memory or training data for "which modules exist" — this list
   changes over time and must be checked against the live org, same as CLI commands
   and templates elsewhere in this skill set.

3. **If a plausible match is found, stop and confirm with the user** before writing
   any custom rule or script. Say what you found and ask directly, e.g.:
   > "hydra-genetics already has a `cnvkit` module that includes an HTML report rule
   > (`hydra-genetics/cnv_sv`, rule `cnvkit_report`). Do you want to import that
   > module instead of writing a custom rule for this?"
   Never silently assume the match is right or wrong — the user knows their pipeline's
   requirements better than a name/description match does.

4. **If no match is found**, say so explicitly ("I checked the hydra-genetics org and
   didn't find an existing module for X") before proceeding to scaffold a custom
   rule. This keeps the check auditable rather than invisible.

5. **If a match is found and confirmed**, follow the module-import steps elsewhere
   in this skill (or in `module-creation`) rather than duplicating the module's rules.

This check is a stopgap for cross-repo visibility until `hydra-genetics-graph` exists.
Once the graph's CI/CD pipeline is live and queryable, prefer querying it directly
over listing/cloning the org by hand — but until then, this manual check is
mandatory, not optional, at the start of any from-scratch pipeline build.

## Correction versus older documentation

The hydra-genetics readthedocs page for pipeline creation currently says the CLI command is `hydra-genetics create-module`. **That's stale.** Checking the actual current CLI source (the `develop` branch, matching the latest release), the real command is:

```bash
hydra-genetics create-pipeline
```

This one command scaffolds both pipelines and modules (its `short_help` literally says "create bare bone project, pipeline or module") — same template, same folder structure, regardless of which you're building. Use `create-pipeline`, not `create-module`.

## Required flags — ask, don't guess

```bash
hydra-genetics create-pipeline -n <name> -d "<description>" -a "<author>" -e <email> -g <git_user> [OPTIONS]
```

| Flag | Meaning | Required? |
|---|---|---|
| `-n, --name` | Pipeline name | Yes |
| `-d, --description` | Short description | Yes |
| `-a, --author` | Main author name(s) | Yes |
| `-e, --email` | Author email(s) | Yes |
| `-g, --git-user` | Git username | Yes |
| `--version` | Initial version (default `0.0.1`) | No |
| `--min-snakemake-version` | Min snakemake version (default `6.8.0`) | No |
| `--no-git` | Skip local git repo init | No |
| `-f, --force` | Overwrite existing output dir | No |
| `-o, --outdir` | Output directory (default: pipeline name) | No |

Never invent values for the four required flags (name, description, author, email, git-user) — ask the user, the same way rule-development asks about wrapper choice rather than guessing.

## After scaffolding: push to git

The CLI initializes a local git repo (`main` + `develop` branches) unless `--no-git` was passed, but does **not** push anywhere. Pushing to a remote is an action that needs the user's explicit confirmation:

```bash
cd <outdir>
git remote add origin git@github.com:<git_user>/<repo_name>.git
git push --all origin
```

## The mandatory pipeline shape

A scaffolded pipeline isn't "done" just because the command ran — three files have a **mandatory shape** that must be present and correct: `workflow/Snakefile`, `workflow/rules/common.smk`, and the four schema files under `workflow/schemas/`. These are generated by the CLI, but if writing or reviewing one by hand, reproduce them exactly.

### `workflow/Snakefile`

```python
__author__ = "<author>"
__copyright__ = "Copyright <year>, <author>"
__email__ = "<email>"
__license__ = "GPL-3"


# Include pipeline specific rules
include: "rules/common.smk"


# 'All' rule, must be specified before any other modules are
# included, since they also contain 'All' rule
rule all:
    input:
        compile_output_file_list,


# Include modules
```

This is the **default, minimal shape**. The authorship header, the `include: "rules/common.smk"` line, and the `rule all` block are mandatory and always present — don't drop any of them.

**Module imports go under the trailing `# Include modules` comment, and only if the user has told you which modules/rules to import.** If the user hasn't specified any modules, leave the Snakefile exactly as above — don't invent module imports or guess which modules a pipeline "should" have. When the user does specify modules, add blocks like:

```python
module alignment:
    snakefile:
        github(
            "hydra-genetics/alignment",
            path="workflow/Snakefile",
            tag="v0.4.0",
        )
    config:
        config

use rule * from alignment as alignment_*
```

or, for specific rules only:

```python
use rule bwa_mem from alignment as alignment_bwa_mem
```

Never guess a module's release `tag` — ask the user which version, same as never guessing a wrapper version in rule-development. If two imported rules from different modules produce the same output, Snakemake can't disambiguate; resolve with `ruleorder:` in the Snakefile (e.g. `ruleorder: snv_indels_bgzip > misc_bgzip`) — but only add this if the user hits (or anticipates) that specific conflict, not preemptively.

### `workflow/rules/common.smk`

This file's job is config/sample/unit validation and building the pipeline's output-file list. The mandatory shape:

```python
__author__ = "<author>"
__copyright__ = "Copyright <year>, <author>"
__email__ = "<email>"
__license__ = "GPL-3"

import itertools
import numpy as np
import pathlib
import pandas as pd
import yaml
from datetime import datetime
from snakemake.utils import validate
from snakemake.utils import min_version

from hydra_genetics.utils.resources import load_resources
from hydra_genetics.utils.samples import *
from hydra_genetics.utils.units import *

from hydra_genetics.utils.misc import export_config_as_file
from hydra_genetics.utils.software_versions import add_version_files_to_multiqc
from hydra_genetics.utils.software_versions import add_software_version_to_config
from hydra_genetics.utils.software_versions import export_pipeline_version_as_file
from hydra_genetics.utils.software_versions import export_software_version_as_file
from hydra_genetics.utils.software_versions import get_pipeline_version
from hydra_genetics.utils.software_versions import touch_pipeline_version_file_name
from hydra_genetics.utils.software_versions import touch_software_version_file
from hydra_genetics.utils.software_versions import use_container

min_version("<min_snakemake_version>")

### Set and validate config file

if not workflow.overwrite_configfiles:
    sys.exit("At least one config file must be passed using --configfile/--configfiles, by command line or a profile!")

try:
    validate(config, schema="../schemas/config.schema.yaml")
except WorkflowError as we:
    if not we.args[0].lower().startswith("error validating config file"):
        raise
    error_msg = "\n".join(we.args[0].splitlines()[:2])
    parent_rule_ = we.args[0].splitlines()[3].split()[-1]
    if parent_rule_ == "schema:":
        sys.exit(error_msg)
    else:
        schema_hierarchy = parent_rule_.split()[-1]
        schema_section = ".".join(re.findall(r"\['([^']+)'\]", schema_hierarchy)[1::2])
        sys.exit(f"{error_msg} in {schema_section}")

date_string = datetime.now().strftime('%Y%m%d--%H-%M-%S')
pipeline_version = get_pipeline_version(workflow, pipeline_name="<short_name>")
version_files = touch_pipeline_version_file_name(pipeline_version, date_string=date_string, directory="results/versions/software")
if use_container(workflow):
    version_files.append(touch_software_version_file(config, date_string=date_string, directory="results/versions/software"))
add_version_files_to_multiqc(config, version_files)

onstart:
    export_pipeline_version_as_file(pipeline_version, date_string=date_string, directory="results/versions/software")
    # Without containers there is no software info to add, export the config as is
    update_config = config
    if use_container(workflow):
        update_config, software_info = add_software_version_to_config(config, workflow, False)
        export_software_version_as_file(software_info, date_string=date_string, directory="results/versions/software")
    export_config_as_file(update_config, date_string=date_string, directory="results/versions")

### Read and validate resources file

config = load_resources(config, config["resources"])
validate(config, schema="../schemas/resources.schema.yaml")

### Read and validate samples file

samples = pd.read_table(config["samples"], dtype=str).set_index("sample", drop=False)
validate(samples, schema="../schemas/samples.schema.yaml")

### Read and validate units file

units = (
    pd.read_table(config["units"], dtype=str)
    .set_index(["sample", "type", "flowcell", "lane", "barcode"], drop=False)
    .sort_index()
)
validate(units, schema="../schemas/units.schema.yaml")

### Read and validate output file

with open(config["output"]) as output:
    if config["output"].endswith("json"):
        output_spec = json.load(output)
    elif config["output"].endswith("yaml") or config["output"].endswith("yml"):
        output_spec = yaml.safe_load(output.read())

validate(output_spec, schema="../schemas/output_files.schema.yaml")

### Set wildcard constraints
wildcard_constraints:
    sample="|".join(samples.index),
    type="N|T|R",


def compile_output_file_list(wildcards):
    outdir = pathlib.Path(output_spec.get("directory", "./"))
    output_files = []
    for f in output_spec["files"]:
        outputpaths = set(
            [
                f["output"].format(sample=sample, type=unit_type)
                for sample in get_samples(samples)
                for unit_type in get_unit_types(units, sample)
            ]
        )
        for op in outputpaths:
            output_files.append(outdir / pathlib.Path(op))
    return output_files


def generate_copy_rules(output_spec):
    # Generates one "copy" rule per output_files.yaml entry that has an `input`,
    # so already-produced files get placed at the requested output path.
    ...


generate_copy_rules(output_spec)
```

Key points to preserve when writing or reviewing this file:
- **Five validation blocks, in this order**: config → resources → samples → units → output. Each loads its file and immediately validates against its matching schema in `../schemas/`. Don't skip or reorder these.
- **`wildcard_constraints`** pins `sample` to the actual sample IDs and `type` to `N|T|R` — this is what makes `{sample}`/`{type}` safe to use unconstrained in every rule (see rule-development).
- **`compile_output_file_list`** is what `rule all` in the Snakefile targets — it's built from `output_files.yaml`/`output_spec`, not hardcoded.
- The `generate_copy_rules` function (elided above — it's ~40 lines of `exec`-based rule generation) auto-creates a trivial copy rule for every `output_files.yaml` entry that has a non-null `input`, so results land at the requested path without a dedicated rule. Don't try to hand-write this logic; if asked to explain it, describe the behavior (copies `input` to `output` for entries with a real source file) rather than reproducing the exec/rule-generation internals verbatim.

### Schema files (`workflow/schemas/`)

Four schemas are mandatory for a pipeline (a module only strictly needs the first three — `output`/`output_files.schema.yaml` matters when something targets `rule all`, which is primarily a pipeline concern):

**`config.schema.yaml`**:
```yaml
$schema: "http://json-schema.org/draft-04/schema#"
description: snakemake configuration file
type: object
properties:
  samples:
    type: string
  units:
    type: string
  output:
    type: string
    description: output yaml/json file defining expected output from pipeline
  resources:
    type: string
    description: Path to resources.yaml file
  default_container:
    type: string
    description: name or path to a default docker/singularity container
required:
  - samples
  - units
  - output
  - resources
  - default_container
```

Note `output` is required here, in addition to `samples`/`units`/`resources`/`default_container` — that's what `common.smk`'s output-validation block reads.

**`output_files.schema.yaml`** — validates `output_files.yaml`, the file that drives `compile_output_file_list`:
```yaml
$schema: "http://json-schema.org/draft-04/schema#"
description: Output file specification
type: object
properties:
  files:
    description: Defines a list of output files
    type: array
    items:
      type: object
      properties:
        name:
          description: Descriptive name of the output file.
          type: string
        input:
          description: >
            Path to the file that should be copied to the output directory.
            An input path that is `null` means that snakemake will find a rule
            that will generate the output file at `output`, and not copy
            an already generated file.
          type: [string, "null"]
          format: uri
        output:
          description: Relative path within the output directory.
          type: string
          format: uri
        types:
          type: array
          items:
            type: string
            pattern: ^(N|T|R)$
      required: [name, input, output]
required:
  - files
```

**`samples.schema.yaml`** and **`units.schema.yaml`** validate `samples.tsv`/`units.tsv`. Both are pipeline-wide (not per-rule, unlike `rules.schema.yaml` from rule-development) — don't confuse the two. The generated defaults include `sample`/`tumor_content` for samples, and a fuller set (`sample`, `type`, `machine`, `flowcell`, `barcode`, `lane`, `fastq1`, `fastq2`, `adapter`, `bam`, `platform`, etc.) for units, with conditional `required` blocks depending on `platform` (Illumina-type platforms require `flowcell`/`lane`/`machine`/`fastq1`/`fastq2`/`adapter`/`barcode`; `PACBIO`/`ONT` require `processing_unit`/`bam`/`methylation`, and `ONT` additionally `run_id`/`basecalling_model`). Adjust these only if the user's actual sample metadata needs fields beyond the defaults — don't strip required fields without confirming the pipeline doesn't need them.

### `config/config.yaml` and `config/resources.yaml`

```yaml
# config/config.yaml
output: "config/output_files.yaml"
resources: "config/resources.yaml"
samples: "samples.tsv"
units: "units.tsv"
default_container: "docker://hydragenetics/common:0.1.9"
```

```yaml
# config/resources.yaml
default_resources:
  threads: 1
  time: "12:00:00"
  mem_mb: 1024
  mem_per_cpu: 3072
  partition: core
```

`default_container` and the `default_resources` values are generated placeholders — confirm the real container image and resource numbers with the user rather than leaving these as-is or inventing different ones unprompted.

## Full folder structure

```
├── .git
├── .github/
│   ├── CODEOWNERS
│   ├── ISSUE_TEMPLATE/
│   └── workflows/
│       ├── integration.yaml
│       ├── lint.yaml
│       ├── pycodestyle.yaml
│       ├── pytest.yaml
│       ├── snakefmt.yaml
│       └── snakemake-dry-run.yaml
├── .gitignore
├── README.md
├── LICENSE.md
├── requirements.txt
├── requirements.test.txt
├── mkdocs.yaml
├── docs/
│   ├── index.md
│   ├── intro.md
│   ├── softwares.md
│   ├── extra.css
│   ├── requirements.txt
│   └── includes/
│       └── abbreviations.md
├── images/
│   └── hydragenetics.png
├── config/
│   ├── config.yaml
│   ├── resources.yaml
│   ├── output_files.yaml
│   ├── samples.tsv
│   └── units.tsv
└── workflow/
    ├── Snakefile
    ├── rules/
    │   └── common.smk
    ├── schemas/
    │   ├── config.schema.yaml
    │   ├── output_files.schema.yaml
    │   ├── resources.schema.yaml
    │   ├── samples.schema.yaml
    │   └── units.schema.yaml
    ├── scripts/
    │   ├── dummy.py
    │   └── test_dummy.py
    └── notebooks/
```

Note there's no `.tests/` scaffolded by `create-pipeline` itself, and no `rulegraph.svg` placed under `images/` — only `hydragenetics.png` (the org logo) ships by default. The `.tests/integration/` setup and initial `images/rulegraph.svg` mentioned in some older docs/tutorials appear to be added manually or via a different workflow step, not generated by this command — verify against the actual output directory rather than assuming they exist.

`workflow/scripts/dummy.py` / `test_dummy.py` are placeholder example script + test — meant to be replaced, not real starter logic.

## What's out of scope here

- **Writing the pipeline's own rules** → `rule-development` skill
- **Creating a module** (same CLI, different intent/next-steps) → `module-creation` skill
- **Generating real `samples.tsv`/`units.tsv` content** → `hydra-genetics create-input-files`, not covered here

## Checklist

- [ ] All required flags (name, description, author, email, git-user) confirmed with the user, not guessed
- [ ] **(verify against the actual output directory)** Scaffold command ran and produced the expected structure — check the real filesystem, don't assume from command syntax alone
- [ ] Git remote add/push only performed after explicit user confirmation
- [ ] `Snakefile` has the authorship header, `include: "rules/common.smk"`, and `rule all: input: compile_output_file_list,` — unmodified unless the user asked for something different
- [ ] Module imports added under `# Include modules` **only if** the user specified which modules/rules — otherwise left untouched
- [ ] Any module `tag` version was confirmed with the user, not guessed
- [ ] `common.smk` preserves all four validation blocks (config, resources, samples, units) plus the output-file validation, in order
- [ ] `config.schema.yaml` includes `output` in both `properties` and `required` (pipeline-level, not module-level)
- [ ] `config/config.yaml`'s `default_container` and `config/resources.yaml`'s `default_resources` values confirmed with the user, not left as generated placeholders
- [ ] Placeholder files (`dummy.py`, `test_dummy.py`) flagged to the user as stand-ins to replace