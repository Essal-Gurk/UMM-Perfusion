# UMMPerfusionIsiX v0.4.2

GitHub distribution prepared on 24 November 2026.
Plugin version 0.4.2, build 9. Apple Silicon, macOS 15 or later.
Built with IsiXPluginKit 1.0.0 / API v1 from IsiX 6.0.7.

## Features

- Standard and Extended Tofts, plus regularized deconvolution.
- Individually selected result maps, including Ktrans-only output.
- In-memory result viewers and optional saving as new DICOM series.
- Persistent model, output and numerical settings.
- Progress display, cancellation and retry opening saved results.
- Ten languages with parameter-specific mouseover help and Arabic layout.
- A visible Language menu offers all ten languages and a System language
  option. Labels and tooltips update immediately. The language selection is
  retained independently of the existing calculation settings.

## Distribution changes

The English README explains the workflow, installation, output units and
limitations. Attribution credits the original UMMPerfusion team in Mannheim
and cites both foundational papers. The existing BSD 3-Clause licence is
retained.

Build 9 recreates native menu content on language changes, fixing stale
German model and signal-conversion entries after switching to English.
Language names, the host command and generated DICOM series labels follow
the selected language. Status/error messages retain translation keys and
typed arguments until display. Unmapped host errors use localized text
with a diagnostic domain/code.

Calculation parameters and stored model choices retain stable identifiers.
Source DICOM series names and ROI names are preserved.

## Verification and limits

The SDK-verified arm64 build, deterministic synthetic tests, ten-language
catalogue checks, code signature and installer have been checked locally.
Localization regression tests exercise all ten selections, returning to
system-language selection, live German/English switching and tooltip lookup.
They also check model/signal entries, translated language names and nested
status/error messages across language changes. The experimental
PickerLocalizationTests helper that caused macOS crash dialogs was removed.
Independent clinical/DRO validation and complete visual acceptance of all
language layouts remain outstanding.

This release is distributed for software development, teaching and
exploratory research. It makes no claim of MDR CE marking or FDA market
authorization. See `docs/REGULATORY.md`.
