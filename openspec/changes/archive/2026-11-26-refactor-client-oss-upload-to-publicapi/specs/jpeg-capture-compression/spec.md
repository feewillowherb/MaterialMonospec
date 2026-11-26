# jpeg-capture-compression

## ADDED Requirements

### Requirement: Target-size in-memory JPEG compression for upload

`JpegCompressionUtil` SHALL provide a static in-memory method `CompressToTargetSize(byte[] sourceBytes, int targetMaxBytes = 200 * 1024, ILogger? logger = null)` returning a named `record` (`CompressedImagePayload`) that adaptively compresses JPEG bytes to fit near or under `targetMaxBytes` (default 200KB) via stepped quality reduction and optional proportional downscaling, without modifying any file on disk.

#### Scenario: Source image already within target size
- **WHEN** `CompressToTargetSize` is called with `sourceBytes.Length <= targetMaxBytes` (e.g., 150KB with 200KB target)
- **THEN** the method SHALL return the original bytes immediately with `WasCompressed = false` and without re-encoding

#### Scenario: Large image compressed to target size in memory
- **WHEN** `CompressToTargetSize` is called with a 1.5MB valid JPEG byte array and `targetMaxBytes = 200 * 1024`
- **THEN** the method SHALL re-encode using JPEG `ImageCodecInfo` encoders with stepped quality reduction (and proportional downscaling if quality alone is insufficient) until the output size is at or below `targetMaxBytes` (or the minimum compression tier is reached)
- **AND** SHALL return `WasCompressed = true` with `CompressedLength <= OriginalLength`

#### Scenario: Invalid or unreadable image bytes fall back safely
- **WHEN** `CompressToTargetSize` receives corrupted or non-image bytes
- **THEN** the method SHALL catch the exception, log a warning if a logger is provided, and return the original bytes with `WasCompressed = false` without throwing
