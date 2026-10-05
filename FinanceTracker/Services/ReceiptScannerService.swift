import Foundation
import UIKit
import Vision

/// Structured result returned from OCR parsing of a receipt image.
struct ParsedReceiptResult {
    var items: [ReceiptLineItem] = []
    var tax: Double = 0.0
    var serviceFee: Double = 0.0
    var rounding: Double = 0.0
    var totalAmount: Double = 0.0
}

/// Service that leverages the native iOS Vision framework (VNRecognizeTextRequest)
/// to parse line items, quantities, prices, taxes, service charges, and rounding adjustments from receipt images.
enum ReceiptScannerService {

    /// Scans a receipt UIImage asynchronously and returns extracted line items and charges.
    static func scanReceipt(image: UIImage) async throws -> ParsedReceiptResult {
        guard let cgImage = image.cgImage else {
            throw NSError(domain: "ReceiptScanner", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid image data."])
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: ParsedReceiptResult())
                    return
                }

                // Sort observations vertically from top to bottom (bounding box Y is 0 at bottom, 1 at top in Vision)
                let sorted = observations.sorted { obs1, obs2 in
                    obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
                }

                let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
                let parsed = parseReceiptLines(lines)
                continuation.resume(returning: parsed)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Parses an array of recognized text strings into receipt items, tax, service fee, and rounding adjustment.
    static func parseReceiptLines(_ lines: [String]) -> ParsedReceiptResult {
        var items: [ReceiptLineItem] = []
        var detectedTax: Double = 0.0
        var detectedServiceFee: Double = 0.0
        var detectedRounding: Double = 0.0
        var detectedTotal: Double = 0.0

        // Price regex matches amounts like 12.50, 8.00, 105.99, etc.
        let priceRegex = try? NSRegularExpression(pattern: #"(\d+[\.,]\d{2})(?!\d)"#)

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            let lower = line.lowercased()

            // Skip common metadata / non-item lines
            if lower.contains("welcome") || lower.contains("thank you") || lower.contains("tel:")
                || lower.contains("receipt") || lower.contains("invoice") || lower.contains("cashier")
                || lower.contains("table") || lower.contains("order #") || lower.contains("card")
                || lower.contains("change") || lower.contains("visa") || lower.contains("mastercard") {
                continue
            }

            // Extract price from end of line
            guard let matches = priceRegex?.matches(in: line, range: NSRange(line.startIndex..., in: line)),
                  let lastMatch = matches.last,
                  let priceRange = Range(lastMatch.range, in: line) else {
                continue
            }

            let priceStr = String(line[priceRange]).replacingOccurrences(of: ",", with: ".")
            guard let price = Double(priceStr), price > 0 else { continue }

            // Check if this is Rounding Adjustment (e.g. "Rounding -0.02", "Round Adj: 0.02-", "Pusingan -0.02")
            if lower.contains("rounding") || lower.contains("round adj") || lower.contains("pusingan") {
                let isNegative = line.contains("-") || lower.contains("cr")
                detectedRounding = isNegative ? -price : price
                continue
            }

            // Check if this is Tax, Service Charge, or Total
            if lower.contains("tax") || lower.contains("sst") || lower.contains("gst") || lower.contains("vat") {
                detectedTax = price
                continue
            }

            if lower.contains("service") || lower.contains("svc") || lower.contains("tip") || lower.contains("fee") {
                detectedServiceFee = price
                continue
            }

            if lower.contains("grand total") || lower.contains("total amount") || lower.starts(with: "total") {
                detectedTotal = max(detectedTotal, price)
                continue
            }

            if lower.contains("subtotal") || lower.contains("sub total") {
                continue
            }

            // Item Name & Quantity
            let rawName = String(line[..<priceRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawName.isEmpty else { continue }

            var itemName = rawName
            var quantity = 1

            // Check for leading quantity like "2x Burger" or "3 Burger"
            let qtyPattern = #"^(\d+)\s*[xX]?\s+(.*)$"#
            if let qtyRegex = try? NSRegularExpression(pattern: qtyPattern),
               let match = qtyRegex.firstMatch(in: itemName, range: NSRange(itemName.startIndex..., in: itemName)),
               match.numberOfRanges == 3,
               let qRange = Range(match.range(at: 1), in: itemName),
               let nameRange = Range(match.range(at: 2), in: itemName) {
                if let parsedQty = Int(itemName[qRange]), parsedQty > 0 {
                    quantity = parsedQty
                    itemName = String(itemName[nameRange]).trimmingCharacters(in: .whitespaces)
                }
            }

            // Clean up item name symbols
            itemName = itemName.replacingOccurrences(of: "RM", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "$", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard !itemName.isEmpty else { continue }

            let unitPrice = (price / Double(quantity) * 100).rounded() / 100.0

            items.append(ReceiptLineItem(
                name: itemName,
                unitPrice: unitPrice,
                quantity: quantity,
                assignedMemberIDs: []
            ))
        }

        let computedSubtotal = items.reduce(0.0) { $0 + $1.totalPrice }
        let preRoundingTotal = ((computedSubtotal + detectedTax + detectedServiceFee) * 100).rounded() / 100.0

        // If explicit rounding was not parsed, but grand total was recognized:
        if detectedRounding == 0.0 && detectedTotal > 0 {
            let diff = ((detectedTotal - preRoundingTotal) * 100).rounded() / 100.0
            if abs(diff) > 0.001 && abs(diff) <= 0.05 {
                detectedRounding = diff
            }
        } else if detectedRounding == 0.0 && detectedTotal == 0.0 {
            // Apply Malaysian 5-sen rounding if no total detected
            detectedRounding = MalaysianRounding.adjustment(for: preRoundingTotal)
        }

        let finalTotal = detectedTotal > 0 ? detectedTotal : ((preRoundingTotal + detectedRounding) * 100).rounded() / 100.0

        return ParsedReceiptResult(
            items: items,
            tax: detectedTax,
            serviceFee: detectedServiceFee,
            rounding: detectedRounding,
            totalAmount: finalTotal
        )
    }
}
