# Modal visible impressions and repeat presentation

For bottom sheets, dialogs/modals and full screen in-app windows,
`visible_impression` / WRIMP means **the window content actually appeared**:
the first confirmed painted frame intersecting the screen while the app is
active. There is no minimum viewing duration or visibility percentage.
Creating a widget, `/choose`, loading content and painting only the scrim do
not qualify. The content paint check follows the opening animation, including
frames where retained layers move without repainting their children.

Explicit close (swipe, X, Back, dismiss/“Not now”) shares the same synchronous
once flag as the paint check. It cannot lose a confirmed appearance or create
a second event. Navigation disposal, backgrounding and cancellation before
appearance never infer an impression. An opening that never appeared releases
its reservation. `OPEN_STEP`, including form-driven steps, retains the opening
and its root tracking URLs; step-specific content IDs do not create new WRIMP.
The backend `visible_impression` event is used even without a custom
`onVisibleImpression` action.

Automatic `trackView` and `triggerEvent` reserve by section, user and campaign
ID before `/choose`; modal anchor presentations also use this gate. Requests
capture the user and screen generation, reusing the SDK's stale route/user
guard. Parallel requests cannot both present. Responses begun before the WRIMP
acknowledgement cannot reopen the campaign after that acknowledgement.
Unshown reservations expire after 60 seconds and are invalidated by a newer
screen/user. A visible reservation bridges the asynchronous durable write;
its own timeout is 60 seconds if no usable event was recorded.

Before network delivery, all WRIMP URLs from an opening are saved together as
one `OutboxKind.engagement` entry in the existing SharedPreferences outbox.
The entry includes the original user snapshot, section, API key, campaign ID
and unmodified URLs. The URLs already bind server user/event identity; delivery
never resolves the current user or appends new user data. After a user or SDK
configuration change, old entries are **sent with their original URLs and API
key**, so a real prior impression is retained without attributing it to the
new user. No new endpoint or server schema is required.

The durable entry protects the campaign across screens, UI destruction and
process restarts until all URLs return HTTP 2xx. Network errors and HTTP
408/429/5xx use the existing outbox backoff, resumed on app start, foreground,
a successful online request or `flushQueue()`. Unlike optional offline events,
modal WRIMP is always persisted and drained even when
`OfflineQueueSettings.enabled` is false. Server failures are retried until the
queue's `maxAge` rather than dropped after five failures. The existing
`maxAge` (default seven days), `maxEntries` (default 500), permanent rejection
and explicit `clearQueue()` policy still apply. Missing URLs and storage
failures are reported; they do not count as successful delivery. A lost or
expired event cannot suppress a campaign forever.

After successful delivery, fresh requests use server frequency caps. There
is no permanent or session-long local cap, preserving “no limit” and “every
page view” behavior. Section and user keys are independent. Retrying a group
can repeat an already accepted URL if another URL failed; URLs/event IDs stay
the same, but exactly-once server analytics is not guaranteed.

Inline-block and product-card detectors/tracking are unchanged. Snackbar and
tooltip use separate detector paths and are unchanged.

## Verification

Run `flutter test` and `flutter analyze`. Regression tests cover animated
appearance, 100–400 ms close paths, duplicate signals, unshown/background
content, steps, parallel/stale responses, durable enqueue before HTTP, retry
and queue reload with the original identity and authorization.

Before release, verify swipe/Back and the first animation frame on physical
Android/iOS devices, then test a monthly-capped campaign against a staging
Gateway while offline and after reconnecting. Widget and local HTTP tests do
not verify Gateway cap persistence or device compositor output.
