import Foundation
import Vision
import CoreImage
import CoreGraphics

public struct DocumentCropper {
    
    /// Detects and crops a document from an image using Vision ML
    /// - Parameter image: The input image containing a document
    /// - Returns:  Cropped and perspective-corrected image, or nil if detection fails
    public static func detectAndCropDocument(_ image: CIImage) -> CIImage? {
        let context = CIContext(options: [. useSoftwareRenderer: false])
        
        // Convert to CGImage for Vision processing
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }
        
        // Try document segmentation first (most accurate for full/partial pages)
        if let segmentedImage = detectUsingSegmentation(image: image, cgImage: cgImage) {
            return segmentedImage
        }
        
        // Fallback to rectangle detection with perspective correction
        if let rectangleCroppedImage = detectUsingRectangles(image: image, cgImage: cgImage) {
            return rectangleCroppedImage
        }
        
        // No document detected
        return nil
    }
    
    // MARK: - Detection Methods
    
    /// Uses VNDetectDocumentSegmentationRequest to find document boundaries
    private static func detectUsingSegmentation(image:  CIImage, cgImage: CGImage) -> CIImage? {
        let request = VNDetectDocumentSegmentationRequest()
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [: ])
        
        do {
            try handler.perform([request])
        } catch {
            print("Document segmentation failed: \(error)")
            return nil
        }
        
        guard let results = request.results, !results.isEmpty else {
            return nil
        }
        
        guard let observation = results.first else {
            return nil
        }
        
        // Extract the mask and find document bounds
        guard let croppedImage = cropToSegmentationMask(image: image, observation: observation) else {
            return nil
        }
        
        return croppedImage
    }
    
    /// Uses VNDetectRectanglesRequest to find rectangular document boundaries
    private static func detectUsingRectangles(image:  CIImage, cgImage: CGImage) -> CIImage? {
        let request = VNDetectRectanglesRequest()
        
        // Configure for document detection
        request.minimumAspectRatio = 0.3  // Allow narrow documents
        request.maximumAspectRatio = 2.0  // Allow wide documents
        request.minimumSize = 0.15        // At least 15% of image
        request.maximumObservations = 1   // Only get the best match
        request.minimumConfidence = 0.6   // Lower threshold for partial pages
        request.quadratureTolerance = 45.0 // Allow more skew
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            print("Rectangle detection failed: \(error)")
            return nil
        }
        
        guard let results = request.results, !results.isEmpty else {
            return nil
        }
        
        guard let observation = results.first else {
            return nil
        }
        
        // Apply perspective correction
        return applyPerspectiveCorrection(to:  image, with: observation)
    }
    
    // MARK: - Image Processing
    
    /// Crops image to the document region found in segmentation mask
    private static func cropToSegmentationMask(image: CIImage, observation: VNRectangleObservation) -> CIImage? {
        // VNDetectDocumentSegmentationRequest returns VNRectangleObservation
        // We can use the bounding box directly
        let imageSize = image.extent.size
        
        // Convert normalized bounding box to image coordinates
        // Vision uses bottom-left origin, Core Image uses top-left
        let boundingBox = observation.boundingBox
        
        let x = boundingBox.origin.x * imageSize.width
        let y = (1.0 - boundingBox.origin.y - boundingBox.height) * imageSize.height
        let width = boundingBox.width * imageSize.width
        let height = boundingBox.height * imageSize.height
        
        let cropRect = CGRect(x: x, y: y, width: width, height: height)
        
        // Ensure crop rect is within image bounds
        let validCropRect = cropRect.intersection(image.extent)
        
        guard !validCropRect.isEmpty else {
            return nil
        }
        
        // Apply perspective correction for better results
        return applyPerspectiveCorrection(to: image, with: observation)
    }
    
    /// Applies perspective correction to straighten a document
    private static func applyPerspectiveCorrection(to image: CIImage, with observation: VNRectangleObservation) -> CIImage? {
        let imageSize = image.extent.size
        
        // Convert normalized coordinates to image coordinates
        // Vision uses bottom-left origin, Core Image uses top-left
        func convertPoint(_ point: CGPoint) -> CGPoint {
            return CGPoint(
                x: point.x * imageSize.width,
                y: (1.0 - point.y) * imageSize.height
            )
        }
        
        let topLeft = convertPoint(observation.topLeft)
        let topRight = convertPoint(observation.topRight)
        let bottomLeft = convertPoint(observation.bottomLeft)
        let bottomRight = convertPoint(observation.bottomRight)
        
        // Apply perspective correction filter
        let correctedImage = image.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight":  CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight)
        ])
        
        return correctedImage
    }
}
