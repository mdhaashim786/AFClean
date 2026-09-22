#!/bin/bash
#
# Compiles the framework-free domain layer on its own and runs its checks.
#
set -euo pipefail

cd "$(dirname "$0")/.."
SRC="AppFactory_StorageCleaner/Domain"
OUT="$(mktemp -d)/domainchecks"

swiftc -O -o "$OUT" \
    "$SRC/Entities/MediaAsset.swift" \
    "$SRC/Entities/PhotoGroup.swift" \
    "$SRC/Entities/ContactRecord.swift" \
    "$SRC/Entities/ContactDuplicateGroup.swift" \
    "$SRC/Services/UnionFind.swift" \
    "$SRC/Services/PerceptualHash.swift" \
    "$SRC/Services/BestShotSelector.swift" \
    "$SRC/Services/SimilarityGrouper.swift" \
    "$SRC/Services/ContactMatcher.swift" \
    DomainTests/main.swift

"$OUT"
