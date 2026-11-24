# UMMPerfusionIsiX

Native MRI perfusion research plugin for IsiX DICOM Viewer on Apple Silicon.
Version 0.4 uses IsiXPluginKit 1.0.0 / API v1, built against the SDK from
IsiX 6.0.7.

This repository includes the Swift source, synthetic tests and a precompiled
`UMMPerfusionIsiX.isixplugin` in [Prebuilt](Prebuilt/).

## Intended use and regulatory status

This release is intended for software development, teaching and exploratory
perfusion-method research. Its results are excluded from diagnosis, treatment
selection, patient monitoring and clinical report sign-off.

Independent clinical validation is outstanding. This release makes no claim
of CE marking under the EU Medical Device Regulation, FDA clearance, FDA
authorization or FDA approval. A research label and an open-source licence
do not establish a regulatory exemption. Any proposed medical intended use
requires a documented qualification, classification and applicable regulatory
assessment. See [Regulatory information](docs/REGULATORY.md).

## Functionality

The plugin reads a registered scalar 4D MR series from an IsiX viewer and
measures the selected arterial region of interest across time to obtain the
arterial input function (AIF). It fits the selected model voxel by voxel,
then opens the requested parameter maps.

| Model | Available maps |
| --- | --- |
| Standard Tofts | Ktrans [1/min], ve [%], fit quality R² |
| Extended Tofts | Ktrans [1/min], ve [%], vp [%], fit quality R² |
| Regularized deconvolution | Plasma flow [mL/100mL/min], plasma volume [%], mean transit time [s], fit quality R² |

Each map has an individual checkbox. Selecting only Ktrans produces one
result window. The model parameters are fitted jointly regardless of the
number of output maps selected.

- **Display in memory** opens each selected map in a new IsiX viewer. Closing
  the result windows discards these results.
- **Also save as new DICOM series** imports each selected map into the source
  study and opens the saved results. This option is off on the first launch.
- **Persistent settings** retain the model, numerical inputs, signal
  conversion, output option and separate map selections for each model.
  Tofts models initially select Ktrans alone.
- **Progress and cancellation** cover AIF measurement, slice fitting,
  optional DICOM writing/import and opening results. Saved-series and
  opened-window counts are shown separately.
- **Mouseover help** explains the selected model, signal conversion,
  numerical settings, output controls and each parameter map with its units.

Signal conversion supports relative T1 enhancement `(S − S₀)/S₀`, absolute
T1 enhancement `S − S₀` and T2*-DSC `−ln(S/S₀)`. These are concentration
surrogates. DICOM acquisition times are used when complete and strictly
increasing. Otherwise, the explicitly entered phase interval is used.
The status reports the timing source.

The interface follows the preferred system language. The ten languages are
English, German, French, Spanish, Italian, Portuguese, Japanese, Simplified
Chinese, Turkish and Arabic. Arabic uses a right-to-left layout.

## Requirements

- An Apple Silicon Mac running macOS 15 or later.
- The GitHub distribution of IsiX with external plugin support. This build
  targets the public API supplied with IsiX 6.0.7.
- A registered 4D perfusion series containing at least four time phases and
  a suitable arterial area ROI.

The Mac App Store edition of IsiX disables external plugins. The executable
included here contains the arm64 architecture.

## Install the precompiled plugin

Download the arm64 release ZIP from the repository's Releases tab, or use
GitHub's **Code → Download ZIP** to obtain the source and bundled plugin.

1. Quit IsiX.
2. Extract the ZIP and open Terminal in the extracted folder.
3. Run `bash install.sh`.
4. Restart IsiX and open **Image Filters → UMM Perfusion…**.

The installer copies the plugin into
`~/Library/Application Support/IsiX/Plugins`, verifies its signature and
backs up an existing version in the adjacent `Plugin Backups` folder.
Preferences are retained.

The precompiled plugin is ad-hoc signed and has no Apple notarization.
The installer clears extended attributes, including a download quarantine
attribute, from the staged plugin before installation. Run it after checking
the source and provenance of your download. Release ZIPs have SHA-256
checksums supplied alongside them.

## Use

1. Open the registered DCE series as a 4D viewer.
2. Draw or select one area ROI inside an artery on the current slice.
3. Open the plugin and confirm its source dimensions and AIF ROI.
4. Choose the model and maps, for example Extended Tofts with Ktrans only.
5. Review baseline phases, hematocrit, signal conversion and timing.
6. Enable DICOM saving if you want the maps retained in the study.
7. Select **Calculate** and review the progress, result windows and status.

