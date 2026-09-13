# Performance

Captured on a physical Galaxy S24 and iPhone 16 in profile mode. Your hardware will differ. Full
method and numbers live in [`benchmark/`](../benchmark/README.md).

> **Two fixes landed after these runs, so the charts are due a recapture.** iOS was inheriting a
> Vision setting that quietly skipped small text, and Android was capturing at 640x480. Both are
> pinned now. Where it changes how to read a number, it's called out below.

## One image

What `TextSight.recognizeImage` costs, by page density. Read the line count beside each bar: a level
that recognizes nothing returns fast, which would otherwise look like a win.

![One-shot recognition latency on device](https://raw.githubusercontent.com/LahaLuhem/text_sight/main/benchmark/reports/one_shot_latency.png)

On Android the level is a no-op, since ML Kit's Latin recognizer has no accuracy dial, so its two
bars land on top of each other. On iOS `fast` is roughly 4x quicker than `accurate`, though some of
that gap is the small-text setting: `fast` here reads less, then nothing, as the pages get denser.

## Live camera

Recognized frames per second over a fixed window, both phones pointed at the same page.

| Platform | Level      | Frame     | Captures/s | Paced by       |
|----------|------------|-----------|-----------:|----------------|
| iOS      | `fast`     | 1080x1920 |       30.0 | the camera     |
| iOS      | `accurate` | 1080x1920 |        4.0 | the recognizer |
| Android  | `fast`     | 480x640   |        5.9 | the recognizer |
| Android  | `accurate` | 480x640   |        6.6 | the recognizer |

Hitting the camera's own frame rate means recognition is keeping up and the camera is the limit.
That's where iOS `fast` sits, at 30/s on a 30 fps camera. The recognizer paces everything else.

Android ran at CameraX's 640x480 default here. It now asks for about 2 MP in 4:3, which roughly
doubles the lines it reads and costs frame rate. `CaptureResolution.low` gets the old speed back.
iOS asks for 1080p.

**Don't read this as iOS versus Android.** The two capture at different sizes and shapes, so they
aren't doing the same work per frame, and both depend entirely on what the camera sees.

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
