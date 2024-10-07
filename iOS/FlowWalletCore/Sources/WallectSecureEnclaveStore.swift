//
//  WallectSecureEnclaveStore.swift
//  FRW
//
//  Created by cat on 2023/11/7.
//

import Foundation
import KeychainAccess

public extension WallectSecureEnclave {
    enum StoreError: Error {
        case unowned
        case encode
        case decode
        case emptyKeychain
    }

    enum Store {
        private static var service: String = "com.flowfoundation.wallet.securekey"
        private static var userKey: String = "user.keystore"

        public static func config(service: String) throws {
            if !service.isEmpty {
                Store.service = service
            }
        }

        public static func store(key: String, value: Data) throws {
            storeBackup(key: key, value: value)
            var userList = try fetch()
            let targetModel = userList.first { info in
                info.uniq == key
            }
            if targetModel == nil {
                let newModel = StoreInfo(uniq: key, publicKey: value)
                userList.insert(newModel, at: 0)
            }
            try Store.store(list: userList)
        }

        private static func storeBackup(key: String, value: Data) {
            if key.isEmpty || value.isEmpty {
                return
            }
            let keychain = twoBackupKeychain
            keychain[data: key] = value
        }
        
        public static func migrationFromLilicoTag() {
            let lilicoService = "io.outblock.lilico.securekey"
            let keychain = Keychain(service: lilicoService)
            guard let data = try? keychain.getData(userKey) else {
                print("[SecureEnclave] migration empty ")
                return
            }
            guard let users = try? JSONDecoder().decode([StoreInfo].self, from: data) else {
                print("[SecureEnclave] decoder failed on loginedUser ")
                return
            }
            for model in users {
                try? store(key: model.uniq, value: model.publicKey)
            }
        }
        
        public static func twoBackupIfNeed() throws {
            let userList = try fetch()
            let twoKeys = twoBackupKeychain.allKeys()
            if twoKeys.count == userList.count {
                return
            }
            for model in userList {
                storeBackup(key: model.uniq, value: model.publicKey)
            }
        }
        
        private static var twoBackupKeychain: Keychain {
            let backupService = service + ".backup"
            let keychain = Keychain(service: backupService)
            return keychain
        }
        
        private static func store(list: [StoreInfo]) throws {
            guard let data = try? JSONEncoder().encode(list) else {
                print("[SecureEnclave] store failed ")
                throw StoreError.encode
            }
            let keychain = Keychain(service: service)
            keychain[data: userKey] = data
        }

//        public static func delete(key: String) throws -> Bool {
//            var userList = try fetch()
//            let index = userList.firstIndex { info in
//                info.uniq == key
//            }
//            if index == nil {
//                return false
//            }
//            userList.remove(at: index!)
//            try store(list: userList)
//            return true
//        }

        public static func fetch() throws -> [StoreInfo] {
            let keychain = Keychain(service: service)
            guard let data = try keychain.getData(userKey) else {
                print("[SecureEnclave] get value from keychain empty ")
                return []
            }
            guard let users = try? JSONDecoder().decode([StoreInfo].self, from: data) else {
                print("[SecureEnclave] decoder failed on loginedUser ")
                throw StoreError.encode
            }
            return users
        }
        
        public static func fetch(by key: String) throws -> Data? {
            let list: [StoreInfo] = try fetch()
            let model = list.first { info in
                info.uniq == key
            }
            return model?.publicKey
        }
    }

    struct StoreInfo: Codable {
        public var uniq: String
        public var publicKey: Data
        
        public init(uniq: String, publicKey: Data) {
            self.uniq = uniq
            self.publicKey = publicKey
        }
    }
}
