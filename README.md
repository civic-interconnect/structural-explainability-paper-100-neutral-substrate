# The Ontological Neutrality Theorem

[![License: CC BY 4.0](https://img.shields.io/badge/License-CC_BY_4.0-blue.svg)](https://creativecommons.org/licenses/by/4.0/)
[![Build PDF](https://github.com/civic-interconnect/structural-explainability-paper-100-neutral-substrate/actions/workflows/build-latex.yml/badge.svg)](https://github.com/civic-interconnect/structural-explainability-paper-100-neutral-substrate/actions/workflows/build-latex.yml)
[![Check Links](https://github.com/civic-interconnect/structural-explainability-paper-100-neutral-substrate/actions/workflows/links.yml/badge.svg)](https://github.com/civic-interconnect/structural-explainability-paper-100-neutral-substrate/actions/workflows/links.yml)
[![ArXiv Prep](https://github.com/civic-interconnect/structural-explainability-paper-100-neutral-substrate/actions/workflows/arxiv-prep.yml/badge.svg)](https://github.com/civic-interconnect/structural-explainability-paper-100-neutral-substrate/actions/workflows/arxiv-prep.yml)

> Paper establishing that for an ontological substrate to remain neutral and stable
> under allowable frameworks that include persistent disagreement,
> causal or normative commitments cannot be part of the substrate itself.

## Paper

- [PDF](./se100_the_ontological_neutrality_theorem.pdf)

## Repository Structure

```
.github/         # CI workflows
.vscode/         # Editor settings
bibliography/    # BibTeX references
glossary/        # Term definitions
tools/           # Scripts
```

## Building Locally

<!--
On Windows (MiKTeX):

- Download from <https://miktex.org/download>.
- Suggested options during installation:
  - Install for current user only
  - Leave paper size at A4 (default is fine)
  - Install missing packages on the fly = Yes
  - Add MiKTeX to PATH = Yes
-->

Requires a LaTeX distribution with `latexmk` (MiKTeX, TeX Live, or MacTeX):

```bash
latexmk -pdf se100_the_ontological_neutrality_theorem.tex
```

Windows:

```pwsh
.\tools\build\build.ps1
```

## Related

- [Civic Interconnect](https://github.com/civic-interconnect/civic-interconnect)

## Annotations

This repository uses the [Structural Explainability Annotation Standard](./ANNOTATIONS.md) for self-documenting configuration.

## Citation

See [CITATION.cff](./CITATION.cff).

## License

[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)
