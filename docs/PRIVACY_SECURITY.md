# Privacy, security and clinical safety

## Data flow

The plugin receives image pixels, geometry, selected ROI statistics and a small
set of DICOM identifiers from the local IsiX process. Calculations are local.
It makes no network request, contains no telemetry and does not write patient
names or identifiers to plugin preferences or logs.

When DICOM saving is enabled, derived output is written back to the currently
open local IsiX database. With saving disabled, the SDK opens derived series
in memory. Output inherits the source study's privacy classification and
must be protected, retained, exported and deleted under the same institutional
policy as the source DICOM.

Temporary DICOM files are created by IsiXPluginKit, imported, then deleted on a
best-effort basis. Abnormal process termination can leave temporary files in an
IsiX-controlled temporary directory; operational cleanup should include these
locations.

## Least privilege

Declared capabilities include viewer read/write, ROI access, database read
and database import. Viewer write enables in-memory derived viewers.
The plugin declares no general database-edit, DICOM network,
XML-RPC or external-process capability.

## Safeguards

- Rejects series with fewer than four phases.
- Rejects non-scalar images and phase geometry mismatch.
- Uses DICOM acquisition dates only when complete and strictly monotonic;
  otherwise uses an explicit user-entered temporal resolution and reports it.
- Masks low baseline signal and all non-finite/physically invalid fits.
- Never modifies source pixels or source ROIs.
- Writes new derived series rather than overwriting source DICOM.
- Supports cancellation and cleans temporary output best-effort.

## Remaining hazards

- Wrong AIF ROI, hematocrit, baseline, temporal resolution or signal model can
  create plausible but wrong maps.
- Geometry equality does not prove motion-free registration.
- DICOM acquisition time semantics vary across vendors and enhanced objects.
- Series descriptions carry units, but the output is not yet a standards-based
  DICOM Parametric Map with coded units.
- Fit quality alone does not establish physiological validity.

The UI and documentation label the plugin as unvalidated. Clinical deployment
would require formal risk management, software lifecycle controls, independent
verification/validation, usability testing and the applicable medical-device
regulatory assessment.
