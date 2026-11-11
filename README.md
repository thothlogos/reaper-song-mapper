# REAPER Song Mapper

Build your band's song structure as a list of sections, then generate colored regions and a tempo/time-signature map in one operation. REAPER's metronome follows the generated map.

## Easy installation on macOS

Install **REAPER 7.82+** first, launch it once, then quit it. From [GitHub Releases](https://github.com/thothlogos/reaper-song-mapper/releases), download the **`Install-Song-Mapper.command` release attachment**. This standalone file downloads and verifies its matching Song Mapper release automatically; you do not need Git, a GitHub account, the repository ZIP, or adjacent Lua files.

Release attachments must be published before this route is available. As a development/manual fallback, download and extract the repository ZIP and run its installer with the whole extracted folder together. The installer in the repository is a template/local-source installer; copying that file alone is not equivalent to downloading a generated release attachment. If Finder does not allow it to run, use the manual instructions below or run `bash "Install Song Mapper.command"` from Terminal in that folder; the installer does not remove quarantine flags or change macOS security settings.

A directly downloaded `.command` may lose its executable permission. If double-clicking reports a permission error, run `bash ~/Downloads/Install-Song-Mapper.command` in Terminal (adjust the path if saved elsewhere). A signed/notarized app installer would be needed to further streamline macOS security prompts.

The installer uses built-in Bash 3.2 and macOS tools: no Python, Homebrew, compiler, administrator access, or ReaPack is required. It installs missing ReaImGui files directly from the official **0.10.0.5** release using pinned SHA-256 checksums, installs Song Mapper, then opens REAPER to verify the API and register the action. Add the **optional toolbar button** using the instructions in the completion dialog. REAPER itself is installed separately so you can choose the correct OS build and complete its normal setup.

Existing ReaImGui is reused without updates. If it is too old or incomplete, installation stops with repair instructions; use ReaPack to update a dependency already managed by ReaPack. Directly installed ReaImGui files are not registered as ReaPack-owned packages. If you later adopt ReaPack, manage ReaImGui there deliberately; the installer never edits ReaPack's package database.

Save and quit REAPER before running the installer. It refuses multiple ReaImGui binaries, architecture conflicts, symbolic-link destinations, concurrent installs, and unmanaged folders already named `Scripts/Song Mapper`. Move a manually installed folder aside yourself before adopting the installer. Installer-managed updates preserve the previous runtime under `Scripts/.song-mapper-backup.*`; interrupted file replacement is rolled back. It does not edit your song projects or toolbar configuration. A failed native-extension load can leave verified files installed; repair the dependency and rerun `Finish Installation.lua` from REAPER's Actions window to finish registration.

**Compatibility:** intended for 64-bit Intel Macs on macOS **10.12+**, plus Apple Silicon Macs. The pinned Intel ReaImGui binary declares a minimum macOS of 10.9. This installer has been tested on the development Mac and in disposable resource folders, not on historical macOS releases; old system TLS certificates and vendor runtime compatibility still require real-machine verification. No guarantee of every ten-year-old Mac is implied. Existing 32-bit installs use the manual route.

Advanced options for a release download (use `Install Song Mapper.command` instead when running from an extracted repository):

```sh
bash Install-Song-Mapper.command --dry-run
bash Install-Song-Mapper.command --arch x86_64
bash Install-Song-Mapper.command --reaper-app "/Applications/REAPER.app" --resource-path "/path/to/REAPER/resources"
```

`--dry-run` makes no changes or downloads, so it does not verify network availability or release contents. Standalone installers always fetch their pinned release, even when local source files happen to be nearby. `--arch x86_64` supports Intel REAPER on an Apple Silicon Mac with Rosetta already installed; the default selects the hardware's native architecture. `--no-launch` installs files only; load the installed `Finish Installation.lua` through Actions to complete verification and registration. Standard resource paths are detected automatically. For portable/custom installs, provide the actual resource path; the registration script verifies it against the running REAPER instance and refuses a mismatch.

## Manual installation on a fresh computer

**ReaPack is a third-party extension; it is not included with a fresh REAPER install.** Install the components in this order: **REAPER → ReaPack → ReaImGui → Song Mapper**. Internet access is needed for the downloads; Song Mapper itself runs locally.

| Component | Purpose | Required version |
| --- | --- | --- |
| [REAPER](https://www.reaper.fm/download.php) | Runs the script and owns the song project | 7.82 or newer |
| [ReaPack](https://reapack.com/) | Installs and updates ReaImGui | Current stable build for your REAPER platform |
| ReaImGui | Provides Song Mapper's editor window | 0.10 or newer |
| Song Mapper | This repository's Lua script and supporting modules | Download together |

Lua is included with REAPER. You do **not** need Python, a separate Lua installation, SWS, Git, or a compiler to use Song Mapper. Testing so far has been on macOS Apple Silicon; the manual installation paths below also cover Windows and Linux, but those platforms have not yet been integration-tested.

### 1. Install REAPER and locate its resource folder

1. Install REAPER from its official download page and launch it once.
2. Choose **Options → Show REAPER resource path in explorer/finder** (wording varies by operating system).
3. Keep that folder open. This is the resource folder for the REAPER installation you are actually running, including portable installations. It is not the application bundle or your audio plug-in/VST folder.

### 2. Install ReaPack separately

1. Download ReaPack from [reapack.com](https://reapack.com/). Choose the build matching your operating system **and the architecture of REAPER**: for example, Apple Silicon/ARM64 versus Intel/x86_64 on Mac. If REAPER runs under Rosetta, match the Intel REAPER process.
2. Quit REAPER completely.
3. Copy the downloaded ReaPack extension file into **`UserPlugins`** inside the resource folder from step 1. Extract the download first if it is an archive; create `UserPlugins` if necessary. Native extension files use `.dylib` on macOS, `.dll` on Windows, and `.so` on Linux.
4. Relaunch REAPER. Verify that **Extensions → ReaPack** is now available.

Typical resource locations are shown below, but the folder opened by REAPER is the source of truth:

| System | Typical resource folder |
| --- | --- |
| macOS | `~/Library/Application Support/REAPER/` |
| Windows | `%APPDATA%\REAPER\` |
| Linux | `~/.config/REAPER/` |
| Portable installation | The resource folder of that portable installation |

See the official [ReaPack installation guide](https://reapack.com/user-guide#installation) for platform-specific requirements and troubleshooting.

### 3. Install ReaImGui through ReaPack

1. Choose **Extensions → ReaPack → Browse packages**.
2. Search for **ReaImGui**. Select **ReaImGui: ReaScript binding for Dear ImGui** by cfillion, from the **ReaTeam Extensions** repository. Choose the extension itself, not a script whose title merely mentions ReaImGui.
3. Right-click it, select **Install** for a stable version of at least 0.10, and click **Apply**. Check that the transaction report shows no errors.
4. Quit and restart REAPER again so the native extension loads.

If the package is missing, check that **ReaTeam Extensions** is enabled in **Extensions → ReaPack → Manage repositories**, then use **Synchronize packages** and search again. ReaImGui's [upstream project](https://codeberg.org/cfillion/reaimgui) documents its distribution through this default repository.

### 4. Download and install Song Mapper

1. Open [this GitHub repository](https://github.com/thothlogos/reaper-song-mapper), select **Code → Download ZIP**, and extract it. Alternatively, clone the repository if you use Git.
2. In REAPER's resource folder, create **`Scripts/Song Mapper`**.
3. Copy **`Song Mapper.lua`** and the entire **`song_mapper`** folder into it. Do not copy only the main Lua file, and do not flatten the module folder. The resulting layout must be:

```text
REAPER resource folder/
└── Scripts/
    └── Song Mapper/
        ├── Song Mapper.lua
        └── song_mapper/
            ├── compat.lua
            ├── codec.lua
            ├── model.lua
            ├── project.lua
            ├── session.lua
            └── ui.lua
```

The README, tests, and example project are optional for installation. Keep `examples/Sample Song.rpp` somewhere convenient if you want to try the sample. Song Mapper is currently installed manually; it is not published as a ReaPack package.

4. In REAPER, open **Actions → Show action list** and select the **Main** section.
5. Choose **New action → Load ReaScript**, select the installed **`Song Mapper.lua`**, and click **Open**.
6. Select **Script: Song Mapper.lua** in the action list and click **Run**. The Song Mapper window should open.

You can instead register the script directly from a stable checkout. Keep that checkout in place: REAPER remembers the script's full path.

### 5. Add the toolbar button and verify installation

1. Right-click an empty part of REAPER's main toolbar and choose **Customize toolbar**.
2. Click **Add**, search for **Song Mapper**, select **Script: Song Mapper.lua**, and click **Select/close**.
3. Click **OK** to save the toolbar. The new button opens Song Mapper. The toolbar editor's **Edit** menu lets you customize its text or icon.
4. In a new, empty project, open Song Mapper and click **Load example**, then **Apply Song Map**. You should see six colored regions (including Count-in), with tempo changes between 110 and 120 BPM.
5. Enable REAPER's metronome and play from the start. Save the project if you want to keep this example.

### Updates and troubleshooting

- **No Extensions → ReaPack menu:** confirm the file is in the active REAPER resource folder's `UserPlugins`, that its architecture matches REAPER, and that REAPER was fully restarted. Consult the official ReaPack guide for any OS-specific loading error.
- **Song Mapper reports missing ReaImGui:** install the extension as described above and restart REAPER. Updating it through ReaPack also requires a restart.
- **“Module song_mapper… not found”:** restore the entire `song_mapper` folder beside `Song Mapper.lua`, keeping the directory structure above.
- **Action points to a missing file:** reload the script from its new location and update the toolbar action if you moved the installation.
- **Apply is disabled:** read the explanation at the bottom of the window. Start with an empty project and stop playback. See [Revisit a map](#revisit-a-map) for the other safeguards.
- **“Script is running in background”:** choose **Cancel** to keep the existing draft. Close the existing Song Mapper window using its **Close** button before reopening. Forcibly terminating the script discards its draft.

To update Song Mapper, close its window, replace both the main script and the module folder with files from the same download, then reopen it. Keep the install path unchanged so the toolbar continues working. ReaPack updates ReaImGui separately; it does not update Song Mapper.

## Map a song

1. Start with a new project. Tracks, routing, and effects may already be present, but there must be no audio/MIDI/media items or existing multi-point tempo map.
2. Click **Song Mapper**, then **Add section**. Choose a section type, measures, BPM, and time signature. Select **Custom** to enter your own label.
3. Add the remaining sections. New rows inherit the preceding row's settings. Use **Duplicate**, **Up**, **Down**, and **Delete** to arrange the song.
4. Set **Count-in measures**: the default is two; zero disables it. This is an actual region at the project start, using the first section's tempo and meter. It is separate from REAPER's recording count-in setting.
5. Review the measure ranges and duration. Click **Apply Song Map**, enable REAPER's metronome, and save the project normally.

The first new section defaults to four measures, 120 BPM, and 4/4. Repeated labels are numbered in song order; a label used only once stays unnumbered. Section colors are consistent by type.

The preview uses measure 1 for the physical project start. Use a standard project starting-measure offset of zero so the ruler's displayed numbers match. Song Mapper does not change your ruler display or metronome enable/accent settings; choose **Measures.Beats** from REAPER's ruler menu if desired.

**BPM always means quarter notes per minute.** At 120 BPM, one 4/4 measure lasts two seconds, one 6/8 measure lasts 1.5 seconds, and one 7/8 measure lasts 1.75 seconds. The duration estimate assumes project playback rate 1.0. Tempo changes are immediate, with a tempo/time-signature marker at every section start, including consecutive sections that share a tempo.

Supported inputs: 1–10,000 whole measures per section, 0–10,000 count-in measures, BPM 1–960 (fractions allowed), numerator 1–64, and denominator 1, 2, 4, 8, 16, 32, or 64. A map may contain up to 1,000 sections and 1,000,000 total measures. Custom labels allow up to 120 UTF-8 bytes and cannot contain control characters.

## REAPER version compatibility

**7.82 is the minimum supported version, not an exact requirement.** Song Mapper accepts **7.82, 7.83, 7.84, 7.85, and later releases** without an upper version limit. Version comparisons use separate major/minor numbers, so 7.100 and 8.0 are accepted too. The macOS installer and runtime both check the minimum; startup also checks that the required scripting functions exist before opening the editor or registering the action.

| REAPER version | Current evidence |
| --- | --- |
| 7.82 | Full integration suite exercised on the development Mac |
| 7.83–7.85 | Expected compatible: version-gate tests pass; official release notes reviewed; all 36 required core API/helper names appear in the 7.85 reference. Full REAPER integration runs on these versions are still pending. |
| Later stable releases | Accepted by design; required capabilities are checked at startup. Future behavior cannot be guaranteed without testing. |
| Before 7.82 | Outside the supported/tested range; installer and startup refuse it. |

The [7.83–7.85 release notes](https://www.reaper.fm/whatsnew.txt) do not document relevant breaking changes to the tempo, measure, marker, or project-state calls used here. The [7.85 API reference](https://www.reaper.fm/sdk/reascript/reascripthelp.html) retains the older marker APIs used for compatibility with 7.82; newer region/marker APIs are not required.

Version-related snags to keep in mind:

- **ReaImGui has its own version/API contract.** We request its `0.10` compatibility API, rather than binding to the installed extension's newest API. Existing newer installations are reused if that API loads successfully; incompatible extensions produce a startup explanation. The automatic fresh install pins 0.10.0.5 for reproducibility.
- **REAPER version, macOS version, and CPU architecture are separate requirements.** On older Macs choose the vendor's older-OS-compatible Intel REAPER build; newer Universal builds may require a newer macOS. Matching the REAPER process architecture remains essential for native extensions.
- **API availability does not prove identical behavior.** Tempo-envelope point metadata and undoable master-track data are compatibility-sensitive areas. After a REAPER or ReaImGui update, run `tests/reaper_integration.lua` in disposable projects before relying on the updated workstation. The suite checks Undo/Redo, mixed-meter boundaries, save/reopen, conflict detection, and failed-apply recovery.

REAPER upgrades at the same app/resource location do not require reinstalling Song Mapper. If moving between REAPER installations or resource folders, install/register it in the new resource folder.

## Revisit a map

Applied maps are stored inside the `.rpp` project. Open Song Mapper again to edit them **before recording**. Applying replaces its previous generated regions and tempo map without creating duplicates. Unrelated regions and ordinary markers remain at their original absolute times.

Each successful Apply is one REAPER undo operation. **Undo/Redo restores both the timeline and its matching section list.** An open, unchanged editor follows those revisions automatically. If you have unapplied edits when the applied revision changes, the draft is retained and Apply is disabled until you choose **Reload applied map**.

Song Mapper refuses to apply when:

- The project contains any media item, including an empty item. The saved map remains viewable.
- Playback, pause, or recording is active, or a different project tab is selected.
- A generated region was moved, renamed, recolored, or deleted outside Song Mapper.
- The tempo map or tempo-point metadata was edited outside Song Mapper.
- The saved map cannot be read or a different editor has applied a newer revision.

Undo a manual timeline edit to make the map editable again. Importing hand-built maps, editing a recorded arrangement, ramps, custom click patterns, and audio click-track rendering are outside this version. Once recorded, continue using REAPER's native controls for timeline edits.

Closing an edited draft offers **Apply**, **Discard**, or **Cancel**. Applying updates the project in memory; save the REAPER project to keep it on disk. Unapplied drafts are not stored in the project and will not survive REAPER shutdown or forced script termination.

If an Apply fails partway through, Song Mapper undoes its own changes and verifies recovery. It then commits a recovery checkpoint to prevent ordinary Redo from replaying the failed partial operation. A harmless recovery entry may remain in undo history.

## Example

Use **Load example** or open `examples/Sample Song.rpp`. With the default count-in, the example is:

| Region | Measures | BPM | Meter |
| --- | --- | --- | --- |
| Count-in | 1–2 | 110 | 4/4 |
| Verse 1 | 3–6 | 110 | 4/4 |
| Chorus 1 | 7–8 | 120 | 4/4 |
| Verse 2 | 9–12 | 110 | 4/4 |
| Chorus 2 | 13–14 | 120 | 4/4 |
| Bridge | 15–18 | 120 | 4/4 |

The song has 16 measures plus two count-in measures, lasting approximately **37.82 seconds** at playback rate 1.0. Use **Save As** to make your own copy of the sample.

## Publishing a standalone installer (maintainers)

Create a version tag such as `v1.0.0` pointing to the tested commit that includes the release tooling. In GitHub Actions, run **Build draft release** with that existing tag. The workflow checks out the tag, builds the assets, and creates a **draft** GitHub Release. Review it, then publish it. It refuses to overwrite an existing release.

The release has three matching attachments:

- **`Install-Song-Mapper.command`**: the only file users download and run.
- **`song-mapper-runtime.tar.gz`**: the package downloaded automatically by that installer; keep it attached to the same release.
- **`SHA256SUMS`**: checksums for verification.

To build locally with Python 3 (maintainer-only dependency):

```sh
python3 scripts/build_release.py v1.0.0 --output dist
```

Attach all three files in `dist/` to the release with exactly that tag. Do not upload the repository's unbuilt installer template. The builder embeds the tag and the runtime archive's SHA-256 digest into the installer. The installer never follows `main` or `latest`, and it verifies the archive checksum and exact regular-file manifest before extracting it. Build from the matching tagged checkout. Publish assets as a set and do not replace the archive in an existing release; publish a new version instead.

The download URL targets this public GitHub repository. Fork maintainers must update the repository URL in the installer before building their own releases. HTTPS and checksum verification remain enabled; failed downloads can be retried by rerunning the installer. The release workflow is manual and does not publish releases automatically.

## Repository layout

- `Song Mapper.lua`: the action loaded by REAPER; keep its path stable.
- `song_mapper/`: runtime modules for song data, storage, REAPER integration, draft state, and UI.
- `examples/`: the tracked sample REAPER project, without recordings.
- `tests/`: unit tests, the optional Python runner, and manual REAPER integration scripts. Generated logs and project artifacts are ignored.
- `scripts/build_release.py`: produces reproducible version-pinned standalone release assets.
- `installer/` and `Install Song Mapper.command`: macOS installation and REAPER action registration.
- `.github/workflows/`: automated Lua syntax and unit checks for pushes and pull requests. Real REAPER integration tests remain manual.
- [VALIDATION.md](VALIDATION.md): recorded verification results and platform limitations.

## Development and verification

GitHub Actions uses the same Python runner below with a pinned Lupa binary package containing Lua 5.4. This avoids installing Lua from Ubuntu package mirrors. Python remains a testing dependency only; REAPER users do not need it.

The code is split into a pure song model, a non-executable data codec, a REAPER adapter, draft/revision coordination, and a ReaImGui interface. The installed Song Mapper runtime has no network service or package downloads. The installer downloads release files and missing dependencies during setup.

Run the pure Lua tests from the repository root:

```sh
lua tests/unit.lua
```

If standalone Lua 5.4 is unavailable, the optional Python runner also checks syntax for every Lua file:

```sh
python3 -m venv /tmp/song-mapper-tests
/tmp/song-mapper-tests/bin/pip install --only-binary=:all: -r tests/requirements.txt
/tmp/song-mapper-tests/bin/python tests/run.py
```

Load `tests/reaper_integration.lua` as a REAPER action for the integration suite. It creates disposable tabs, runs against the actual REAPER API, writes `tests/integration-results.txt`, saves intermediate projects under `tests/artifacts/`, and regenerates the sample project. It returns to the original project without editing it. Test tabs remain available for inspection.

Integration coverage includes generation, replacement, unrelated-marker preservation, mixed meters, fractional tempo, Undo/Redo, stale drafts, external edits, media-item guards, playback/recording guards, injected failure recovery, save/reopen, and project-tab binding. The playback-state guard cases inject API return values rather than making an audible recording. `tests/reaper_probe.lua` documents the REAPER persistence behavior that motivated the revision design.

Project extension state itself does **not** participate in Undo on REAPER 7.82. Song Mapper stores immutable revision payloads there and keeps the active revision reference in the master track's undoable `P_EXT` data. Previous payloads remain available for Undo/Redo and are not pruned. The codec parses data without calling `load` or executing project text.

API reference: [REAPER ReaScript](https://www.reaper.fm/sdk/reascript/reascript.php), [REAPER API](https://www.reaper.fm/sdk/reascript/reascripthelp.html), [ReaImGui](https://codeberg.org/cfillion/reaimgui).
