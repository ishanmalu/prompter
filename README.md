# Prompter

A teleprompter that records. One HTML file, no build step, no dependencies.

The script overlays the camera preview but is **not** in the recording — the
recorder captures the camera stream, not the screen.

## Features

- Script library (saved in `localStorage`)
- Manual scroll: spacebar to pause, arrows to nudge speed, scroll wheel to seek
- **Voice follow** — reads along with you and keeps pace, so you can ad-lib and
  pause without the text running away (Chrome only)
- Records to MP4 where Chrome supports it, WebM otherwise
- Camera/mic picker, up to 4K, 24/30/60fps, countdown
- Mirror mode for beamsplitter glass rigs
- Adjustable band height, so the text can sit right under the lens

## Running it on your tailnet

```bash
./serve.sh
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

## Running it locally only

```bash
python3 -m http.server 8080
```

`http://localhost:8080` is a secure context, so the camera works there too.

## Keyboard

| Key | Action |
|---|---|
| <kbd>Space</kbd> | Play / pause |
| <kbd>↑</kbd> <kbd>↓</kbd> | Nudge position |
| <kbd>←</kbd> <kbd>→</kbd> | Slower / faster |
| <kbd>R</kbd> | Start / stop recording |
| <kbd>Home</kbd> | Back to top |

## Known limits

- **Takes live in the tab.** They're object URLs in memory — download the ones
  you want before reloading. The page warns you on unload if any are pending.
- **Voice follow is Chrome-only** and sends audio to Google for recognition, so
  it needs an internet connection. Manual mode works fully offline.
- **iOS Safari** has no `webkitSpeechRecognition`, and `MediaRecorder` there is
  unreliable. Treat the phone as a viewing device, not a recording one.
- **No manual focus/exposure.** The browser doesn't expose them meaningfully.
  If you want real camera control, film on the phone and use this as the
  prompter only.

## Tip: get a good sensor

A laptop webcam is the weak link. On a Mac, **Continuity Camera** makes your
iPhone a webcam — pick it in the Camera tab and you get the iPhone sensor
through `getUserMedia` like any other device.

## License

MIT
