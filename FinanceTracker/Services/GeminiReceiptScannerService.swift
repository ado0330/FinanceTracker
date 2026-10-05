import Foundation
import UIKit

/// Service that sends receipt images to Google Gemini Multimodal API (e.g. gemini-3.5-flash-lite)
/// to extract structured line items, quantities, prices, taxes, and service charges.
enum GeminiReceiptScannerService {

    /// Standard system prompt instructing Gemini to return structured JSON
    private static let systemPrompt = """
    You are an expert receipt and invoice parser. Analyze this receipt image carefully.
    Extract:
    1. Every line item purchased (clean name without currency symbols, quantity as integer, unit price as float, total price as float).
    2. Tax amount (SST, GST, sales tax, or VAT). If none detected, 0.0.
    3. Service charge, fee, or tip amount. If none detected, 0.0.
    4. Rounding adjustment amount (e.g. in Malaysia / Singapore 5-sen rounding mechanism: -0.02, +0.01, etc. If none detected, 0.0).
    5. Grand total amount (final payable amount after rounding adjustment).

    Return ONLY a valid JSON object with this exact structure (no markdown fences, no explanatory text):
    {
      "items": [
        {
          "name": "Item Name",
          "quantity": 1,
          "unitPrice": 10.50,
          "totalPrice": 10.50
        }
      ],
      "tax": 1.20,
      "serviceFee": 2.50,
      "rounding": -0.02,
      "totalAmount": 14.20
    }
    """

    /// Checks if Gemini AI scanning is available (has built-in or user-provided key).
    static var isAvailable: Bool {
        return !AppSecrets.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Resolves the effective Gemini API key to use.
    static func effectiveApiKey(userKey: String? = nil) -> String {
        if let key = userKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            return key
        }
        return AppSecrets.geminiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Resolves the effective Gemini model name to use.
    static func effectiveModel(userModel: String? = nil) -> String {
        if let m = userModel?.trimmingCharacters(in: .whitespacesAndNewlines), !m.isEmpty {
            return m
        }
        return AppSecrets.defaultGeminiModel
    }

    /// Scans a receipt using the Gemini API.
    /// - Parameters:
    ///   - image: The receipt image.
    ///   - apiKey: Google Gemini API key (defaults to AppSecrets.geminiApiKey).
    ///   - model: The model name (defaults to AppSecrets.defaultGeminiModel: "gemini-3.5-flash-lite").
    static func scanWithGemini(
        image: UIImage,
        apiKey: String = AppSecrets.geminiApiKey,
        model: String = AppSecrets.defaultGeminiModel
    ) async throws -> ParsedReceiptResult {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(
                domain: "GeminiScanner",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Gemini API key is missing."]
            )
        }

        // Downscale image if too large to ensure fast network upload
        let scaledImage = downscaleImageIfNeeded(image, maxDimension: 1280)
        guard let jpegData = scaledImage.jpegData(compressionQuality: 0.75) else {
            throw NSError(
                domain: "GeminiScanner",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Failed to process image data."]
            )
        }

        let base64Image = jpegData.base64EncodedString()
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gemini-3.5-flash-lite" : model.trimmingCharacters(in: .whitespacesAndNewlines)

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent?key=\(trimmedKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "GeminiScanner",
                code: 402,
                userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini API endpoint URL."]
            )
        }

