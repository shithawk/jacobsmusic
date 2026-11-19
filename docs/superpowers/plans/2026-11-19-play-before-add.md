# Play-before-add Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Only save YouTube/SoundCloud links after a hidden probe confirms real PLAY; show Checking link… / Trying playback… status on all five players.

**Architecture:** Extend `addLink` to report status, call oEmbed, then `probeStreamingPlayback` (dedicated off-screen YouTube player or SoundCloud iframe). Save with `putTrack` only after PLAY within 8s. Mirror the same `app.js` changes across jacob/jori/wayne/dan/stef and bump shell cache versions.

**Tech Stack:** Vanilla JS PWAs, YouTube IFrame API, SoundCloud Widget API, IndexedDB `putTrack`, existing `#link-confirm` / `#add-error` / `setNotice` UI.

## Global Constraints

- Timeout: 8 seconds from probe start until PLAY
- Success: YouTube `YT.PlayerState.PLAYING` only; SoundCloud Widget `PLAY` only
- Reject autoplay-blocked SoundCloud (no tap during check)
- Do not change main now-playing queue during probe
- Probe muted / volume 0; tear down after pass or fail
- Failure copy: `Couldn’t play this song. It wasn’t added.`
- Status copy: `Checking link…`, `Trying playback…`, success `Added`
- Apply to all five: jacobsmusic, jorismusic, waynesmusic, dansmusic, stefsmusic

## File map

- Modify: each app’s `web/app.js` — status callbacks, `probeStreamingPlayback`, gate `addLink`
- Modify: each app’s `web/index.html` + `web/sw.js` — bump `app.js?v=` and `CACHE`
- Spec: `docs/superpowers/specs/2026-11-19-play-before-add-design.md`

---

### Task 1: Probe helpers + gated addLink in jacobsmusic

**Files:**
- Modify: `/Users/jacobward/jacobsmusic/web/app.js`
- Modify: `/Users/jacobward/jacobsmusic/web/index.html` (app.js version)
- Modify: `/Users/jacobward/jacobsmusic/web/sw.js` (CACHE + app.js version)

**Interfaces:**
- Produces: `setLinkAddStatus(text)`, `probeStreamingPlayback({ source, mediaRef, streamRef }) → Promise<void>`, `addLink(text, { onStatus })` gated before `putTrack`
- Consumes: `fetchOEmbed`, `loadYouTubeAPI`, `loadSoundCloudAPI`, `putTrack`, `parseLink`, `linkRefsMatch`

- [ ] **Step 1: Add status helper and probe functions near `addLink`**

Add after `fetchOEmbed` (or immediately before `addLink`):

```javascript
const LINK_PLAY_FAIL = "Couldn’t play this song. It wasn’t added.";
const LINK_PROBE_MS = 8000;

function setLinkAddStatus(text) {
  if (linkConfirmVisible()) showLinkConfirm(text);
  else {
    const button = document.getElementById("add-link");
    if (button) button.textContent = text || "Add this link";
  }
}

function probeStreamingPlayback(parsed, meta) {
  if (parsed.source === "youtube") return probeYouTubePlayback(parsed.mediaRef);
  if (parsed.source === "soundcloud") {
    const url = String((meta && meta.streamRef) || parsed.mediaRef || "").trim();
    return probeSoundCloudPlayback(url);
  }
  return Promise.reject(new Error(LINK_PLAY_FAIL));
}

function probeYouTubePlayback(videoId) {
  return new Promise(async (resolve, reject) => {
    let settled = false;
    let player = null;
    let mount = null;
    const finish = (ok, err) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try {
        if (player && player.destroy) player.destroy();
      } catch { /* probe teardown */ }
      if (mount && mount.parentNode) mount.remove();
      if (ok) resolve();
      else reject(err || new Error(LINK_PLAY_FAIL));
    };
    const timer = setTimeout(() => finish(false), LINK_PROBE_MS);
    try {
      loadYouTubeAPI();
      await new Promise((ready, fail) => {
        const started = Date.now();
        const wait = () => {
          if (window.YT && window.YT.Player) return ready();
          if (Date.now() - started > LINK_PROBE_MS) return fail(new Error(LINK_PLAY_FAIL));
          setTimeout(wait, 50);
        };
        wait();
      });
      mount = document.createElement("div");
      mount.id = "yt-probe-mount";
      mount.setAttribute("aria-hidden", "true");
      mount.style.cssText = "position:fixed;left:-9999px;top:0;width:320px;height:180px;opacity:0;pointer-events:none;";
      document.body.append(mount);
      player = new YT.Player("yt-probe-mount", {
        width: 320,
        height: 180,
        videoId: videoId,
        playerVars: {
          autoplay: 1,
          playsinline: 1,
          rel: 0,
          controls: 0,
          fs: 0,
          origin: window.location.origin
        },
        events: {
          onReady: (event) => {
            try {
              if (event.target.mute) event.target.mute();
              if (event.target.setVolume) event.target.setVolume(0);
              if (event.target.playVideo) event.target.playVideo();
            } catch { /* wait for state */ }
          },
          onStateChange: (event) => {
            if (event.data === YT.PlayerState.PLAYING) finish(true);
          },
          onError: () => finish(false)
        }
      });
    } catch {
      finish(false);
    }
  });
}

function probeSoundCloudPlayback(playURL) {
  return new Promise(async (resolve, reject) => {
    let settled = false;
    let frame = null;
    let widget = null;
    const finish = (ok) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      try {
        if (widget && widget.pause) widget.pause();
      } catch { /* probe teardown */ }
      if (frame && frame.parentNode) frame.remove();
      if (ok) resolve();
      else reject(new Error(LINK_PLAY_FAIL));
    };
    const timer = setTimeout(() => finish(false), LINK_PROBE_MS);
    try {
      await loadSoundCloudAPI();
      if (!window.SC || !window.SC.Widget) return finish(false);
      frame = document.createElement("iframe");
      frame.id = "sc-probe-frame";
      frame.setAttribute("allow", "autoplay; encrypted-media");
      frame.setAttribute("aria-hidden", "true");
      frame.style.cssText = "position:fixed;left:-9999px;top:0;width:320px;height:180px;opacity:0;pointer-events:none;border:0;";
      frame.src =
        "https://w.soundcloud.com/player/?" +
        "url=" +
        encodeURIComponent(playURL) +
        "&auto_play=true&hide_related=true&show_comments=false&show_user=false&show_reposts=false&visual=false&show_teaser=false";
      document.body.append(frame);
      widget = window.SC.Widget(frame);
      widget.bind(window.SC.Widget.Events.READY, () => {
        try {
          if (widget.setVolume) widget.setVolume(0);
          widget.play();
        } catch { /* wait for PLAY */ }
      });
      widget.bind(window.SC.Widget.Events.PLAY, () => finish(true));
      if (window.SC.Widget.Events.ERROR) {
        widget.bind(window.SC.Widget.Events.ERROR, () => finish(false));
      }
    } catch {
      finish(false);
    }
  });
}
```

