# Clipious

[![license agpl v3](https://shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0.en.html)
Android client application for [invidious](https://invidious.io), the privacy focused youtube front end

## Features

- Use own or public  server
- Subscription management
- SponsorBlock + DeArrow (click bait removal)
- Video view/progress tracking
- Playlists
- background playback
- Live stream support
- Android TV ui
- Audio playback
- Video / audio download
- Video filtering
- Return YouTube dislikes

## Custom Features

- **DeArrow improvements**: Normalize video titles and replace more thumbnails
- **Hide videos**: Hide videos from subscriptions (requires an [invidious fork](https://git.serversmp.xyz/TwintStudio/invidious))
- **Video Chapters**: Chapter markers with title popup and highlight track in the player (requires an [invidious fork](https://git.serversmp.xyz/TwintStudio/invidious))
- **Show channel icons on search**: Display channel thumbnails in search results
- **Add video history on TV**: Browse watched videos from the TV home menu
- **TV recommendations**: Show recommended videos right in the player

### Patches from [Videre](https://github.com/DVBeckwitt/Videre)

- Credential leak fix in thumbnail loading
- HTML response crash protection
- Nullable FormatStream fields for compatibility with non-standard instances
- Credential logging removal
- Non-DASH quality selection fix
- Disable Impeller on Android to fix black video on TV
- Comment parsing for current Invidious payloads (singular authorThumbnail, non-list comments)
- Ignore thumbnail errors after leaving a screen
- No-op layout reorder guard and search history on by default when unset
- Maxres-first thumbnails and overlay child stays visible on image failure
- Propagate documents-directory failure instead of falling back to Directory.current
- Deep-link video-id validation and log scrubbing (URLs and cookies)
- Download path traversal protection (safe file ids, joined paths)
- Aspect-ratio guard for missing decoder size and fullscreen bottom inset fix
- Empty-buffer crash guard and re-read saved server after token login
- SponsorBlock skip-loop fix, fetch guards, subtitle bounds check, show zero dislikes
- Duration badges on compact video thumbnails
- Grid aspect ratio scales with text size
- Keep TV settings open while sliders consume remote keys
- Stale video-load guard and async dislike loading
- Search suggestion race fix (per-cubit timer, stale-response guard) and TV history fix
- Stop background playback promptly, owned player-control timers, subscribe-button closed guards
- Comment load guard, keep comments on error, retry button
- Tolerant per-format parsing and channelId-keyed subscription continuations
- Hardened playback fallback (source cap, media-URL validation, no instance credentials to the native player, stale-setup cancellation)
- Bounded quality selection (resolutions from budget-accepted streams, tracks from built sources)
- Per-source media headers and resolution fallback chain in the player
- Invidious DASH 400 "No check ID" fix (manifest resolver, one retry, route-health cache)
- Hardened Invidious sessions (status code + HTML diagnostics, session validation, no infinite subscribe retry)
- 429 handling with Retry-After, duplicate video-request coalescing, 15 s browse cache, Accept: application/json
- Dropped playback commands fix (play/pause intent survives source setup)
- Keep playback position when switching to audio; ignore zero-progress until the initial seek finishes
- Queue, pagination, FileDB and redirect fixes (queue correctness, Timer lifecycle, cursor restore on failure, serialised atomic FileDB writes, origin-scoped redirects, sequential history sync, serialised server edits)
- Exact resume position (saved position/duration, resume to the exact second, transactional watched-status updates)
- Mini-player drag fixes (cancel settles to mini/big, drag state resets, top clamped to the viewport with keyboard inset)
- Audio-focus and MediaSession sync (play/pause re-emit on ready, admitted position published before play/rate events)
- Relaxed server-setup thumbnail validation (one usable resolved thumbnail is enough)

## Installation

Download the latest APK from the [Releases Section](https://github.com/ForkPrince/clipious/releases/latest).

## Screenshots

### Phone

| | |
|-|-|
| [![Home](./screenshots/mobile-home_small.png)](./screenshots/mobile-home.png) | [![Video](./screenshots/mobile-video_small.png)](./screenshots/mobile-video.png) |
| [![Channel](./screenshots/mobile-channel_small.png)](./screenshots/mobile-channel_small.png) | [![Playlist](./screenshots/mobile-playlist_small.png)](./screenshots/mobile-playlist_small.png) |

### Tablet

| | |
|-|-|
| [![Home](./screenshots/tablet-home_small.png)](./screenshots/tablet-home.png) | [![Video](./screenshots/tablet-video_small.png)](./screenshots/tablet-video.png) |
| [![Channel](./screenshots/tablet-channel_small.png)](./screenshots/tablet-channel_small.png) | [![Playlist](./screenshots/tablet-playlist_small.png)](./screenshots/tablet-playlist_small.png) |

### TV

| | | |
|-|-|-|
| [![Home](./screenshots/tv-home_small.png)](./screenshots/tv-home.png) | [![Home](./screenshots/tv-home-2_small.png)](./screenshots/tv-home-2.png) | [![Video](./screenshots/tv-video_small.png)](./screenshots/tv-video.png) |
| [![Video](./screenshots/tv-video-2_small.png)](./screenshots/tv-video-2.png) | [![Channel](./screenshots/tv-channel_small.png)](./screenshots/tv-channel_small.png) | [![Playlist](./screenshots/tv-playlist_small.png)](./screenshots/tv-playlist_small.png) |
| [![Playlist](./screenshots/tv-playlist-2_small.png)](./screenshots/tv-playlist_small-2.png) | | |

## Credits

This is a fork of [Clipious](https://github.com/lamarios/clipious), licensed under the [GNU Affero General Public License v3.0 or later](./LICENSE).

```text
Clipious code:         Copyright (C) 2023 Paul Fauchon
Videre patches:        Copyright (C) 2026 DVBeckwitt and Videre contributors
ForkPrince patches:    Copyright (C) 2026 ForkPrince
```

Provided without warranty. Users are responsible for complying with laws and terms that apply to their use of this app and their selected Invidious instance.