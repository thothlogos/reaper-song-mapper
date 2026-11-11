# REAPER Song Mapper

Build your band's song structure as a list of sections, then generate colored regions and a tempo/time-signature map in one operation. REAPER's metronome follows the generated map.

## Install

Requires **REAPER 7.82 or newer** and **ReaImGui 0.10 or newer**. Lua is included with REAPER; Python and SWS are not required.

1. In REAPER, open **Extensions → ReaPack → Browse packages**. Search for **ReaImGui**, right-click **ReaImGui: ReaScript binding for Dear ImGui**, select **Install**, and click **Apply**. Restart REAPER.
2. Keep `Song Mapper.lua` and the `song_mapper` folder together. They can live in this checkout, or copy both into a `Song Mapper` folder under **Options → Show REAPER resource path → Scripts**.
3. Open **Actions → Show action list**, choose the **Main** section, then **New action → Load ReaScript**. Load `Song Mapper.lua` and run it.
4. To add a toolbar button, right-click the main toolbar and choose **Customize toolbar**. Click **Add**, select **Script: Song Mapper.lua**, then **Select/close** and **OK**. You can use the toolbar editor's **Edit** menu to customize the button's text or icon.

For this development checkout, ReaImGui has already been installed and the action registered directly from the checkout. A Song Mapper button has also been added to the main toolbar. Keep the checkout in place, or reload the action from its new location after moving it.

If REAPER asks whether to terminate or launch a running instance, choose **Cancel** to keep the existing draft, or **New instance** to open another window. Close windows through Song Mapper's **Close** button to get the unsaved-draft prompt; forcibly terminating a script discards its draft.

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

## Development and verification

The code is split into a pure song model, a non-executable data codec, a REAPER adapter, draft/revision coordination, and a ReaImGui interface. There is no network service or runtime package download.

Run the pure Lua tests from the repository root:

```sh
lua tests/unit.lua
```

If standalone Lua 5.4 is unavailable, the optional Python runner also checks syntax for every Lua file:

```sh
python3 -m venv /tmp/song-mapper-tests
/tmp/song-mapper-tests/bin/pip install lupa
/tmp/song-mapper-tests/bin/python tests/run.py
```

Load `tests/reaper_integration.lua` as a REAPER action for the integration suite. It creates disposable tabs, runs against the actual REAPER API, writes `tests/integration-results.txt`, saves intermediate projects under `tests/artifacts/`, and regenerates the sample project. It returns to the original project without editing it. Test tabs remain available for inspection.

Integration coverage includes generation, replacement, unrelated-marker preservation, mixed meters, fractional tempo, Undo/Redo, stale drafts, external edits, media-item guards, playback/recording guards, injected failure recovery, save/reopen, and project-tab binding. The playback-state guard cases inject API return values rather than making an audible recording. `tests/reaper_probe.lua` documents the REAPER persistence behavior that motivated the revision design.

Project extension state itself does **not** participate in Undo on REAPER 7.82. Song Mapper stores immutable revision payloads there and keeps the active revision reference in the master track's undoable `P_EXT` data. Previous payloads remain available for Undo/Redo and are not pruned. The codec parses data without calling `load` or executing project text.

API reference: [REAPER ReaScript](https://www.reaper.fm/sdk/reascript/reascript.php), [REAPER API](https://www.reaper.fm/sdk/reascript/reascripthelp.html), [ReaImGui](https://codeberg.org/cfillion/reaimgui).
