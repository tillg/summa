//
//  IAImageOverlayView.swift
//  Foundation Lab
//
//  Overlay view for displaying bounding boxes on analyzed images
//

import SwiftUI

/// SwiftUI view that displays an image with analysis overlays (bounding boxes, priority badges)
public struct IAImageOverlayView: View {
    let analyzedImage: AnalyzedImage

    public init(analyzedImage: AnalyzedImage) {
        self.analyzedImage = analyzedImage
    }

    public var body: some View {
        #if canImport(UIKit)
        Image(uiImage: analyzedImage.originalImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay(alignment: .topLeading) {
                Canvas { context, size in
                    drawOverlays(context: context, size: size)
                }
                .allowsHitTesting(false)
            }
        #elseif canImport(AppKit)
        Image(nsImage: analyzedImage.originalImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .overlay(alignment: .topLeading) {
                Canvas { context, size in
                    drawOverlays(context: context, size: size)
                }
                .allowsHitTesting(false)
            }
        #endif
    }

    private func drawOverlays(context: GraphicsContext, size: CGSize) {
        // Draw text bounding boxes with priority markers
        for textResult in analyzedImage.textResults {
            drawBoundingBox(
                context: context,
                normalizedBox: textResult.boundingBox,
                color: .blue,
                canvasSize: size
            )

            // Draw priority badge
            drawPriorityBadge(
                context: context,
                normalizedBox: textResult.boundingBox,
                priority: textResult.priority,
                canvasSize: size
            )
        }

        // Draw face bounding boxes and landmarks
        for faceResult in analyzedImage.faceResults {
            drawBoundingBox(
                context: context,
                normalizedBox: faceResult.boundingBox,
                color: .green,
                canvasSize: size
            )

            // Draw facial landmarks if present
            if let landmarks = faceResult.landmarks {
                drawLandmarks(
                    context: context,
                    landmarks: landmarks,
                    faceBoundingBox: faceResult.boundingBox,
                    canvasSize: size
                )
            }
        }
    }

    private func drawBoundingBox(
        context: GraphicsContext,
        normalizedBox: CGRect,
        color: Color,
        canvasSize: CGSize
    ) {
        // Vision returns normalized CGRect with:
        // - origin: bottom-left corner
        // - range: 0.0 to 1.0
        // - coordinate system: (0,0) is bottom-left, (1,1) is top-right

        // Canvas uses:
        // - origin: top-left corner
        // - coordinate system: (0,0) is top-left

        // Convert: multiply by canvas size and flip Y axis
        let x = normalizedBox.origin.x * canvasSize.width
        let width = normalizedBox.width * canvasSize.width
        let height = normalizedBox.height * canvasSize.height

        // Flip Y: Vision's bottom-left to SwiftUI's top-left
        let y = canvasSize.height - (normalizedBox.origin.y + normalizedBox.height) * canvasSize.height

        let rect = CGRect(x: x, y: y, width: width, height: height)

        var path = Path()
        path.addRect(rect)

        context.stroke(
            path,
            with: .color(color),
            lineWidth: 3
        )
    }

    private func drawLandmarks(
        context: GraphicsContext,
        landmarks: FacialLandmarks,
        faceBoundingBox: CGRect,
        canvasSize: CGSize
    ) {
        // Draw yellow crosses at each landmark position
        if let leftEye = landmarks.leftEye {
            drawLandmarkCross(
                context: context,
                landmarkPoint: leftEye,
                faceBoundingBox: faceBoundingBox,
                canvasSize: canvasSize
            )
        }

        if let rightEye = landmarks.rightEye {
            drawLandmarkCross(
                context: context,
                landmarkPoint: rightEye,
                faceBoundingBox: faceBoundingBox,
                canvasSize: canvasSize
            )
        }

        if let nose = landmarks.nose {
            drawLandmarkCross(
                context: context,
                landmarkPoint: nose,
                faceBoundingBox: faceBoundingBox,
                canvasSize: canvasSize
            )
        }

        if let mouth = landmarks.mouth {
            drawLandmarkCross(
                context: context,
                landmarkPoint: mouth,
                faceBoundingBox: faceBoundingBox,
                canvasSize: canvasSize
            )
        }
    }

    private func drawLandmarkCross(
        context: GraphicsContext,
        landmarkPoint: CGPoint,
        faceBoundingBox: CGRect,
        canvasSize: CGSize
    ) {
        // Landmark point is relative to the face bounding box (0-1 coordinates within the box)
        // Convert to image coordinates (0-1 normalized to entire image)
        let imageX = faceBoundingBox.origin.x + landmarkPoint.x * faceBoundingBox.width
        let imageY = faceBoundingBox.origin.y + landmarkPoint.y * faceBoundingBox.height

        // Now convert from image coordinates (normalized, bottom-left) to canvas (pixels, top-left)
        let canvasX = imageX * canvasSize.width
        let canvasY = canvasSize.height - imageY * canvasSize.height

        let point = CGPoint(x: canvasX, y: canvasY)

        // Draw yellow X cross
        let crossSize: CGFloat = 10
        let lineWidth: CGFloat = 2

        var path = Path()

        // Diagonal line from top-left to bottom-right
        path.move(to: CGPoint(x: point.x - crossSize/2, y: point.y - crossSize/2))
        path.addLine(to: CGPoint(x: point.x + crossSize/2, y: point.y + crossSize/2))

        // Diagonal line from top-right to bottom-left
        path.move(to: CGPoint(x: point.x + crossSize/2, y: point.y - crossSize/2))
        path.addLine(to: CGPoint(x: point.x - crossSize/2, y: point.y + crossSize/2))

        context.stroke(
            path,
            with: .color(.yellow),
            lineWidth: lineWidth
        )
    }

    private func drawPriorityBadge(
        context: GraphicsContext,
        normalizedBox: CGRect,
        priority: Int,
        canvasSize: CGSize
    ) {
        // Convert normalized coordinates to canvas coordinates
        let x = normalizedBox.origin.x * canvasSize.width
        let width = normalizedBox.width * canvasSize.width
        let y = canvasSize.height - (normalizedBox.origin.y + normalizedBox.height) * canvasSize.height

        // Badge color based on priority
        let badgeColor: Color = {
            switch priority {
            case 1: return .red      // Highest priority
            case 2: return .orange   // Medium priority
            case 3: return .blue     // Lower priority
            default: return .gray
            }
        }()

        // Fixed badge size for legibility
        let badgeWidth: CGFloat = 32
        let badgeHeight: CGFloat = 24

        // Position badge at top-right corner of bounding box
        let badgeX = x + width - badgeWidth / 2
        let badgeY = y + 4

        // Draw badge background (rounded rectangle)
        let badgeRect = CGRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)
        let badgePath = Path(roundedRect: badgeRect, cornerRadius: 4)
        context.fill(badgePath, with: .color(badgeColor))

        // Draw text
        let text = Text("P\(priority)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.white)

        context.draw(text, at: CGPoint(x: badgeX + badgeWidth / 2, y: badgeY + badgeHeight / 2))
    }
}
