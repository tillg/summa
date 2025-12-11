# Test Images for ImageMetadataExtractor Tests

This directory contains sample images for testing the ImageMetadataExtractor functionality.

## Required Test Images

Please add the following images to enable all tests:

### 1. **photo_with_exif.jpg**
- **Description**: Photo with EXIF DateTimeOriginal metadata
- **Requirements**:
  - Must have EXIF DateTimeOriginal field populated
  - Should be taken with a camera or phone (not a screenshot)
  - Known date/time in EXIF for verification

### 2. **photo_with_tiff.jpg**
- **Description**: Photo with TIFF DateTime but no EXIF DateTimeOriginal
- **Requirements**:
  - Must have TIFF DateTime field
  - Should NOT have EXIF DateTimeOriginal (or it should be removed)

### 3. **photo_no_metadata.jpg**
- **Description**: Photo with no EXIF or TIFF metadata
- **Requirements**:
  - All EXIF/TIFF metadata stripped
  - File creation date will be used as fallback

### 4. **photo.png**
- **Description**: PNG image with metadata
- **Requirements**:
  - PNG format with date metadata

### 5. **photo.heic**
- **Description**: HEIC image (iPhone format)
- **Requirements**:
  - HEIC format with EXIF metadata
  - Common iPhone photo format

### 6. **photo_known_date.jpg**
- **Description**: Photo with known EXIF date for timezone testing
- **Requirements**:
  - EXIF DateTimeOriginal: "2024:01:15 14:30:00" (or document actual date)
  - Used to verify device timezone parsing

### 7. **photo_exif_and_tiff.jpg**
- **Description**: Photo with both EXIF and TIFF dates (different values)
- **Requirements**:
  - EXIF DateTimeOriginal: e.g., "2024:01:15 10:00:00"
  - TIFF DateTime: e.g., "2024:01:14 12:00:00" (different date)
  - Used to verify EXIF takes priority

### 8. **photo_tiff_only.jpg**
- **Description**: Photo with TIFF DateTime but no EXIF
- **Requirements**:
  - TIFF DateTime should be different from file creation date
  - No EXIF DateTimeOriginal

## How to Add Images

1. Take photos with your iPhone/camera for real EXIF data
2. Use tools like `exiftool` to inspect/modify metadata:
   ```bash
   # View metadata
   exiftool photo.jpg

   # Remove EXIF data
   exiftool -all= photo.jpg

   # Set specific EXIF date
   exiftool -DateTimeOriginal="2024:01:15 14:30:00" photo.jpg
   ```
3. Add images to this directory
4. Run tests in Xcode

## Notes

- Tests will be skipped (not failed) if images are missing
- You can start with just a few images and add more incrementally
- Screenshots typically have current date metadata
- Photos from camera roll have authentic EXIF data
