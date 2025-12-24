# Structural Explainability Annotation Standard

<!--
WHY: Defines the structured annotation vocabulary for documenting decisions.
WHY: Annotations make decisions explicit, scannable, and comparable across files and repositories.
OBS: Version 1.0, December 2025.
-->

Structured annotations document decisions, constraints, alternatives, and observations
directly alongside code and configuration.

Annotations are **human-readable**, **machine-scannable**, and **non-enforcing by default**.
They explain _why something is the way it is_ without turning comments into executable policy.

## Core Vocabulary

Five annotations cover the majority of use cases.

| Annotation | Purpose                   | Use                                 |
| ---------- | ------------------------- | ----------------------------------- |
| `WHY`      | Rationale                 | Explain intent or trade-offs        |
| `OBS`      | Observable fact           | State current state or measurements |
| `REQ`      | Requirement or constraint | Declare invariants                  |
| `ALT`      | Alternative               | Document other viable options       |
| `CUSTOM`   | Customization point       | Flag values expected to change      |

`REQ` documents intent. It does not imply enforcement unless paired with tooling.

## Extended Vocabulary

Three additional annotations support governance-heavy or analytical contexts.

| Annotation | Purpose            | Use                                      |
| ---------- | ------------------ | ---------------------------------------- |
| `MODEL`    | Decision framework | Attribute reasoning to a method or model |
| `EVIDENCE` | Supporting data    | Cite data underlying a decision          |
| `ATTEST`   | Verification       | Record that validation occurred          |

Extended annotations are optional. Most repositories need only the core five.

## Scoping

Annotations apply at different scopes.

### Default Scope

Without qualification, an annotation applies to the **immediate next item** (line or block).

```python
# WHY: Avoids circular import at module level.
from typing import TYPE_CHECKING
```

### Section Scope

Use `=== SECTION NAME ===` markers to define logical boundaries within a file.

```bash
# === Environment variables and secrets ===

# WHY: Never commit credentials or environment-specific configuration.
.env
.env.*
*.env

# === LaTeX papers ===

# WHY: LaTeX build artifacts are regenerated on each compile.
*.aux
*.bbl
```

Annotations apply until the next section marker unless scoped more narrowly.

Use the `-SECTION` suffix to make section scope explicit:

```bash
# WHY-SECTION: All patterns below prevent committing generated artifacts.
```

Section markers are visual and semantic. The `=== ... ===` pattern is conventional but not enforced; any consistent delimiter works.

### File Scope

Use the `-FILE` suffix to apply an annotation to the entire document.

```python
# WHY-FILE: Configuration for explainability and accountability tracking.
# OBS-FILE: Auto-generated; do not edit manually.
```

### Domain Scope

Use **dot notation** to scope requirements to a domain.

```python
# REQ.PYTHON: Use src/ layout for all packages.
# REQ.UNIVERSAL: Include .gitignore in all repositories.
```

Common domain scopes:

| Scope       | Applies to                       |
| ----------- | -------------------------------- |
| `UNIVERSAL` | All professional repositories    |
| `PROJECT`   | This specific project            |
| `PYTHON`    | Python projects                  |
| `RUST`      | Rust projects                    |
| `LATEX`     | LaTeX documents                  |
| `CI`        | Continuous integration workflows |

Dot notation is syntactic sugar. `REQ.PYTHON` is equivalent to `REQ[scope=python]`.

### Arbitrary Scope

Use **bracket notation** for scopes not covered by dot sugar.

```yaml
# REQ[scope=nwmsu-courses]: All student repos must include acknowledgement when generative AI tools are used.
# REQ[scope=civic-interconnect]: Adapters must not define new entity kinds.
```

General form: `ANNOTATION[key=value]` or `ANNOTATION[value]` (shorthand for `scope=value`).

### Scope Precedence

Narrower scope overrides broader scope. `REQ.PROJECT` overrides `REQ.UNIVERSAL` for the same concern.

## Syntax by Language

Annotations use the same keywords across file types. Only comment syntax differs.

| File Type                           | Syntax                      |
| ----------------------------------- | --------------------------- |
| Python, YAML, TOML, shell           | `# WHY: Explanation`        |
| HTML, Markdown, XML                 | `<!-- WHY: Explanation -->` |
| JavaScript, TypeScript, C, Rust, Go | `// WHY: Explanation`       |
| CSS                                 | `/* WHY: Explanation */`    |
| LaTeX                               | `% WHY: Explanation`        |

