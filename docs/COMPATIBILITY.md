# Source, SDK and build compatibility audit

SDK/build audit date: 2026-11-22 (Europe/Berlin).

## UMMPerfusion upstream

The upstream observations below are retained from the initial 2026-11-13 audit.

- Repository: https://github.com/Computer-Assisted-Clinical-Medicine/UMMPerfusion
- Public repository state observed: `main`, 18 commits, no GitHub releases.
- Repository license: BSD 3-Clause, copyright 2023
  Computer-Assisted-Clinical-Medicine.
- Historical source files additionally contain BSD notices naming the original
  2012 contributors and Universitätsmedizin Mannheim.
- The old project is Objective-C/C and carries OsiriXAPI/GraphKit-era project
  artifacts. Reusing that binary directly would require an arm64 rebuild and
  continued reliance on the legacy ABI.

This port reimplements the numerical and workflow surface in Swift and does not
embed legacy frameworks. The upstream source remains the scientific and
behavioral reference.

## IsiXPluginKit 1.0.0 / IsiX 6.0.7

- Release: https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS/releases/tag/v6.0.7
- SDK source revision: `f4f0677125e30a579555204a8e38f90edff3cb06`.
- IsiX 6.0 introduced IsiXPluginKit v1 and retained compatible legacy Horos and
  OsiriX plugin loading in the GitHub edition.
- The v1 API exposes viewer/image snapshots, geometry, pixel access/commit,
  ROIs, Derived DICOM series, database import, commands, events and tasks.
- Comparing the arm64 public interface to the previous 6.0.3 SDK shows two
  additions, `IsiXCommand.Placement.report` and `IsiXCapability.report`.
  Viewer, image, ROI, task and database signatures used by this plugin match.
- API version remains 1 and kit version remains 1.0.0. SDK kit versions and
  application release numbers identify different things. The current SDK
  archive is versioned by its IsiX application release, 6.0.7.
- A plugin must contain the architecture slice used by the app. This project
  targets `arm64-apple-macos15.0`.
- The GitHub edition loads external `.isixplugin` bundles. The Mac App Store
  edition is sandboxed and disables external plugin loading.

## Verification state

The official `IsiXPluginKit-SDK-6.0.7.zip` release asset was downloaded and
verified against GitHub's published SHA-256:

`ab8479ccb485dbf92726bf527bff82e5bbea0271ebfebf64ea048323269a9297`

Its `SDK.json` records:

- API version 1, kit version 1.0.0;
- revision `f4f0677125e30a579555204a8e38f90edff3cb06`;
- arm64 and x86_64 interfaces;
- macOS 15.0 minimum;
- Swift 6.4.2;
- framework binary SHA-256
  `6635787f8efab6ef277c70ec748790e957cda95d22ffc20bdfbf046eb1196712`.

The arm64 interface SHA-256 is
`4bace50228bf076df6bcf2643732679d10fb22062ae9382692b25ea5a9454494`.
The project compiles with the official 6.0.7 SDK; the resulting Mach-O bundle
is arm64 and passes strict ad-hoc code-signature verification. Automated
numerical tests pass.

Every build checks SDK API/kit version, deployment target, arm64 availability
and the framework/interface hashes against `SDK.json`. The verified manifest
is included in the plugin resources and in `docs/SDK.json`.

The v0.2 preference domain and settings schema remain in use in v0.4.1, including
per-model map selections and the optional DICOM saving setting. The stored
settings contain numerical options and output choices.

The explicit language choice uses the separate `language.v1` preference.
Existing `settings.v1` calculation preferences require no migration.

Runtime validation inside IsiX still requires the viewer/ROI/import acceptance
tests in `VALIDATION.md`; compilation cannot substitute for that test.
