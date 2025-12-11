# Get Timestamp from Picture

## Overview

Currently when creating a new ValueSnapshot based on a picture sent through the ShareSheet, we use the current date & time as time for the ValueSnapshot. We should rather use the date of the picture. The timestamp is encoded in the image metadata (EXIF data or file creation date).

## Requirements

**Date Extraction Priority:**
1. EXIF DateTimeOriginal
2. TIFF DateTime
3. File creation/modification date
4. `nil` if nothing found (no date available)

**Key Requirements:**
- Extract date before any image transformation/compression
- Make `date` field optional in ValueSnapshot model (`Date?`)
- `nil` clearly indicates "date unknown"
- Users can always manually override the date
- Shared utility needed for both main app and share extension

---

## Architecture

### Core Component

**ImageMetadataExtractor**
- Shared utility class in `Utils/`
- Dual target membership: Summa app + Share Extension
- Uses ImageIO framework to read EXIF/TIFF metadata
- Simple file sharing (no framework overhead needed)

### Key Decisions

**1. Timezone Handling**
- EXIF dates lack timezone information
- **Decision**: Use device timezone when parsing EXIF/TIFF dates

**2. Extraction Timing**
- Must extract metadata while original image artifact is available
- **Decision**: Extract date as first step in processing chain, before compression/transformation

**3. User Override**
- **Decision**: Users can always manually override the date, regardless of source (metadata vs inferred)

**4. Multiple Images**
- **Decision**: Not a requirement for this implementation

**5. Date Field Model**
- **Decision**: Make `date` field optional (`Date?`) in ValueSnapshot model
- `nil` indicates date is unknown
- CloudKit fully supports optional fields

**6. Missing Metadata Indication**
- When date is inferred (not from metadata), show visual indicator
- **Decision**: Display subtle info icon (ⓘ) next to date field with tooltip
- Tooltip text: "Date estimated (no metadata found in image)"

### Integration Points

**Share Extension:**
- Extract date as first step (before OCR/transformation)
- Pass extracted `Date?` to ValueSnapshot
- Store `nil` if no metadata found

**Main App (AddValueSnapshotView):**
- Pre-fill date picker with extracted date (or `Date.now` for display)
- Show info icon (ⓘ) with tooltip when date is `nil`
- Allow manual date override in all cases

**Model Changes:**
- Change `date: Date` → `date: Date?`
- CloudKit schema update (development environment reset required)

### Technical Considerations

**Performance:**
- Metadata extraction is fast (<100ms typically)
- Extract on background thread to avoid blocking UI

**Error Handling:**
- Gracefully handle corrupted image files
- Handle non-image files shared to extension
- Return `nil` if extraction fails

**Testing:**
- Test with images lacking EXIF data
- Test various image formats (JPEG, PNG, HEIC)
- Test file date fallback

**Privacy:**
- Only read date fields from EXIF (not location or other metadata)

### Implementation Phases

**Phase 1: Core Utility**
- Create `ImageMetadataExtractor.swift` in Utils/ with dual target membership
- Implement EXIF, TIFF, file date extraction with device timezone
- Add unit tests

**Phase 2: Model & Schema Update**
- Make `date` field optional (`Date?`) in ValueSnapshot model
- Reset CloudKit development environment
- Handle existing data migration

**Phase 3: Share Extension Integration**
- Extract date as first step when receiving image (before OCR)
- Pass extracted date to ValueSnapshot creation

**Phase 4: UI Enhancement**
- Pre-fill date picker with extracted date in AddValueSnapshotView
- Show info icon (ⓘ) with tooltip when date is nil
- Ensure date can always be manually overridden

