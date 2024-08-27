//
//  File.swift
//  
//
//  Created by Hao Fu on 16/1/2024.
//

import Foundation
import Flow
import KeychainAccess

public enum WalletType {
    case secureEnclave
    case seedPhrase
    case privateKey
    case keyStore
}

public protocol WalletProtocol {
    associatedtype Wallet
    associatedtype Secret
    
    var walletType: WalletType { get }
    
    var storage: StorageProtocol { get }
    
    static func create() throws -> Wallet
    static func create(id: String, password: String, sync: Bool) throws -> Wallet
    static func get(id: String, password: String) throws -> Wallet
    static func restore(secret: Secret) throws -> Wallet
    
    func store(id: String, password: String, sync: Bool) throws
    func isValidSignature(signature: Data, message: Data, signAlgo: Flow.SignatureAlgorithm) -> Bool
    func publicKey(signAlgo: Flow.SignatureAlgorithm) throws -> Data?
    func sign(data: Data, signAlgo: Flow.SignatureAlgorithm, hashAlgo: Flow.HashAlgorithm) throws -> Data
    func remove(id: String) throws
    
    func allKeys() -> [String]
    
    func account(chainID: Flow.ChainID) async throws -> [Flow.Account]
}


extension WalletProtocol {
    public var storage: StorageProtocol {
        FWKManager.shared.storage
    }
    
    public func remove(id: String) throws {
        try storage.remove(id)
    }
    
    public func allKeys() -> [String] {
        storage.allKeys
    }
    
    public func account(chainID: Flow.ChainID) async throws -> [Flow.Account] {
        var accounts: [KeyIndexerResponse.Account] = []
        if let p256Key = try publicKey(signAlgo: .ECDSA_P256)?.hexString {
            async let p256KeyRequest = Network.findAccountByKey(publicKey: p256Key, chainID: chainID)
            try await accounts += p256KeyRequest
        }
        
        if let secp256k1Key = try publicKey(signAlgo: .ECDSA_SECP256k1)?.hexString {
            async let secp256k1KeyRequest = Network.findAccountByKey(publicKey: secp256k1Key, chainID: chainID)
            try await accounts += secp256k1KeyRequest
        }
        
        let addresses = Set(accounts).compactMap{ Flow.Address(hex: $0.address) }
        return try await fetchAccounts(addresses: addresses)
    }
    
    public func fetchAccounts(addresses: [Flow.Address]) async throws -> [Flow.Account] {
        try await withThrowingTaskGroup(of: Flow.Account.self) { group in
            
            addresses.forEach { address in
                group.addTask { try await Flow.shared.accessAPI.getAccountAtLatestBlock(address: address) }
            }

            var result = [Flow.Account]()

            for try await image in group {
                result.append(image)
            }

            return result
        }
    }
}
