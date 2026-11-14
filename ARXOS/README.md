# Plexo, ArxOS community build

This repository is a fork of [anmolkapil/plexo](https://github.com/anmolkapil/plexo) (MIT), a
download manager that combines several network connections. It is a community project: Plexo is
built by its upstream authors, not by ArxOS. ArxOS adds only what is on this `arxos` branch:

- `ARXOS/AUDIT.md`: the security review of the source, and what this build changes.
- `ARXOS/patches/`: four small patches (no self-update, no navigation away from the app page, IPC
  answers only the app's page, the browser bridge cannot be flipped by a web page).
- `ARXOS/review.sh` and `.github/workflows/arxos-community.yml`: every upstream release is reviewed
  on the risky surfaces, its dependencies are scanned with install scripts disabled, it is built
  with the patches and smoke-started, and released with SHA256SUMS and build provenance.
- `install.sh` (repository root, where `arx pub install` reads and safety-scans it): installs the released binary after checking its hash (`arx pub install plexo`).
- `.github/dependabot.yml`: dependency alerts and update proposals; they go through the same steps.

The `main` branch mirrors upstream unchanged. Report Plexo bugs upstream; report problems with this
build here.
