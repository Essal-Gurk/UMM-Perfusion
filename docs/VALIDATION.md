# Test data and validation plan

## Automated synthetic tests

`Tests/PerfusionEngineTests.swift` generates its data deterministically; it
contains no patient information. `TestData/synthetic_case.json` records the
fixture parameters in a machine-readable form. The AIF is a delayed gamma-like
bolus sampled every five seconds. Tissue curves are generated from the same
documented trapezoidal Tofts convolution and converted to synthetic MR signal.

Covered assertions:

- relative T1 and T2* signal conversion;
- recovery of Standard Tofts `Ktrans` and `ve`;
- recovery of Extended Tofts `Ktrans`, `ve` and `vp`;
- finite positive deconvolution PF/PV/MTT;
- low-signal background masking;
- progress through masked voxels and cancellation between voxel batches;
- rejection of non-monotonic acquisition time.

Run with `./test.sh`.

These are implementation regression tests, not independent scientific
validation, because the synthetic generator shares numerical conventions with
the fitter.

## Required independent validation

Before any research comparison or clinical evaluation:

1. **SDK/runtime gate** — build with IsiXPluginKit 1.0.0 from the official
   IsiX 6.0.7 SDK and run on the GitHub arm64 IsiX 6.0.7 distribution.
2. **Public digital reference objects** — compare Standard/Extended Tofts maps
   against a QIBA/OSIPI DCE DRO with prespecified tolerances.
3. **Legacy parity** — run the same de-identified 4D series, AIF ROI, timing,
   baseline and hematocrit through historical UMMPerfusion and this port.
4. **Independent implementation** — compare against a maintained perfusion
   library using identical signal/concentration assumptions.
5. **Geometry** — test multi-slice and enhanced multiframe series, phase order,
   missing acquisition dates and irregular sampling.
6. **Robustness** — zero/negative signal, bolus outside acquisition, noisy AIF,
   partial-volume AIF, motion, saturation, truncated first pass and cancellation.
7. **DICOM round-trip** — verify Study/Series/SOP UIDs, pixel dimensions,
   orientation, spacing, units in series descriptions and database re-open.
8. **Performance** — record peak memory and runtime for representative
   256×256×N and 512×512×N datasets.

Suggested acceptance targets must be frozen before testing. A reasonable
starting point for noiseless DROs is absolute parameter error <= 5% and map
correlation >= 0.99; noisy and clinical datasets require separately justified
limits.

## Manual IsiX acceptance test

1. Open an anonymized 4D DCE series and select an arterial oval ROI.
2. Confirm the plugin reports the correct slice/phase counts and ROI name.
3. Run each model and confirm progress advances during fitting. Select Ktrans
   alone in Extended Tofts and verify one result window. With saving off,
   confirm that no new series enters the database. With saving on, confirm
   one new Ktrans series in the source study. Select all maps and verify three
   series for Standard Tofts and four for each other model. Verify that saved and
   opened counts can differ if a window fails to open and that retry uses
   the already imported series.
4. Repeat with DICOM acquisition times removed; confirm the status reports use
   of manual temporal resolution.
5. Try a mismatched or single-phase series; confirm calculation is refused.
6. Cancel a long run and record whether cancellation happened before or during
   DICOM import. If import had already begun, remove any clearly labelled
   partial UMM Perfusion result series from the test database.
7. Restart IsiX and verify imported results remain readable.
8. Change the selected model, map checkboxes, output save option and numerical
   settings. Close/reopen the plugin and restart IsiX. Verify every choice is
   restored and map selections remain independent between models.
9. Select each of the ten languages from the Language menu at the top of the
   plugin window. Verify that the interface and tooltips change immediately
   and that the selected language survives an IsiX restart. Select System
   language to return to the system preference. Verify the
   translated interface, status messages and tooltips over each map checkbox,
   the selected model, signal conversion and output setting. Check Arabic
   right-to-left layout and readable mixed Latin parameter names and units.

All test DICOM must be de-identified under the institution's approved process;
removing only Patient Name is insufficient.
