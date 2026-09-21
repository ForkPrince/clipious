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