If a saved series fails to open, **Open saved results** retries opening the
existing database results. Cancellation can leave series already imported
before the cancellation request in the source study.

## Limitations and validation

The current conversion uses proportional concentration surrogates.
Native-T1/TR/flip-angle/relaxivity-based quantitative concentration conversion
and motion correction are outstanding. Geometry checks detect some phase
mismatches, while residual patient motion can still affect the fits.
Deconvolution uses ridge regularization. Comparison with historical
UMMPerfusion requires independent validation of the numerical conventions.

Saved maps use the SDK's derived grayscale DICOM output, with parameters and
units in series descriptions. DICOM Parametric Map IOD and coded measurement
metadata are outstanding.

The tests cover synthetic parameter recovery, signal conversion, masking,
timing rejection, progress/cancellation and settings serialization.
The generator and fitter share numerical conventions. Public digital
reference-object testing, a complete independent DCE validation and visual
acceptance of all languages remain outstanding.

See the [model equations and units](docs/MODELS.md),
[validation plan](docs/VALIDATION.md) and
[SDK/build audit](docs/COMPATIBILITY.md).

## Build from source

Use Xcode and a Swift compiler compatible with the official SDK. The SDK
manifest records Apple Swift 6.4.2. Download `IsiXPluginKit-SDK-6.0.7.zip`
from the official [IsiX 6.0.7 release](https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS/releases/tag/v6.0.7).

```bash
bash test.sh
bash build.sh /absolute/path/to/IsiXPluginKit-SDK-6.0.7.zip
```

The build checks the SDK's API and kit version, arm64 availability and
framework/interface hashes against its manifest. Its output is
`.build/UMMPerfusionIsiX.isixplugin`. The verified `SDK.json` accompanies
the plugin resources. IsiX supplies IsiXPluginKit at runtime.
Download the SDK separately for development.

## Privacy and contributions

Calculations run locally. The plugin contains no telemetry or network client.
Saved DICOM results inherit the source study's patient information.
Temporary files and the IsiX database require the same protections as the
source study.

Keep patient data, screenshots with identifiers, database exports,
credentials and private keys out of commits and issues. Use synthetic data
for public examples. See [privacy and security](docs/PRIVACY_SECURITY.md),
[contribution guidance](CONTRIBUTING.md) and
[security reporting](SECURITY.md).

To update text, add translations to `Translations.psv` and
`Translations-extra.psv`. Every build checks that all ten languages contain
the same keys and compatible format placeholders.

## Acknowledgements

We gratefully acknowledge the original UMMPerfusion authors and the
Computer-Assisted-Clinical-Medicine team in Mannheim, associated with
Universitätsmedizin Mannheim and the Medical Faculty Mannheim of Heidelberg
University, for making their perfusion-analysis work and source available.
The historical project credits Marcel Reich, Sven Kaiser, Markus Daab,
Patrick Schülein and Engin Aslan, together with the scientific contributors
listed in the papers below. The original algorithms draw on Steven
Sourbron's Platform for Research in Medical Imaging.

This independent IsiX implementation draws on their published workflow and
scientific work. The acknowledgement conveys credit without implying
institutional endorsement or transferring any upstream validation or
regulatory status to this port.
[Original UMMPerfusion repository](https://github.com/Computer-Assisted-Clinical-Medicine/UMMPerfusion)

Thanks also to the IsiX, Horos and OsiriX contributors whose work provides
the viewer infrastructure.
[IsiX DICOM Viewer](https://github.com/ThalesMMS/IsiX-DICOM-Viewer-macOS)

## Citation and licence

Please cite the original UMMPerfusion papers when publishing work based on
this plugin, and report the exact port version, IsiX version, model,
signal-conversion assumptions and parameters.

1. Zöllner FG et al. UMMPerfusion: An Open Source Software Tool Towards
   Quantitative MRI Perfusion Analysis in Clinical Routine.
   Journal of Digital Imaging. 2013;26:344–352.
   [doi:10.1007/s10278-012-9510-6](https://doi.org/10.1007/s10278-012-9510-6)
2. Zöllner FG et al. An open source software for analysis of dynamic contrast
   enhanced magnetic resonance images: UMMPerfusion revisited.
   BMC Medical Imaging. 2016;16:7.
   [doi:10.1186/s12880-016-0109-0](https://doi.org/10.1186/s12880-016-0109-0)

The source and this plugin distribution use the BSD 3-Clause licence.
Retain its notices when redistributing source or binaries.
See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY.md).
