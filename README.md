# Prompter

A teleprompter that records. One HTML file, no build step, no dependencies.

The script overlays the camera preview but is **not** in the recording — the
recorder captures the camera stream, not the screen.

## Features

- Script library (saved in `localStorage`)
- Manual scroll: spacebar to pause, arrows to nudge speed, scroll wheel to seek
- **Voice follow** — reads along with you and keeps pace, so you can ad-lib and
  pause without the text running away (Chrome and Safari 26+)
- Records to MP4 wherever the browser supports it, which now includes Safari
  and iOS Safari; WebM otherwise
- Takes are kept in IndexedDB, so a reload or a backgrounded tab doesn't
  destroy footage
- Camera/mic picker, up to 4K, 24/30/60fps, countdown
- Mirror mode for beamsplitter glass rigs
- Adjustable band height, so the text can sit right under the lens

## Running it on your tailnet

```bash
./server.py
```

Then open the `https://<machine>.ts.net/` URL it prints, on any device in your
tailnet.

**Why not just `http://100.x.x.x:8080`?** `getUserMedia` requires a secure
context. `localhost` is exempt; a raw tailnet IP over plain HTTP is not, so
Chrome silently refuses camera access. `tailscale serve` fronts the local
server with a real Let's Encrypt cert for your `*.ts.net` name, which clears
the bar on every device.

One-time prerequisites in the Tailscale admin console:

- **MagicDNS** enabled
- **HTTPS Certificates** enabled

The first `tailscale serve` may take a few seconds while it provisions the cert.

To take it down:

```bash
./serve.sh --stop
```

## Mirroring: do it afterwards, not while recording

The app can mirror the recording so the take matches the preview, but on a phone
it is not worth it. Mirroring copies every frame through a canvas before the
encoder sees it, and an iPhone responds by stalling the preview and dropping
frames: a 50-second 1080p take measured **7.6fps**, confirmed with ffprobe on
the AirDropped file. Lost frames cannot be recovered afterwards.

Film with **Record what I see** off, at full frame rate, then flip the file here:

```bash
./mirror.sh ~/Downloads/take-02.mp4
```

Audio is copied untouched and only the video is re-encoded. A 50-second 1080p
take takes about five seconds.

## Getting takes off the phone

The share sheet is the only route from a browser into Photos on iOS, and it is
not a plain copy — takes can arrive re-encoded, which is where frame rate goes
missing. **Send to Mac**, on each take, posts the original bytes to the machine
serving the page instead. They land in `takes/`, untouched, and you can check
what you actually recorded:

```bash
ffprobe -v error -select_streams v:0 \
  -show_entries stream=avg_frame_rate,nb_frames -show_entries format=duration \
  takes/your-take.mp4
```

`avg_frame_rate` there is the truth. If it is healthy but Photos disagrees, the
problem is the trip through the share sheet, not the recording.

This needs `server.py` rather than `python3 -m http.server`, which only serves.

## Keeping it running

`serve.sh` dies with the shell that started it. To have the file server come
back at login instead:

```bash
./install-autostart.sh          # port 8080
./install-autostart.sh 9000     # different port
```

That installs a launchd agent (`dev.ishanmalu.prompter`) with `KeepAlive`, so
the server also restarts if it crashes. It binds `127.0.0.1` on purpose —
`tailscale serve` is what puts it on the tailnet, and it has to, because
`getUserMedia` refuses a plain-HTTP origin. Binding straight to the tailnet IP
would hand you a page whose camera never starts.

The `tailscale serve` config persists across reboots on its own, so it only
needs setting up once:

```bash
tailscale serve --bg 8080
```

Undo the agent with `./uninstall-autostart.sh`, which leaves the serve config
alone.

### Running something else alongside it

`tailscale serve` can host several apps on one machine, on separate HTTPS
ports:

```bash
tailscale serve --bg 8080              # https://<machine>.ts.net/
tailscale serve --bg --https=8443 5005 # https://<machine>.ts.net:8443/
```

Prefer ports over `--set-path`. A path mount only works if the app asks for its
assets relatively; anything requesting `/static/…` or `/api/…` from the root
escapes the mount and hits whatever owns `/`.

## Running it locally only

```bash
python3 -m http.server 8080
```

`http://localhost:8080` is a secure context, so the camera works there too.

## On a phone or tablet

The layout switches to camera-first: the video fills the screen and the controls
live in a bottom sheet you pull up from the menu button.

- **Tap the video** to start/stop scrolling
- **Drag the video** up or down to find your place
- **Swipe the sheet header down** to dismiss it
- Front/back camera swap and fullscreen sit in the button row
- The screen is kept awake while the camera is live
- Recording auto-closes the sheet so the panel is never in the shot
- Takes go through the **share sheet**, which is the only route to Photos or
  Files on iOS — a plain download link dead-ends there
- Takes survive a reload, and iOS dropping a backgrounded tab, because they are
  written to IndexedDB as they finish

Sizing uses `dvh`, so the band stays put when mobile browser chrome slides
away, and safe-area insets keep the HUD clear of the home indicator and notch.

## Keyboard

Desktop only — the shortcut list is hidden on touch layouts.


| Key | Action |
|---|---|
| <kbd>Space</kbd> | Play / pause |
| <kbd>↑</kbd> <kbd>↓</kbd> | Nudge position |
| <kbd>←</kbd> <kbd>→</kbd> | Slower / faster |
| <kbd>R</kbd> | Start / stop recording |
| <kbd>Home</kbd> | Back to top |

## Known limits

- **Takes are stored, not backed up.** They go to IndexedDB under this origin,
  so they survive a reload, but clearing site data removes them and Safari
  evicts unused origins after about seven days. Export anything you want to
  keep. A take that couldn't be written is flagged *in memory only* in the
  list, and the page warns you on unload if one of those is outstanding or a
  recording is still running.
- **A take is written when it stops,** not while it rolls. If the tab is killed
  mid-recording, that take is gone.
- **Voice follow has a language picker** (Prompter tab), defaulting to your
  browser's locale. Recognition accuracy depends on the browser's engine.
- **Voice follow needs browser speech recognition** — Chrome and Safari 26+
  both have it, older Safari does not. Recognition is vendor-hosted, so it
  generally needs a connection. Manual mode works fully offline.
- **Record as MP4, not WebM.** iOS only offers *Save Video* (straight to Photos)
  for MP4; a WebM take can only go to Files. MP4 is the default wherever the
  browser supports it, which now includes Safari.
- The app feature-detects everything and tells you in the Camera tab when a
  browser is missing something, rather than failing silently.
- **No manual focus/exposure.** The browser doesn't expose them meaningfully.
  If you want real camera control, film on the phone and use this as the
  prompter only.

## Browser support

Verified against Safari 26.6.2 (its own engine, not an emulation) and Chrome:

| | Chrome | Safari 26 | iOS Safari |
|---|---|---|---|
| Record (MP4/H.264) | ✅ | ✅ | ✅ |
| Voice follow | ✅ | ✅ | version-dependent |
| Share to Photos / Files | — | ✅ | ✅ |
| Wake lock | ✅ | ✅ | ✅ |
| Element fullscreen | ✅ | ✅ (prefixed) | ✗ (button hidden) |

## Tip: get a good sensor

A laptop webcam is the weak link. On a Mac, **Continuity Camera** makes your
iPhone a webcam — pick it in the Camera tab and you get the iPhone sensor
through `getUserMedia` like any other device.

## License

MIT
