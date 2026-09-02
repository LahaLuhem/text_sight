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

`one_shot_latency` is honestly *one-shot API latency as an app sees it*: image decode, inference,
native encode and transport, all inside one number. It is not pure inference time. Splitting those
apart needs native timestamps, which is a separate job.
