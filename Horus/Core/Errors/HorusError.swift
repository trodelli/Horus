//
//  HorusError.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation

/// Top-level error type for the Horus application
enum HorusError: Error, LocalizedError {
    case document(DocumentLoadError)
    case ocr(OCRError)
    case network(NetworkError)
    case keychain(KeychainError)
    case export(ExportError)
    case session(SessionError)
    case documentNotProcessed
    case featureNotImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .document(let error):
            return error.localizedDescription
        case .ocr(let error):
            return error.localizedDescription
        case .network(let error):
            return error.localizedDescription
        case .keychain(let error):
            return error.localizedDescription
        case .export(let error):
            return error.localizedDescription
        case .session(let error):
            return error.localizedDescription
        case .documentNotProcessed:
            return "Document Not Processed"
        case .featureNotImplemented(let feature):
            return feature
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .document(let error):
            return error.recoverySuggestion
        case .ocr(let error):
            return error.recoverySuggestion
        case .network(let error):
            return error.recoverySuggestion
        case .keychain:
            return "Try removing and re-adding your API key in Settings."
        case .export:
            return "Check that you have write permission to the destination folder."
        case .session:
            return nil
        case .documentNotProcessed:
            return "This document hasn't been processed yet. Complete OCR or Cleaning before adding to Library."
        case .featureNotImplemented:
            return "This feature is coming in a future update."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .ocr(let error):
            return error.isRetryable
        case .network(let error):
            return error.isRetryable
        default:
            return false
        }
    }
}

// MARK: - Document Load Errors

/// Errors that occur when loading/validating documents
enum DocumentLoadError: Error, LocalizedError {
    case fileNotFound(URL)
    case fileNotReadable(URL)
    case fileTooLarge(size: Int64, maxSize: Int64)
    case unsupportedFormat(String)
    case encryptedPDF
    case corruptedFile
    case tooManyPages(count: Int, maxPages: Int)
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        case .fileNotReadable(let url):
            return "Cannot read file: \(url.lastPathComponent)"
        case .fileTooLarge(let size, let maxSize):
            let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
            let maxStr = ByteCountFormatter.string(fromByteCount: maxSize, countStyle: .file)
            return "File too large (\(sizeStr)). Maximum size is \(maxStr)."
        case .unsupportedFormat(let ext):
            return "Unsupported file format: .\(ext)"
        case .encryptedPDF:
            return "This PDF is password-protected"
        case .corruptedFile:
            return "This file appears to be corrupted"
        case .tooManyPages(let count, let maxPages):
            return "Document has \(count) pages. Maximum is \(maxPages)."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .fileNotFound:
            return "Check that the file exists and try again."
        case .fileNotReadable:
            return "Check file permissions and try again."
        case .fileTooLarge:
            return "Try splitting the document into smaller files."
        case .unsupportedFormat:
            return "Supported formats: PDF, PNG, JPEG, TIFF, GIF, WebP"
        case .encryptedPDF:
            return "Remove the password protection from the PDF and try again."
        case .corruptedFile:
            return "Try re-creating or re-downloading the file."
        case .tooManyPages:
            return "Split the document into smaller parts."
        }
    }
}

// MARK: - OCR Errors
// Note: OCRError is defined in OCRService.swift to keep error types close to their usage

// MARK: - Network Errors

/// Low-level network errors
enum NetworkError: Error, LocalizedError {
    case noConnection
    case timeout
    case invalidURL
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .noConnection:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .invalidURL:
            return "Invalid URL"
        case .httpError(let code, let message):
            if let message = message {
                return "HTTP error \(code): \(message)"
            }
            return "HTTP error \(code)"
        case .decodingError(let detail):
            return "Failed to parse response: \(detail)"
        case .unknown(let message):
            return message
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noConnection:
            return "Check your internet connection and try again."
        case .timeout:
            return "The server is slow to respond. Try again in a moment."
        case .invalidURL:
            return nil
        case .httpError:
            return "Try again. If this persists, contact support."
        case .decodingError:
            return "Try again. If this persists, contact support."
        case .unknown:
            return "Try again."
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout:
            return true
        case .httpError(let code, _):
            return code >= 500 || code == 429
        default:
            return false
        }
    }
}

// MARK: - Keychain Errors

/// Errors from Keychain operations
enum KeychainError: Error, LocalizedError {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case notFound
    case unexpectedData
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let status):
            return "Failed to save to Keychain (error \(status))"
        case .loadFailed(let status):
            return "Failed to load from Keychain (error \(status))"
        case .deleteFailed(let status):
            return "Failed to delete from Keychain (error \(status))"
        case .notFound:
            return "API key not found in Keychain"
        case .unexpectedData:
            return "Unexpected data format in Keychain"
        }
    }
}

// MARK: - Session Errors (defined in ProcessingSession.swift)
// Note: SessionError is defined in ProcessingSession.swift to avoid duplication

// MARK: - Export Errors
// Note: ExportError is defined in ExportService.swift to keep error types close to their usage

