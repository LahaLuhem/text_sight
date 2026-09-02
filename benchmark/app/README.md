# `text_sight` device benchmark host

A minimal Flutter app whose only job is to host the on-device benchmark scenarios under
[`integration_test/`](integration_test/). Modelled on the maintainer's `list_smith` benchmark app.

Scenarios run in profile mode via `flutter drive`, which keeps the VM service the driver needs
(release mode disables it). Each scenario piles records into `binding.reportData`, and
[`test_driver/perf_driver.dart`](test_driver/perf_driver.dart) writes them to the
`--dart-define=OUTPUT` path as JSON matching `harness/result_writer.dart`'s schema.

## Signing, for physical devices

The committed xcconfigs carry a bundle id and no team, which is all a simulator needs. For a real
device, drop your own `ios/Flutter/LocalSigning.xcconfig` (gitignored, same mechanism as the example
app):

```
DEVELOPMENT_TEAM = YOURTEAMID
PRODUCT_BUNDLE_IDENTIFIER = com.yourteam.textsight.bench
```

Debug, Profile and Release all pick it up, and Profile is the one `flutter drive` builds.

## Running

From this directory, with a device attached:

```bash
flutter drive \
  --driver=test_driver/perf_driver.dart \
  --target=integration_test/one_shot_latency_test.dart \
  --profile -d <device-id> \
  --dart-define=ITERATIONS=3 \
  --dart-define=OUTPUT=../results-local/current/one_shot_latency/iterations.json \
  --dart-define=GIT_SHA="$(git rev-parse --short HEAD)" \
  --dart-define=PKG_VERSION=0.2.0
```

Run it once per device. Records carry a `platform` field, so iOS and Android results can be merged
and compared.

## Scenarios

| Scenario | Measures | Needs a camera |
|---|---|:--:|
| `one_shot_latency_test.dart` | `TextSight.recognizeImage` round-trip latency by page profile and recognition level | no |
| `codec_on_device_test.dart` | the codec micro-benchmark on phone silicon, same payloads and candidates as `micro/` | no |
| `live_throughput_test.dart` | recognized frames per second and the gap between them, per level | **yes** |

`one_shot_latency` is honestly *one-shot API latency as an app sees it*: image decode, inference,
native encode and transport, all inside one number. It is not pure inference time. Splitting those
apart needs native timestamps, which is a separate job.

## The live scenario needs a camera

`live_throughput` is the only scenario that opens the camera, which brings two wrinkles.

`flutter drive` uninstalls the app when it finishes, so a permission grant cannot be set up in
advance. The scenario surfaces the prompt and then waits up to 45 seconds. On Android the runner
grants it over adb as soon as the package appears, so it is hands-off. On iOS somebody has to tap
Allow on the device while it waits.

The numbers also depend entirely on what the camera sees, so point it at the same thing every time
if you intend to compare runs. Every row carries the median lines per capture: a zero there means
nothing readable was in frame, and the throughput number says nothing about recognition.