- [ ] **Step 2: Rewrite `addLink` to status + probe before save**

Replace `addLink` with:

```javascript
async function addLink(text, options) {
  const onStatus = options && typeof options.onStatus === "function" ? options.onStatus : null;
  const status = (text) => {
    if (onStatus) onStatus(text);
    else setLinkAddStatus(text);
  };
  const parsed = parseLink(text);
  if (!parsed) throw new Error("Use a YouTube or SoundCloud link.");
  if (state.tracks.some((track) => linkRefsMatch(track, parsed))) {
    throw new Error("That song is already in the list.");
  }
  status("Checking link…");
  const meta = await fetchOEmbed(parsed);
  status("Trying playback…");
  await probeStreamingPlayback(parsed, meta);
  const track = {
    id: parsed.source + ":" + parsed.mediaRef,
    title: meta.title,
    artist: meta.artist,
    source: parsed.source,
    mediaRef: parsed.mediaRef,
    bytes: 0,
    createdAt: Date.now()
  };
  if (parsed.source === "soundcloud" && meta.streamRef) track.streamRef = meta.streamRef;
  await putTrack(track);
  state.tracks = sortTracks(state.tracks.concat(track));
  return track;
}
```

- [ ] **Step 3: Wire paste + typed status**

In `addPastedLink`, before `addLink`, ensure confirm shows Checking; pass status:

```javascript
showLinkConfirm("Checking link…");
const track = await addLink(text, {
  onStatus: (message) => showLinkConfirm(message)
});
```

In `addLinkText`, pass:

```javascript
const track = await addLink(text, {
  onStatus: (message) => {
    document.getElementById("add-link").textContent = message;
  }
});
```

Map probe failures to `LINK_PLAY_FAIL` in catch if needed (errors already throw that message).

- [ ] **Step 4: Bump jacobsmusic cache**

`app.js?v=159` → `160`, `jacob-shell-v236` → `v237` in index.html + sw.js.

- [ ] **Step 5: Manual verify on jacobsmusic**

Open `http://127.0.0.1:8092/`, hard refresh, add a playable YouTube link and Sea Lemon Slow Burn; confirm Slow Burn rejected and not in IndexedDB.

- [ ] **Step 6: Commit jacobsmusic app changes** (only if user asked; otherwise leave uncommitted until asked)

---

### Task 2: Mirror to jori, wayne, dan, stef

**Files:**
- Modify: each `/Users/jacobward/{jorismusic,waynesmusic,dansmusic,stefsmusic}/web/app.js`
- Modify: matching `index.html` + `sw.js` version bumps

- [ ] **Step 1:** Apply the same `setLinkAddStatus`, probe helpers, `addLink`, paste/typed wiring as Task 1
- [ ] **Step 2:** Bump each app’s `app.js?v=` and `CACHE` by 1
- [ ] **Step 3:** Grep all five for `probeStreamingPlayback` and `Trying playback` to confirm presence

## Spec coverage

| Spec item | Task |
|-----------|------|
| Checking / Trying / Added status | Task 1 |
| Probe before putTrack | Task 1 |
| 8s timeout, PLAY-only | Task 1 |
| Reject SC autoplay fail | Task 1 |
| Paste + typed | Task 1 |
| All five players | Task 2 |
| No main queue change | Task 1 probes off-screen |
