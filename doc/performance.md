# Performance

Captured on a physical Galaxy S24 and iPhone 16 in profile mode. Your hardware will differ. Full
method and numbers live in [`benchmark/`](../benchmark/README.md).

## One image

What `TextSight.recognizeImage` costs, by page density. Read the line count beside each bar: a level
that recognizes nothing returns fast, which would otherwise look like a win.

![One-shot recognition latency on device](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/one_shot_latency.png)

On Android all four bars land on top of each other. ML Kit's Latin recognizer has no accuracy dial
and handles correction itself, so neither knob does anything there.

On iOS both knobs bite, and they stack:

| iOS, the 63-line page | p50 |
|---|--:|
| `fast` | 101 ms |
| `fast` + correction | 199 ms |
| `accurate` | 404 ms |
| `accurate` + correction | 736 ms |

Roughly 4x for the level, then roughly double again for correction. On pages this clean both levels
read every line, so `fast` is the one to reach for. A live scene is a different story, see below.

Neither iOS level reads the 127-line page at all. It renders at 15.8 pt, and Vision returns nothing
at that size here, so those four bars time a miss rather than a recognition. Android reads 126 of
the 127.

## Live camera

Recognized frames per second over a fixed window, both phones pointed at the same page at the same
time.

| Platform | Level | Frame | Captures/s | Lines read |
|----------|-------|-------|-----------:|-----------:|
| iOS | `fast` | 1080x1920 | 19.0 | 9 |
| iOS | `fast` + correction | 1080x1920 | 16.9 | 9 |
| iOS | `accurate` | 1080x1920 | 5.0 | 15 |
| iOS | `accurate` + correction | 1080x1920 | 3.9 | 13 |
| Android | any | 1440x1920 | 5.1 to 5.5 | 15 to 17 |

Here `accurate` earns its cost. It pulls noticeably more text out of the same frame, which the
one-image numbers hide because those pages are clean enough for either level to read everything.

The recognizer paces every row above. If you ever see the gap sit at the camera's own frame interval
(about 33 ms at 30 fps), that means recognition is keeping up and the camera is the limit instead.

Android asks CameraX for about 2 MP in 4:3 and got 1440x1920 here. `CaptureResolution.low` trades
lines for frame rate. iOS asks for 1080p.

**Don't read this as iOS versus Android.** The two capture at different sizes and shapes, so they
aren't doing the same work per frame, and both depend entirely on what the camera sees.

> Phones boost when they're cool. These are the settled numbers, so a short scan will feel quicker
> than this and a long one will drift down to it.

## The transport is not the bottleneck

Results cross from native to Dart as a small per-frame map. Decoding one on the UI isolate costs
**microseconds**: worst case on the slower of the two phones, a dense 127-line frame is 87 µs, or
0.5% of a 60 fps frame budget. So the recognizer's own work sets the pace.

<details>
<summary>Host-measured charts, for the finer sweep a phone run doesn't produce</summary>

![Per-frame decode cost vs frame size](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/decode_vs_lines.png)
![Encoded payload size vs frame size](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/wire_bytes_vs_lines.png)
![Decode cost per realistic OCR profile](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/profile_decode_bars.png)

Leaner wire formats win big in *percent* and stay tiny in absolute microseconds, which is why the
self-describing map stays.

</details>
