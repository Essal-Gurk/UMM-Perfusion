# Publishing this repository

## Prepared files

Use `UMMPerfusionIsiX` as the repository root. It contains source, tests,
English documentation, licence, translation catalogues and the precompiled
arm64 plugin in `Prebuilt/`.

The sibling `Release-assets` folder contains an installable source-and-binary
ZIP and its SHA-256 checksum for a GitHub Release. Keep those downloads
outside the source repository. Generated builds, local caches, DICOM data and
private keys are excluded by `.gitignore`.

## Upload

1. Create an empty GitHub repository named `UMMPerfusionIsiX` in the account
   or organization you choose. Use the prepared LICENSE and README.
2. Upload the contents of the prepared repository root. Include hidden
   `.gitignore` and `.gitattributes` files if using a graphical uploader.
   A local Git client preserves the complete tree.
3. Optionally use these commands from the prepared repository directory.
   Replace `YOUR_ACCOUNT` with the chosen owner.

   ```bash
   git init -b main
   git add .
   git commit -m "Prepare UMMPerfusionIsiX v0.4.2 source and arm64 plugin"
   git remote add origin https://github.com/YOUR_ACCOUNT/UMMPerfusionIsiX.git
   git push -u origin main
   ```

4. Create a GitHub Release with tag `v0.4.2`. Use `RELEASE_NOTES.md` for the
   release description and attach the ZIP and `SHA256SUMS.txt` from
   `Release-assets`.
5. Keep the research status visible in the repository description and
   release text. A suggested short description is
   `Native Apple Silicon IsiX plugin for MRI perfusion-method research`.
6. Enable private vulnerability reporting in the repository's security
   settings if you want to receive confidential reports there.

The destination account, repository visibility and publication are choices
for the repository owner. This prepared package has been checked locally.

## Future releases

Update version/build metadata and release notes, run `bash test.sh`, and
build with the SDK path described in the README. Refresh the `Prebuilt`
bundle from the successful build and verify it with `codesign`.
Prepare a new release ZIP and its checksum after the content is final.
Keep public descriptions consistent with the intended purpose and validation
evidence in `REGULATORY.md` and `VALIDATION.md`.
