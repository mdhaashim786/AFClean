# AF Clean

An iPhone storage cleaner. It finds duplicate and near-identical photos,
screenshots, large videos and duplicate contacts, and removes them only after
you have reviewed exactly what will go.

Everything runs on the device. Nothing is uploaded, and nothing is deleted
without explicit approval.

- iOS 17+, iPhone only, portrait, dark.
- SwiftUI, Swift Concurrency, Observation. No third-party dependencies.

## The core loop

**Scan → Review → Clean.** Selections from all four categories collect into one
basket, which becomes a single `CleanupPlan`, which is the only thing that can
be deleted.

## Architecture

Clean Architecture with MVVM in the presentation layer, three layers and a
strict inward dependency rule:

```
Presentation   SwiftUI views + @Observable view models
     │ depends on
     ▼
  Domain       entities, use cases, repository protocols   (Foundation only)
     ▲
     │ implements
   Data        PhotoKit, Contacts, Vision, FileManager
```

- **Domain** imports no framework beyond Foundation. No `Photos`, no `Contacts`,
  no `SwiftUI`. All the interesting logic lives here and can be compiled and
  tested on its own.
- **Presentation** never imports `Photos` or `Contacts`. Views hold no business
  logic; view models talk only to use cases.
- **Data** is the only layer that knows Apple's media frameworks exist, and maps
  `PHAsset`/`CNContact` into domain entities at the boundary.
- `App/AppDependencies.swift` is the composition root — the one place concrete
  implementations are chosen. Everything else is initialiser-injected.

```
AppFactory_StorageCleaner/
├── App/           entry point, composition root, router
├── Domain/        Entities, Repositories (protocols), Services, UseCases
├── Data/          DataSources, Cache, Mappers, Repositories (implementations)
├── Presentation/  one view + view model per screen, plus shared session stores
└── Core/          design system, formatters, concurrency helpers
```

## How the scan stays fast

The similarity scan never compares every photo to every other one. On a
20,000-photo library that would be 200 million comparisons.

1. **Persistent cache** — hash and byte size are memoised per asset, validated
   against its modification date, so only new or edited photos are ever
   analysed. Repeat scans are near-instant.
2. **Difference hash** — each photo is reduced to a 64-bit fingerprint from a
   9×8 greyscale thumbnail, comparing each pixel with its right-hand neighbour.
   Comparing neighbours rather than absolute values is what makes it survive
   exposure, white balance and re-compression differences.
3. **Three cheap grouping passes**, each only looking at plausible candidates:
   exact hash classes (O(n), and it stops flat images producing huge clusters),
   a sliding time window for bursts, and LSH banding for look-alikes taken far
   apart. A union-find collapses the proposed matches into groups.
4. **Vision verification** on the weakest groups only — those held together
   purely by a loose hash match between photos taken at unrelated times, where a
   false positive is both likeliest and most costly.

Grouping 20,000 photos takes ~0.04s (see checks below). Fingerprinting is the
I/O-bound part and runs through a bounded concurrency window.

## Safety

Nothing is deleted without passing through all of this:

1. The user selects items.
2. The review screen lists exactly what will go, with sizes and a total, and
   lets anything be taken back out.
3. A confirmation alert that spells out what is recoverable and what is not.
4. iOS's own deletion sheet — a second, independent gate.
5. Photos land in Recently Deleted, recoverable for 30 days. The result screen
   says so, and explains that the space returns when that is emptied.

Other deliberate choices:

- `ExecuteCleanupUseCase` is the only code path that can delete anything, and
  only from an explicit `CleanupPlan`.
- Similar photos pre-select everything *except* the best shot, and a group can
  never end up fully selected — something always survives.
- Screenshots and videos pre-select nothing: there is no spare copy.
- Contacts pre-select nothing and default to **merge**, which is additive — the
  surviving card keeps every phone, email and address from the others. Contact
  changes are permanent, so they carry their own confirmation.
- If the user backs out at iOS's sheet, the selection is kept and no result is
  claimed.

## Permissions

Photos and Contacts are explained on a priming screen *before* iOS asks, since
iOS only gives one line and one chance. `denied`, `restricted` and `limited` are
all handled: limited access still scans what it can and offers to widen the
selection, and denied states always offer a route into Settings. Statuses are
re-read whenever the app becomes active, because access can be revoked while
backgrounded.

## Running the domain checks

The domain layer is framework-free by design, so it compiles and runs standalone:

```sh
./DomainTests/run.sh
```

22 checks covering grouping, best-shot selection, contact matching and
throughput on a 20,000-photo synthetic library.

## Development aids

Debug builds accept a launch argument to jump straight to a screen:

```sh
-afRoute similarPhotos | screenshots | largeVideos | duplicateContacts | review
-afPreselect     # also fills the basket, for reaching Review with content
```

Both compile out of release builds.

## Not built

Out of scope per the brief: payments, subscriptions and paywalls; email
cleaning; clearing other apps' caches or "junk files" (iOS does not allow it, so
the app does not claim it); login and cloud sync; iPad, Watch and Mac.

Bonus items not attempted in this pass: video compression, swipe-to-decide,
blurry photo detection, a private vault, calendar cleanup, a Home Screen widget.
