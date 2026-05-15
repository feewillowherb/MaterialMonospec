# License Plate Number Management Specification

## Purpose

Provides license plate recognition caching, selection, and management services for the attended weighing system. This service handles plate number recommendations, priority-based selection, cache management, and integration with LPR (License Plate Recognition) services.

## Requirements

### Requirement: Cache recognized plate numbers

PlateNumberService SHALL maintain a ConcurrentDictionary<string, PlateNumberCacheRecord> storing recognized plate numbers with count, last update time, color type, and locked-at timestamp.

#### Scenario: First recognition of a plate
- **WHEN** a plate number "京A12345" is recognized for the first time with VzvisionColorType.Blue
- **THEN** SHALL create a cache entry with Count=1, LastUpdateTime=now, ColorType=Blue, LockedAt=null (if EnablePlateRewrite=true) or LockedAt=now (if EnablePlateRewrite=false)

#### Scenario: Subsequent recognition increments count
- **WHEN** plate "京A12345" is recognized again
- **THEN** SHALL increment Count by 1, update LastUpdateTime to now, and preserve or update ColorType

### Requirement: Recommend plate number via RecommendPlateNumberService

PlateNumberService SHALL pass recognized plate numbers through RecommendPlateNumberService.GetRecommendPlateNumber() before caching, and cache the recommended result.

#### Scenario: Recommendation differs from raw input
- **WHEN** raw plate "京A12345挂" is recognized and recommendation returns "京A12345"
- **THEN** SHALL cache "京A12345" (the recommended value)

### Requirement: Filter hanging character from plate numbers

PlateNumberService SHALL apply PlateNumberValidator.FilterHangingCharacter() to remove "挂" characters before processing.

#### Scenario: Plate with hanging character
- **WHEN** plate "京A12345挂" is recognized
- **THEN** SHALL filter to "京A12345" before recommendation and caching

### Requirement: Select most frequent plate with priority logic

PlateNumberService SHALL select the best plate number using this priority order:
1. Locked candidates (LockedAt != null, sorted by earliest LockedAt) — when EnablePlateRewrite is false
2. High-priority plates (not low-priority color, within 20-minute window), sorted by LastUpdateTime (if EnableLatestPlateNumber) or Count (otherwise)
3. Low-priority plates as fallback, same sort order

#### Scenario: Locked candidate selected first
- **WHEN** EnablePlateRewrite is false and "京A12345" has LockedAt set
- **THEN** SHALL return "京A12345" regardless of other plate counts

#### Scenario: High-priority plate preferred over low-priority
- **WHEN** yellow plates have 10 recognitions and a blue plate has 1 recognition, yellow is configured as low-priority
- **THEN** SHALL return the blue plate

#### Scenario: Latest plate preferred when EnableLatestPlateNumber is true
- **WHEN** "京A12345" has Count=2 and "粤B67890" has Count=1 but more recent LastUpdateTime, and EnableLatestPlateNumber=true
- **THEN** SHALL return "粤B67890"

#### Scenario: Null color treated as high-priority
- **WHEN** a plate has null ColorType and low-priority plates exist with higher counts
- **THEN** SHALL select the plate with null ColorType over low-priority plates

### Requirement: Clear plate cache

PlateNumberService SHALL provide ClearCache() that removes all entries and publishes PlateNumberChangedEventData(null) via ILocalEventBus.

#### Scenario: Cache cleared
- **WHEN** ClearCache() is called
- **THEN** all entries SHALL be removed and PlateNumberChangedEventData with PlateNumber=null SHALL be published

### Requirement: Remove specific plate from cache

PlateNumberService SHALL provide RemovePlate(string plateNumber) that removes entries matching the plate number (case-insensitive).

#### Scenario: Ghost gate session reset removes abandoned plate
- **WHEN** RemovePlate("京A12345") is called and cache contains "京A12345"
- **THEN** "京A12345" SHALL be removed from cache and PlateNumberChangedEventData SHALL be published with updated most frequent plate

### Requirement: Thread-safe concurrent access

PlateNumberService SHALL handle concurrent plate recognition events without throwing exceptions.

#### Scenario: Concurrent plate recognitions
- **WHEN** three different plates are recognized simultaneously from different threads
- **THEN** SHALL select a valid plate without throwing, and all three plates SHALL be cached