## Machine Readability

Annotations are designed to be scannable by tooling.

### Core Pattern

```regex
(WHY|OBS|REQ|ALT|CUSTOM|MODEL|EVIDENCE|ATTEST)
```

### With Scope

```regex
(WHY|OBS|REQ|ALT|CUSTOM)(\.[A-Z]+|\[[^\]]+\])?(-FILE)?:\s*(.+)
```

### By Comment Style

```python
# Python / YAML / TOML / shell
r'#\s*(WHY|OBS|REQ|ALT|CUSTOM)(\.[A-Z_]+|\[[^\]]+\])?(-FILE)?:\s*(.+)'

# HTML / Markdown / XML
r'<!--\s*(WHY|OBS|REQ|ALT|CUSTOM)(\.[A-Z_]+|\[[^\]]+\])?(-FILE)?:\s*(.+?)\s*-->'

# JavaScript / C-style
r'//\s*(WHY|OBS|REQ|ALT|CUSTOM)(\.[A-Z_]+|\[[^\]]+\])?(-FILE)?:\s*(.+)'
```

Tooling is optional. Annotations work without it.

## Theoretical Basis

This standard implements concepts from **Contextual Evidence and Explanations (CEE)**,
the third paper in the Structural Explainability framework.

| Annotation | CEE Concept    |
| ---------- | -------------- |
| `WHY`      | Explanation    |
| `OBS`      | Observation    |
| `EVIDENCE` | Evidence set   |
| `MODEL`    | Decision model |
| `ATTEST`   | Verification   |

`REQ`, `ALT`, and `CUSTOM` are pragmatic extensions for engineering use.
They document constraints and variation points that support explainability
but do not map directly to CEE's formal structure.

## Examples

### Configuration file (.editorconfig)

```ini
# REQ.UNIVERSAL: All professional repositories MUST include .editorconfig.
# WHY: Establish cross-editor baseline so diffs stay clean.
# ALT: Omit ONLY if formatting enforced equivalently by CI.
# CUSTOM: Adjust indent_size if organizational standards differ.

root = true

[*]
# WHY: Normalize line endings across Windows, macOS, and Linux.
end_of_line = lf
charset = utf-8

# WHY: Newline at EOF avoids noisy diffs and tool warnings.
insert_final_newline = true
```

### Build configuration (pyproject.toml)

```toml
# REQ.PYTHON: Python projects MUST include pyproject.toml as single source of truth.
# WHY: Centralizes metadata and configuration for reproducibility.

[project]
name = "example"  # CUSTOM: Update to match your package.
version = "0.1.0" # CUSTOM: Update as needed.

[tool.ruff.lint]
select = [
  "E",   # REQ: Basic syntax and structural correctness
  "F",   # REQ: Undefined names and unused imports
  # "N", # ALT: Naming conventions (enable if enforcing naming policy)
]
```

### Source code (Python)

```python
# WHY-FILE: Adapter for EU transparency register data.
# OBS: Schema version 2.3, last updated 2025-01.

# WHY: Deferred import avoids circular dependency.
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from cee.core import Exchange

def validate(record: dict) -> bool:
    # REQ: All records must include source jurisdiction.
    # EVIDENCE: See EP Section 4.2 for provenance requirements.
    return "jurisdiction" in record
```

## Adoption

### When to annotate

- When a decision matters and future readers might ask why
- When alternatives exist and the choice is non-obvious
- When constraints are intentional, not accidental
- When customization is expected

### When not to annotate

- To restate what the code obviously does
- To replace proper documentation
- To enforce style (use linters)
- On every line (annotations are signal; overuse is noise)

Value lies in **clarity**, not quantity.

## Theoretical Foundation

These annotations instantiate the Contextual Evidence and Explanations
framework (CEE) at the documentation level.
See [Paper 3: Contextual Evidence and Explanations](./00P3_contextual_evidence_and_explanations.pdf)
for formal semantics.

## Governance

This standard is maintained at:
[github.com/civic-interconnect/structural-explainability/ANNOTATIONS.md](https://github.com/civic-interconnect/structural-explainability/blob/main/ANNOTATIONS.md)

Changes to the core vocabulary require consideration of downstream adopters.
Extended vocabulary and scoping mechanisms may evolve with use.
