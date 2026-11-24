# Contributing

Use an issue to describe a reproducible problem, with plugin version, IsiX
version, macOS version and the selected model/settings. Include synthetic
examples where possible.

Remove patient identifiers and private data from issue text, logs, images
and attachments. Commit synthetic fixtures with documented generation
parameters.

Run `bash test.sh` and build with the official SDK before proposing source
changes. For numerical changes, document the assumptions, units and
independent comparison data. Translation changes should update both PSV
catalogs and pass the ten-language completeness and placeholder checks.

Contributions are submitted under the repository's BSD 3-Clause licence.
Preserve upstream attribution and document third-party additions.

The intended research scope and validation limitations are described in
`docs/REGULATORY.md` and `docs/VALIDATION.md`.
