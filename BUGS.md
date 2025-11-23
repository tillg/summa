# BUGS

## Full screen pictures don't show

When opening a valueSnapshot with an existing picture and tapping on the picture it should display the picture in full screen. It just shows an empty white sheet.

**Fix**: Remove the feature of opening the picture, as the thumbnails are big enough to see what's on them.

## Default series added multiple times

When starting the App it takes some time before the Data from iCloud is read. In this time the App tests if there is a default series, and creates it if it doesn't exist. Then the real data comes in from iCloud - and we have 2 Default series...

**Potential Fixes**:

1. **Add CloudKit sync state detection** (Recommended)
   - Use `NSPersistentCloudKitContainer` notifications to detect when initial sync completes
   - Only create Default series after CloudKit import finishes
   - Implementation: Subscribe to `.NSPersistentCloudKitContainerEventChangedNotification` and check for `.import` event with `.finished` state
   - Add a `UserDefaults` flag to track if Default series was ever created

2. **Use unique constraint on series name**
   - Add `@Attribute(.unique)` to Series.name field
   - Prevents duplicate series names at database level
   - Caveat: May cause conflicts if user legitimately wants duplicate names (less likely for "Default")

3. **Delay Default series creation**
   - Add a 2-3 second delay before checking/creating Default series
   - Simplest approach but unreliable (slow networks may take longer)
   - Not recommended for production

4. **Query with network-aware check**
   - Before creating Default series, explicitly wait for CloudKit sync status
   - Use `NSPersistentCloudKitContainer.recordID(for:)` to check if local data is synced
   - More complex but most robust solution

**Recommended Approach**: Option 1 (CloudKit sync state detection) provides the best balance of reliability and user experience. It ensures we only create the Default series when we're certain CloudKit has finished importing existing data.
