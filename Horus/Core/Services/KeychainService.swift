//
//  KeychainService.swift
//  Horus
//
//  Created on 06/01/2026.
//

import Foundation
import Security
import OSLog

// MARK: - Protocol

/// Protocol for Keychain operations (enables testing with mock implementations)
protocol KeychainServiceProtocol {
    /// Store the API key securely in the Keychain
    func storeAPIKey(_ key: String) throws
    
    /// Retrieve the stored API key from the Keychain
    func retrieveAPIKey() throws -> String?
    
    /// Delete the API key from the Keychain
    func deleteAPIKey() throws
    
    /// Check if an API key is currently stored
    var hasAPIKey: Bool { get }
}

// MARK: - Implementation

/// Service for secure storage of API credentials using macOS Keychain.
/// 
/// The Keychain provides encrypted storage that persists across app launches
/// and is protected by the user's login credentials. This is the recommended
/// way to store sensitive data like API keys on macOS.
final class KeychainService: KeychainServiceProtocol {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.horus.app", category: "Keychain")
    
    /// Service name used to identify our Keychain items
    private let serviceName = "com.horus.app"
    
    /// Account name for the API key entry
    private let accountName = "mistral-api-key"
    
    // MARK: - Singleton
    
    /// Shared instance for app-wide use
    static let shared = KeychainService()
    
    // MARK: - KeychainServiceProtocol
    
    /// Check if an API key is currently stored
    var hasAPIKey: Bool {
        do {
            return try retrieveAPIKey() != nil
        } catch {
            logger.warning("Error checking for API key: \(error.localizedDescription)")
            return false
        }
    }
    
    /// Store the API key securely in the Keychain
    /// - Parameter key: The API key to store
    /// - Throws: KeychainError if the operation fails
    func storeAPIKey(_ key: String) throws {
        // Convert string to data
        guard let keyData = key.data(using: .utf8) else {
            logger.error("Failed to convert API key to data")
            throw KeychainError.unexpectedData
        }
        
        // Delete any existing key first to avoid duplicates
        try? deleteAPIKey()
        
        // Build the query for adding a new item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: keyData,
            // Only accessible when the device is unlocked
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Add the item to the Keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            logger.error("Failed to store API key: \(status)")
            throw KeychainError.saveFailed(status)
        }
        
        logger.info("API key stored successfully")
    }
    
    /// Retrieve the stored API key from the Keychain
    /// - Returns: The API key if found, nil otherwise
    /// - Throws: KeychainError if the operation fails (other than item not found)
    func retrieveAPIKey() throws -> String? {
        // Build the query for retrieving the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // Attempt to retrieve the item
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        // Handle the result
        switch status {
        case errSecSuccess:
            // Successfully found the item
            guard let data = result as? Data,
                  let key = String(data: data, encoding: .utf8) else {
                logger.error("Failed to decode API key data")
                throw KeychainError.unexpectedData
            }
            return key
            
        case errSecItemNotFound:
            // Item doesn't exist - this is not an error
            return nil
            
        default:
            // Some other error occurred
            logger.error("Failed to retrieve API key: \(status)")
            throw KeychainError.loadFailed(status)
        }
    }
    
    /// Delete the API key from the Keychain
    /// - Throws: KeychainError if the operation fails (other than item not found)
    func deleteAPIKey() throws {
        // Build the query for deleting the item
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        
        // Attempt to delete the item
        let status = SecItemDelete(query as CFDictionary)
        
        // Handle the result
        switch status {
        case errSecSuccess, errSecItemNotFound:
            // Success or item didn't exist anyway
            logger.info("API key deleted (or was not present)")
            
        default:
            // Some other error occurred
            logger.error("Failed to delete API key: \(status)")
            throw KeychainError.deleteFailed(status)
        }
    }
}

// MARK: - API Key Validation

extension KeychainService {
    
    /// Validates that a string looks like a valid Mistral API key format.
    /// This is a basic format check, not a verification against the API.
    /// - Parameter key: The key to validate
    /// - Returns: true if the format appears valid
    static func isValidKeyFormat(_ key: String) -> Bool {
        // Accept any non-empty key that's reasonably long
        // The actual validation happens when we call the API
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count >= 10
    }
    
    /// Check if a key appears to be in the standard Mistral format (sk-...)
    static func isStandardMistralFormat(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("sk-") && trimmed.count >= 20
    }
    
    /// Returns a masked version of the API key for display
    /// - Parameter key: The full API key
    /// - Returns: A masked string like "sk-****...****"
    static func maskedKey(_ key: String) -> String {
        guard key.count > 10 else { return "****" }
        let prefix = String(key.prefix(5))
        let suffix = String(key.suffix(4))
        return "\(prefix)****...****\(suffix)"
    }
}

// MARK: - Mock Implementation for Testing

/// Mock implementation of KeychainService for use in previews and tests
final class MockKeychainService: KeychainServiceProtocol {
    
    private var storedKey: String?
    var shouldFailOnSave = false
    var shouldFailOnLoad = false
    
    var hasAPIKey: Bool {
        storedKey != nil
    }
    
    func storeAPIKey(_ key: String) throws {
        if shouldFailOnSave {
            throw KeychainError.saveFailed(errSecAuthFailed)
        }
        storedKey = key
    }
    
    func retrieveAPIKey() throws -> String? {
        if shouldFailOnLoad {
            throw KeychainError.loadFailed(errSecAuthFailed)
        }
        return storedKey
    }
    
    func deleteAPIKey() throws {
        storedKey = nil
    }
}
