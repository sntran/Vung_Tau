# Release notes

## Desktop builds (plan 0004)

The export workflow makes builds for Windows (x86_64), macOS (universal: Intel and Apple silicon), and Linux (x86_64). Download them from the artifacts of the "Export" workflow run on GitHub.

- **The builds are not signed.** The release plan signs them.
- **macOS shows a warning at the first start.** The macOS build has only an ad-hoc signature and is not notarized. macOS says that it cannot check the app. To start it, open the zip file, then right-click the app and select "Open". Or go to System Settings, Privacy & Security, and select "Open Anyway".
- **Windows can show a SmartScreen warning.** Select "More info", then "Run anyway".
- **Linux:** make the file executable (`chmod +x vung-tau.x86_64`), then start it.

At the first start, the game selects a quality preset for the computer: Low without a graphics card, Medium with a graphics chip in the processor, and High with a separate graphics card. Change it in the Settings app on the phone. A change of preset starts at once. The game does not start again.
