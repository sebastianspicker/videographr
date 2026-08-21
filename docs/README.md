# Documentation

The documentation separates implemented behavior from physical-device,
human-validation, and effectiveness evidence.

| Document | Scope |
|---|---|
| [Repository README](../README.md) | Purpose, requirements, installation, configuration, usage, development, testing, and operation |
| [Product scope](../PRODUCT.md) | Intended users, supported workflow, exclusions, and interface requirements |
| [Architecture](ARCHITECTURE.md) | Components, runtime flow, persistence, and trust boundaries |
| [Scientific alpha contract](SCIENTIFIC_ALPHA.md) | Operating modes and allowed evidence claims |
| [Evaluation guide](EVALUATION.md) | Safe evaluation procedure and reporting language |
| [Research gap inventory](RESEARCH_GAP_INVENTORY.md) | Implemented controls and validation still required |
| [Annotated bibliography](references/unterrichtsvideographie.md) | Non-systematic background notes requiring subject review |
| [Release notes](releases/0.1.0-alpha.1.md) | Contents and limits of the local alpha candidate |
| [Release status](../RELEASE_STATUS.md) | Dated local checks and external blockers |
| [Release procedure](../RELEASING.md) | Source-prerelease validation and publication steps |

## Evidence terms

| Term | Meaning |
|---|---|
| Implemented | Current source contains the behavior. |
| Unit tested | Deterministic tests exercise the stated contract. |
| Simulator checked | Compilation or visible behavior was checked without physical capture hardware. |
| Device verified | The behavior was exercised and recorded on supported physical hardware. |
| Human validated | An authorized corpus, declared codebook, trained raters, and reliability evidence support the claim. |
| Effectiveness tested | A study measured reflection or educational outcomes. |

Current local evidence covers implementation, unit tests, and Simulator checks.
The other levels remain open unless a dated record says otherwise.
