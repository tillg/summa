AI Generated SWIFT code often has these problems. Make sure to avoid or fix them!

Every time you see foregroundColor(), switch it out for foregroundStyle(). It’s the same number of characters to type, but the former is deprecated, whereas the latter supports more advanced features like gradients.
Replace cornerRadius() with clipShape(.rect(cornerRadius:)). Again, the former is deprecated, whereas the latter offers more advanced features such as uneven rounded rectangles.
The onChange() modifier should not be used in its 1-parameter variant. Either accept two parameters or none, but the old variant is unsafe and deprecated.
If you see the old tabItem() modifier, replace it with the new Tab API instead. This lets you benefit from the new type-safe tab selection, and also adopt things like the iOS 26 search tab design.
Replace almost all use of onTapGesture() with an actual button – the only exceptions are where you need to know a tap’s location or the number of taps. This is significantly better for VoiceOver, but also means things like eye tracking on visionOS works better.
Replace ObservableObject with the @Observable macro, unless you specifically rely on the Combine publisher for some reason. This lets your code be simpler and faster too.
Be careful if you see @Attribute(.unique) in SwiftData model definitions – this does not work with CloudKit.
If it break ups views by placing things into computed properties, tell it to split them out into separate SwiftUI views instead. This is important for performance when using @Observable – computed properties do not benefit from the intelligent view invalidation of @Observable.
Some LLMs (particularly Claude) love to force specific font sizes – search for .font(.system(size: and replace as many of them as you can using Dynamic Type fonts. (If you can support iOS 26 or later, you can also use .font(.body.scaled(by: 1.5)) and similar.)
Watch out for using the old, inline destination NavigationLink API in lists, and replace it with navigationDestination(for:) or similar.
Expect to see button labels being made with Label rather than the newer, inline API (Button("Tap me", systemImage: "plus", action: whatever)), or, worse, with just an image – it’s a real problem for VoiceOver users.
Replace code like ForEach(Array(x.enumerated()), id: \.element.id) with ForEach(x.enumerated(), id: \.element.id) – we don’t need the Array initializer.
You can safely replace the longer code to find the documents directory with just URL.documentsDirectory.
Every time you see NavigationView replace it with NavigationStack. The only reason to stay with the former is if you still need to support iOS 15.
Expect to see Task.sleep(nanoseconds:) back from the dead. You’re looking for Task.sleep(for:) with values such as .seconds(1).
I know the resulting code is longer, but try to replace C-style number formatting with the safer versions. For example, Text(String(format: "%.2f", abs(myNumber))) can be Text(abs(change), format: .number.precision(.fractionLength(2))).
Watch out for it placing lots of types in a single file – it’s a fantastic way to guarantee longer build times.
If you’re rendering SwiftUI views, you should replace UIGraphicsImageRenderer with ImageRenderer.
All three popular LLMs seem to enjoy over-using the fontWeight() modifier. See above about Dynamic Type, but also remember that fontWeight(.bold) and bold() do not always produce the same result.
If the LLM hits a concurrency problem, you can expect to see DispatchQueue.main.async used an unreasonable number of times. (We only have ourselves to blame for this, but still – ditch it!)
If you’re working with a new app project, main actor isolation is on by default so you don’t need to mark things with @MainActor.
And there there’s GeometryReader – boy oh boy do LLMs love GeometryReader, often combined with the other cardinal sin of adding fixed frame sizes where they don’t belong. Please consider some of the alternatives instead, including visualEffect() and containerRelativeFrame().