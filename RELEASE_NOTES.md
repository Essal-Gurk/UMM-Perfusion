# UMMPerfusionIsiX v0.4

GitHub distribution prepared on 24 November 2026.
Plugin version 0.4, build 7. Apple Silicon, macOS 15 or later.
Built with IsiXPluginKit 1.0.0 / API v1 from IsiX 6.0.7.

## Features

- Standard and Extended Tofts, plus regularized deconvolution.
- Individually selected result maps, including Ktrans-only output.
- In-memory result viewers and optional saving as new DICOM series.
- Persistent model, output and numerical settings.
- Progress display, cancellation and retry opening saved results.
- Ten languages with parameter-specific mouseover help and Arabic layout.

## Distribution changes

The English README explains the workflow, installation, output units and
limitations. Attribution credits the original UMMPerfusion team in Mannheim
and cites both foundational papers. The existing BSD 3-Clause licence is
retained.

Build 7 includes updated attribution and regulatory information in the plugin
resources. Its computational and interface source matches the earlier 0.4
build. Documentation describes the EU-MDR/FDA research status and outstanding
validation.

## Verification and limits

The SDK-verified arm64 build, deterministic synthetic tests, ten-language
catalogue checks, code signature and installer have been checked locally.
Independent clinical/DRO validation and complete visual acceptance of all
language layouts remain outstanding.

This release is distributed for software development, teaching and
exploratory research. It makes no claim of MDR CE marking or FDA market
authorization. See `docs/REGULATORY.md`.
