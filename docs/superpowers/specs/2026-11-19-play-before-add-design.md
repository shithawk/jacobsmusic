# Play-before-add for YouTube and SoundCloud

Date: 2026-11-19  
Apps: jacobsmusic, jorismusic, waynesmusic, dansmusic, stefsmusic

## Problem

Adding a YouTube or SoundCloud link only checks oEmbed metadata. Tracks that cannot actually play (dead videos, geo blocks, SoundCloud AD_SUPPORTED autoplay refusal) are still saved. Paste shows limited status; typed-link add is quieter still.

## Goal

Hard-gate adds: only save a streaming track after a real PLAY signal from a hidden probe. Show clear status while checking. Reject (do not save) if playback does not start on its own.

## Non-goals

- Local file / Mac catalog downloads
- Rebuilding `youtube/videos.txt` or `youtube/catalog.json`
- Changing playback of already-saved tracks
- Letting the user tap the SoundCloud embed during the check

## Approved approach

Hidden probe during Add (Approach A). Reject SoundCloud tracks that refuse autoplay (option 1).

## User-facing flow

Applies to **Paste a copied link** and **Add this link** on all five players.

1. Parse URL → invalid or duplicate → error, no save
2. Status **Checking link…** → oEmbed (title, artist; SoundCloud `streamRef`)
3. Status **Trying playback…** → hidden YouTube or SoundCloud probe
4. Real PLAY within **8 seconds** → stop probe → `putTrack` → success UI
5. Timeout or error → tear down probe → **no save** → failure UI

### Success UI

- Paste / confirm dialog: status **Added**, show title/subtitle, **Play** and **Done**
- Typed link: clear input, close add sheet (current behavior), notice **Added [title]**

### Failure UI

- Paste / confirm: status **Couldn’t play this song. It wasn’t added.**
- Typed link: `add-error` with the same message (or oEmbed/parse errors as today)

### Other status / errors (unchanged meaning)

- Copy a YouTube or SoundCloud link first.
- Use a YouTube or SoundCloud link.
- That song is already in the list.

## Probe behavior

### Shared

- Do not change the main now-playing queue or transport selection
- Tear down probe iframe/player on success or failure
- Prefer muted / volume 0 so a brief probe is less disruptive
- Timeout: **8s** from probe start until PLAY confirmed

### YouTube

- Use existing IFrame API load path (or a dedicated off-screen mount)
- Success = `YT.PlayerState.PLAYING` (BUFFERING alone is not enough)
- Then stop/destroy the probe player

### SoundCloud

- Use Widget API with `auto_play` + `play()` after READY
- Success = Widget `PLAY` event
- No user tap during the check; AD_SUPPORTED / autoplay-blocked tracks are rejected
- Then pause and remove the probe iframe

## Implementation notes

- Centralize in something like `probeStreamingPlayback(parsed, meta)` called from `addLink` **before** `putTrack`
- Keep oEmbed failure messages distinct from play-probe failure when possible
- Bump `app.js` query + service worker cache on each player after the change
- Mirror the same logic across all five `web/app.js` trees

## Success criteria

- Playable YouTube link: status steps, then saved and listed
- Playable SoundCloud (autoplay OK): same
- Unplayable / autoplay-blocked SoundCloud: not saved; clear failure message
- Dead or restricted YouTube: not saved; clear failure message
- Duplicate / bad URL: existing errors; no probe
- Main player state unchanged after a failed or successful add (except explicit Play from confirm)

## Test plan

1. Add a known-good YouTube URL via paste and via typed field → Added, plays from library
2. Add a known-good SoundCloud URL that autoplays (e.g. existing Argument-style track) → Added
3. Add Sea Lemon Slow Burn (AD_SUPPORTED) → rejected, not in library
4. Add a nonsense / private YouTube id → rejected
5. Add a duplicate → already-in-list, no second save
6. Confirm now-playing does not jump to an unrelated track after a failed probe
