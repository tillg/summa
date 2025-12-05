# Get Timestamp from Picture

Currently when creating a new ValueSnapshot based on an picture sent thru the ShareSheet, we use the current date & time as time for the ValueSnapshot. We should rather use the date of the picture. Probably that is in the picture file somehow encoded.

---

## Implementation Details & Considerations

Here is an analysis of how to implement this feature, including open questions and architectural choices.

### Proposed Implementation Steps

1.  **Accessing Image Data**: When an image is shared to the `Summa Share Extension`, the `ShareViewController` receives it as an `NSItemProvider`. This provider can be asked to load the image data.

2.  **Extracting Metadata**: The `ImageIO` framework is the best tool for this. We can create a `CGImageSource` from the image data and then use `CGImageSourceCopyPropertiesAtIndex` to get the metadata dictionary.

3.  **Finding the Timestamp**: The timestamp is typically stored in the EXIF metadata dictionary. The key for the original date and time is `kCGImagePropertyExifDateTimeOriginal`. The value is usually a `String`.

4.  **Parsing the Timestamp**: The date string from the EXIF data needs to be parsed into a `Date` object. A `DateFormatter` will be required. The common EXIF date format is `yyyy:MM:dd HH:mm:ss`.

5.  **Fallback Strategy**: If the image does not contain EXIF metadata, or if the timestamp is missing, the implementation should gracefully fall back to using the current date and time (`Date()`). This ensures that the feature works for all images, not just those with complete metadata.

6.  **Integration**: The logic should be integrated into `ShareViewController.swift`. This is the entry point for shared items. The extracted date will be used when creating the `ValueSnapshot` object.

### Code Example (Conceptual)

```swift
import ImageIO

func getTimestamp(from imageData: Data) -> Date? {
    guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
          let exifDict = properties[kCGImagePropertyExifDictionary as String] as? [String: Any],
          let dateTimeOriginal = exifDict[kCGImagePropertyExifDateTimeOriginal as String] as? String else {
        return nil
    }

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
    return dateFormatter.date(from: dateTimeOriginal)
}

// In ShareViewController
// ...
if let imageData = ... {
    let timestamp = getTimestamp(from: imageData) ?? Date()
    // use timestamp to create ValueSnapshot
}

```

### Open Questions

*   **Timestamp Format Variations**: Are we sure about the `yyyy:MM:dd HH:mm:ss` format? While common, other formats might exist. We need to test with images from various sources (different cameras, phones, apps).
*   **Timezone Handling**: EXIF timestamps often do not include timezone information. When we parse the date string, what timezone should we assume? The user's current timezone? UTC? This needs a clear decision to avoid incorrect data. Assuming the user's current timezone seems like a reasonable default.
*   **Multiple Images**: How should the Share Extension behave if multiple images are shared at once? Should it create multiple `ValueSnapshot`s, each with its own timestamp? The current implementation path needs to be checked for this.
*   **User Override**: Should the user have the ability to confirm or edit the extracted timestamp before saving the `ValueSnapshot`? This would add complexity to the UI, but also give more control to the user.
*   **Video Files**: What about video files? They also have creation dates in their metadata. Is this feature scoped to images only? The current spec says "picture".

### Architecture Choices

1.  **Inline in `ShareViewController`**:
    *   **Description**: Place the metadata extraction logic directly within `ShareViewController.swift`.
    *   **Pros**: Simple, fast to implement.
    *   **Cons**: Tightly couples the view controller with metadata extraction logic, making it harder to test and reuse. Less clean architecture.

2.  **Dedicated `ImageMetadataService`**:
    *   **Description**: Create a new service, `ImageMetadataService`, responsible for extracting metadata from image data. `ShareViewController` would then use this service.
    *   **Pros**:
        *   **Separation of Concerns**: Follows the existing architecture of using services for business logic.
        *   **Testability**: The service can be easily unit tested in isolation.
        *   **Reusability**: The service could be reused in other parts of the app if needed (e.g., if we allow picking from the photo library directly in the main app).
    *   **Cons**: Slightly more upfront work to create the new service file and define its interface.

**Recommendation**: The `ImageMetadataService` approach is strongly recommended. It aligns better with the project's apparent architecture and best practices for building scalable and maintainable apps.
