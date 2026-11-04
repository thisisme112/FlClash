# Vantage maintenance

The fork keeps the network dashboard, route animation, Net.Coffee assessment and
homepage controls as regular commits on top of upstream main. Scheduled builds
merge upstream into that history; they never reset to upstream or overlay a stale
copy of the application.

`sync-build.yaml` runs daily at 20:17 UTC (04:17 Asia/Shanghai) and on changes to
the fork's default `feat/dot-matrix` branch. It reads Flutter, Go and NDK pins from
upstream's build workflow. `tool/sync_upstream.py` preserves the fork's workflows,
merges independent ARB changes as JSON, and leaves conflicting source edits for
targeted resolution. Generated code is regenerated before analysis and tests.

Automatic repairs cover regenerated localization/model/provider output, formatting,
and Dart's supported fixes. A repaired source is committed only after analysis and
the root tests pass. The shared packaging workflow then compiles Windows x64 and
Android ARM64 from the exact verified source commit. Build artifacts include that
commit and are retained for 90 days. Each job summary contains a public
nightly.link download URL for its exact artifact ID.

`build-recovery.yaml` reads completed job logs from the Actions API and selects
the failed step by its timestamps and retries a clearly
temporary infrastructure failure once. Source conflicts, compiler errors, access
denials and repeated failures retain diagnostics and stop. There is no mailbox
reader or unattended AI code editor in this setup.

Net.Coffee caches risk data by CIDR. A different returned IP is accepted only when
both it and the queried IP fall inside the supplied, valid CIDR of the same address
family. The displayed address always remains the queried IP. Missing or unrelated
data never becomes a score.

On Windows, web links resolve the registered browser executable and pass the URL
as one argument, avoiding a malformed browser association command template.
Packaged browsers without an executable association retain normal shell activation.