        // Build Gemini API payload
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": systemPrompt],
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.1
            ]
        ]

        let httpBody = try JSONSerialization.data(withJSONObject: payload)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 30

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "GeminiScanner", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid network response."])
        }

        if httpResponse.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw NSError(
                domain: "GeminiScanner",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Gemini API error (\(httpResponse.statusCode)): \(errorBody)"]
            )
        }

        return try parseGeminiAPIResponse(data)
    }

    /// Parses the raw JSON response returned by the Gemini API endpoint.
    static func parseGeminiAPIResponse(_ data: Data) throws -> ParsedReceiptResult {
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = jsonObject["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let rawText = firstPart["text"] as? String else {
            throw NSError(domain: "GeminiScanner", code: 403, userInfo: [NSLocalizedDescriptionKey: "Could not read Gemini response content."])
        }

        // Sanitize raw text to strip any potential markdown formatting
        var cleanedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.hasPrefix("```json") {
            cleanedText = String(cleanedText.dropFirst(7))
        } else if cleanedText.hasPrefix("```") {
            cleanedText = String(cleanedText.dropFirst(3))
        }
        if cleanedText.hasSuffix("```") {
            cleanedText = String(cleanedText.dropLast(3))
        }
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonResultData = cleanedText.data(using: .utf8),
              let parsedDict = try JSONSerialization.jsonObject(with: jsonResultData) as? [String: Any] else {
            throw NSError(domain: "GeminiScanner", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to parse structured JSON from Gemini."])
        }

        var lineItems: [ReceiptLineItem] = []
        if let rawItems = parsedDict["items"] as? [[String: Any]] {
            for item in rawItems {
                let name = (item["name"] as? String) ?? "Item"
                let quantity = (item["quantity"] as? Int) ?? (Int(item["quantity"] as? Double ?? 1.0))
                let unitPrice = (item["unitPrice"] as? Double) ?? (item["price"] as? Double ?? 0.0)

                if unitPrice > 0 {
                    lineItems.append(ReceiptLineItem(
                        name: name,
                        unitPrice: unitPrice,
                        quantity: max(1, quantity),
                        assignedMemberIDs: []
                    ))
                }
            }
        }

        let tax = (parsedDict["tax"] as? Double) ?? 0.0
        let serviceFee = (parsedDict["serviceFee"] as? Double) ?? (parsedDict["serviceCharge"] as? Double ?? 0.0)
        var rounding = (parsedDict["rounding"] as? Double) ?? (parsedDict["roundingAdjustment"] as? Double ?? 0.0)
        let totalAmount = (parsedDict["totalAmount"] as? Double) ?? (parsedDict["total"] as? Double ?? 0.0)

        let computedSubtotal = lineItems.reduce(0.0) { $0 + $1.totalPrice }
        let preRounding = ((computedSubtotal + tax + serviceFee) * 100).rounded() / 100.0

        if rounding == 0.0 && totalAmount > 0 {
            let diff = ((totalAmount - preRounding) * 100).rounded() / 100.0
            if abs(diff) > 0.001 && abs(diff) <= 0.05 {
                rounding = diff
            }
        } else if rounding == 0.0 && totalAmount == 0.0 {
            rounding = MalaysianRounding.adjustment(for: preRounding)
        }

        let finalTotal = totalAmount > 0 ? totalAmount : ((preRounding + rounding) * 100).rounded() / 100.0

        return ParsedReceiptResult(
            items: lineItems,
            tax: (tax * 100).rounded() / 100.0,
            serviceFee: (serviceFee * 100).rounded() / 100.0,
            rounding: (rounding * 100).rounded() / 100.0,
            totalAmount: (finalTotal * 100).rounded() / 100.0
        )
    }

    // MARK: - Auto Bookkeeping for Back Tap

    /// Structured result returned from Gemini for automatic transaction bookkeeping.
    struct AutoBookkeepingResult {
        var merchant: String = "Receipt Purchase"
        var totalAmount: Double = 0.0
        var date: Date = .now
        var categoryName: String = "Food & Dining"
        var items: [ReceiptLineItem] = []
        var tax: Double = 0.0
        var serviceFee: Double = 0.0
        var rounding: Double = 0.0
        var notes: String = ""
    }

    private static let autoBookkeepingPrompt = """
    You are an expert AI financial bookkeeping assistant. Analyze this receipt, bill, invoice, or payment confirmation screenshot carefully.
    Extract:
    1. "merchant": The store, restaurant, vendor, or merchant name (clean, concise, e.g. "Starbucks", "FamilyMart", "Grab", "McDonald's", "Shell", "Uniqlo"). If not explicitly named, use a clean descriptive merchant title.
    2. "totalAmount": The grand total final payable amount after all discounts, taxes, fees, and rounding adjustments. Must be a positive decimal number.
    3. "date": The transaction date in "YYYY-MM-DD" format if visible, or null.
    4. "category": Choose the single most fitting category from: ["Food & Dining", "Transport", "Shopping", "Bills & Utilities", "Entertainment", "Health & Medical", "Education", "Travel", "Housing", "Other"].
    5. "items": Line items purchased, each with "name" (clean name), "quantity" (integer), "unitPrice" (float), "totalPrice" (float).
    6. "tax": Any tax (SST, GST, VAT) amount, else 0.0.
    7. "serviceFee": Service charge or tip, else 0.0.
    8. "rounding": Rounding adjustment if applicable (e.g. -0.02, +0.01), else 0.0.
    9. "notes": A brief summary of items bought (e.g. "2x Iced Latte, 1x Croissant").

    Return ONLY a valid JSON object with this exact structure (no markdown fences, no explanatory text):
    {
      "merchant": "Starbucks",
      "totalAmount": 28.50,
      "date": "2026-10-04",
      "category": "Food & Dining",
      "items": [
        { "name": "Iced Latte", "quantity": 2, "unitPrice": 11.00, "totalPrice": 22.00 },
        { "name": "Croissant", "quantity": 1, "unitPrice": 6.50, "totalPrice": 6.50 }
      ],
      "tax": 1.70,
      "serviceFee": 0.0,
      "rounding": 0.0,
      "notes": "2x Iced Latte, 1x Croissant"
    }
    """

    /// Scans a receipt screenshot specifically for 1-tap automated bookkeeping.
    static func scanForAutoBookkeeping(
        image: UIImage,
        apiKey: String = AppSecrets.geminiApiKey,
        model: String = AppSecrets.defaultGeminiModel
    ) async throws -> AutoBookkeepingResult {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            throw NSError(domain: "GeminiScanner", code: 400, userInfo: [NSLocalizedDescriptionKey: "Gemini API key is missing."])
        }

        let scaledImage = downscaleImageIfNeeded(image, maxDimension: 1280)
        guard let jpegData = scaledImage.jpegData(compressionQuality: 0.75) else {
            throw NSError(domain: "GeminiScanner", code: 401, userInfo: [NSLocalizedDescriptionKey: "Failed to process image data."])
        }

        let base64Image = jpegData.base64EncodedString()
        let cleanModel = model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "gemini-3.5-flash-lite" : model.trimmingCharacters(in: .whitespacesAndNewlines)

        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(cleanModel):generateContent?key=\(trimmedKey)"
        guard let url = URL(string: urlString) else {
            throw NSError(domain: "GeminiScanner", code: 402, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini API endpoint URL."])
        }

        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": autoBookkeepingPrompt],
                        [
                            "inlineData": [
                                "mimeType": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json",
                "temperature": 0.1
            ]
        ]

        let httpBody = try JSONSerialization.data(withJSONObject: payload)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody
        request.timeoutInterval = 30.0

        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "GeminiScanner", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API Error (\(httpResponse.statusCode)): \(errorText)"])
        }

        return try parseGeminiBookkeepingResponse(data)
    }

    /// Parses the raw JSON returned from Gemini into structured AutoBookkeepingResult.
    static func parseGeminiBookkeepingResponse(_ data: Data) throws -> AutoBookkeepingResult {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "GeminiScanner", code: 403, userInfo: [NSLocalizedDescriptionKey: "Malformed Gemini response JSON."])
        }

        guard let candidates = root["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let rawText = firstPart["text"] as? String else {
            throw NSError(domain: "GeminiScanner", code: 403, userInfo: [NSLocalizedDescriptionKey: "Could not read Gemini response content."])
        }

        var cleanedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.hasPrefix("```json") {
            cleanedText = String(cleanedText.dropFirst(7))
        } else if cleanedText.hasPrefix("```") {
            cleanedText = String(cleanedText.dropFirst(3))
        }
        if cleanedText.hasSuffix("```") {
            cleanedText = String(cleanedText.dropLast(3))
        }
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonResultData = cleanedText.data(using: .utf8),
              let parsedDict = try JSONSerialization.jsonObject(with: jsonResultData) as? [String: Any] else {
            throw NSError(domain: "GeminiScanner", code: 404, userInfo: [NSLocalizedDescriptionKey: "Failed to parse structured JSON from Gemini."])
        }

        let merchant = (parsedDict["merchant"] as? String) ?? (parsedDict["store"] as? String) ?? "Receipt Purchase"
        let category = (parsedDict["category"] as? String) ?? "Food & Dining"
        let notes = (parsedDict["notes"] as? String) ?? ""

        var lineItems: [ReceiptLineItem] = []
        if let rawItems = parsedDict["items"] as? [[String: Any]] {
            for item in rawItems {
                let name = (item["name"] as? String) ?? "Item"
                let quantity = (item["quantity"] as? Int) ?? (Int(item["quantity"] as? Double ?? 1.0))
                let unitPrice = (item["unitPrice"] as? Double) ?? (item["price"] as? Double ?? 0.0)

                if unitPrice > 0 {
                    lineItems.append(ReceiptLineItem(
                        name: name,
                        unitPrice: unitPrice,
                        quantity: max(1, quantity),
                        assignedMemberIDs: []
                    ))
                }
            }
        }

        let tax = (parsedDict["tax"] as? Double) ?? 0.0
        let serviceFee = (parsedDict["serviceFee"] as? Double) ?? (parsedDict["serviceCharge"] as? Double ?? 0.0)
        var rounding = (parsedDict["rounding"] as? Double) ?? (parsedDict["roundingAdjustment"] as? Double ?? 0.0)
        let totalAmount = (parsedDict["totalAmount"] as? Double) ?? (parsedDict["total"] as? Double ?? 0.0)

        let computedSubtotal = lineItems.reduce(0.0) { $0 + $1.totalPrice }
        let preRounding = ((computedSubtotal + tax + serviceFee) * 100).rounded() / 100.0

        if rounding == 0.0 && totalAmount > 0 {
            let diff = ((totalAmount - preRounding) * 100).rounded() / 100.0
            if abs(diff) > 0.001 && abs(diff) <= 0.05 {
                rounding = diff
            }
        }

        let finalTotal = totalAmount > 0 ? totalAmount : ((preRounding + rounding) * 100).rounded() / 100.0

        var transactionDate = Date.now
        if let dateStr = parsedDict["date"] as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            if let parsedDate = formatter.date(from: dateStr) {
                transactionDate = parsedDate
            } else {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                if let parsedDate = df.date(from: dateStr) {
                    transactionDate = parsedDate
                }
            }
        }

        return AutoBookkeepingResult(
            merchant: merchant.trimmingCharacters(in: .whitespacesAndNewlines),
            totalAmount: (finalTotal * 100).rounded() / 100.0,
            date: transactionDate,
            categoryName: category,
            items: lineItems,
            tax: (tax * 100).rounded() / 100.0,
            serviceFee: (serviceFee * 100).rounded() / 100.0,
            rounding: (rounding * 100).rounded() / 100.0,
            notes: notes
        )
    }

    /// Resizes image proportionally if dimensions exceed maxDimension to conserve network bandwidth.
    private static func downscaleImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > maxDimension || size.height > maxDimension else { return image }

        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }
}
