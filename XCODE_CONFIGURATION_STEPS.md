# Xcode Configuration Steps for macOS Share Extension

The files have been created, but Xcode targets need to be configured manually. Follow these steps:

## Step 1: Rename iOS Extension Target

1. In Xcode Project Navigator, select the project (blue icon at top)
2. In the target list, find "Summa Share Extension"
3. Click once to select it, then click again to edit the name
4. Rename to: `Summa Share Extension (iOS)`
5. Update the Build Settings → Code Signing Entitlements:
   - Change from `Summa Share ExtensionDebug.entitlements`
   - To: `Summa Share Extension iOS/Summa Share Extension iOSDebug.entitlements`

## Step 2: Create macOS Extension Target

1. In Xcode, select File → New → Target
2. Select "macOS" tab at the top
3. Choose "Share Extension" template
4. Click "Next"
5. Configure the target:
   - **Product Name**: `Summa Share Extension (macOS)`
   - **Organization Identifier**: `com.grtnr`
   - **Bundle Identifier**: Should auto-populate as `com.grtnr.Summa.ShareExtension-macOS`
   - **Language**: Swift
   - **Project**: Summa
   - **Embed in Application**: Summa
6. Click "Finish"
7. When asked "Activate scheme?", click "Cancel" (we'll configure it later)

## Step 3: Replace Generated Files with Our Files

Xcode will generate template files. We need to replace them with our custom files:

1. In Project Navigator, expand "Summa Share Extension (macOS)" folder
2. **Delete** these generated files (Move to Trash):
   - `ShareViewController.swift` (the generated one)
   - `Info.plist` (if generated)
   - Any other generated files except the folder structure

3. **Add our custom files**:
   - Right-click on "Summa Share Extension (macOS)" folder
   - Select "Add Files to Summa..."
   - Navigate to `Summa/Summa Share Extension macOS/`
   - Select:
     - `ShareViewController.swift`
     - `Info.plist`
     - `Summa Share Extension macOSDebug.entitlements`
   - Make sure "Copy items if needed" is UNCHECKED
   - Make sure "Add to targets" shows only "Summa Share Extension (macOS)" checked
   - Click "Add"

## Step 4: Configure macOS Target Build Settings

1. Select the project in Project Navigator
2. Select "Summa Share Extension (macOS)" target
3. Go to "Build Settings" tab
4. Search for "Entitlements"
5. Set "Code Signing Entitlements" to:
   ```
   Summa Share Extension macOS/Summa Share Extension macOSDebug.entitlements
   ```
6. Search for "Info.plist"
7. Verify "Info.plist File" is set to:
   ```
   Summa Share Extension macOS/Info.plist
   ```
8. Search for "Supported Platforms"
9. Verify it shows only "macOS"

## Step 5: Add Shared Files to macOS Target

We need to add the shared model and utility files to the macOS extension target:

1. In Project Navigator, navigate to `Summa/Summa/Models/`
2. Select `ValueSnapshot.swift`
3. In File Inspector (right panel), under "Target Membership":
   - ✅ Summa (already checked)
   - ✅ Summa Share Extension (iOS) (already checked)
   - ✅ **Summa Share Extension (macOS)** ← CHECK THIS BOX
4. Select `Series.swift`
5. Repeat step 3 (check macOS extension target)

6. Navigate to `Summa/Summa/Utils/`
7. For EACH of these files, add macOS extension target membership:
   - `ModelContainerFactory.swift`
   - `AppConstants.swift`
   - `Logger.swift`
   - `SeriesManager.swift`

**Quick method**: Hold Cmd and select all 6 files (2 models + 4 utils), then in File Inspector, check the "Summa Share Extension (macOS)" box once for all.

## Step 6: Configure Platform Filters

1. Select the project in Project Navigator
2. Select "Summa" target (the main app)
3. Go to "Build Phases" tab
4. Expand "Embed Foundation Extensions"
5. You should see both:
   - `Summa Share Extension (iOS).appex`
   - `Summa Share Extension (macOS).appex`
6. For iOS extension, verify it shows `Platforms: iOS`
7. For macOS extension, verify it shows `Platforms: macOS`

If platform filters aren't showing correctly:
- Select the extension in the list
- Right-click → "Platform Filter" → Select appropriate platform

## Step 7: Configure Signing

1. Select "Summa Share Extension (macOS)" target
2. Go to "Signing & Capabilities" tab
3. Configure:
   - **Team**: Select your team
   - **Bundle Identifier**: `com.grtnr.Summa.ShareExtension-macOS`
4. Verify capabilities are present (should auto-detect from entitlements):
   - ✅ App Groups: `group.com.grtnr.Summa`
   - ✅ iCloud: CloudKit, `iCloud.com.grtnr.Summa`
   - ✅ App Sandbox (macOS only)

If capabilities aren't showing:
- Click "+ Capability"
- Add "App Groups" and configure
- Add "iCloud" and enable CloudKit
- Add "App Sandbox" (macOS only)

## Step 8: Verify Build Settings Match

Compare iOS and macOS extension settings to ensure consistency:

**Both should have:**
- Deployment Target: iOS 18.4 (iOS), macOS 15.4 (macOS)
- Swift Language Version: 6.0
- App Groups: `group.com.grtnr.Summa`
- CloudKit: `iCloud.com.grtnr.Summa`

**macOS specific:**
- App Sandbox: Yes
- Network Client: Yes

## Step 9: Clean and Build

1. Product → Clean Build Folder (Cmd+Shift+K)
2. Product → Build (Cmd+B)
3. Fix any errors that appear (usually missing target memberships)

## Verification

After configuration, verify:

```bash
# Check folder structure
ls -la "Summa/Summa Share Extension iOS/"
ls -la "Summa/Summa Share Extension macOS/"

# Check that both extensions will be built
xcodebuild -project Summa/Summa.xcodeproj -list
```

You should see:
- Scheme: "Summa"
- Scheme: "Summa Share Extension" (iOS)
- Scheme: "Summa Share Extension (macOS)" (if auto-created)

## Troubleshooting

**"Cannot find ModelContainerFactory"**
- Add `Utils/ModelContainerFactory.swift` to macOS target membership

**"Cannot find ValueSnapshot"**
- Add `Models/ValueSnapshot.swift` to macOS target membership

**"Cannot find 'log' in scope"**
- Add `Utils/Logger.swift` to macOS target membership

**"Cannot find AppConstants"**
- Add `Utils/AppConstants.swift` to macOS target membership

**Build succeeds but extension doesn't appear in Share menu**
- Check Info.plist has correct NSExtensionPointIdentifier
- Check entitlements are configured correctly
- Restart the Mac after installing

## Next Steps

After Xcode configuration is complete, test:
1. Build for iOS (Cmd+B with iOS destination)
2. Build for macOS (Cmd+B with macOS destination)
3. Run on iOS simulator → Share image → Verify "Summa" appears
4. Run on macOS → Right-click image → Share → Verify "Summa" appears
