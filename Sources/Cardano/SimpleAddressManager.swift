//
//  SimpleAddressManager.swift
//  
//
//  Created by Ostap Danylovych on 29.10.2021.
//

import Foundation
import CardanoCore

public class SimpleAddressManager: AddressManager, CardanoBootstrapAware {
    private let fetchChunkSize = 20
    
    private weak var cardano: CardanoProtocol!
    
    private var syncQueue: DispatchQueue
    private var addresses: [Address: Bip32Path]
    private var accountAddresses: [Account: [Address]]
    private var accountChangeAddresses: [Account: [Address]]
    
    public init() {
        syncQueue = DispatchQueue(label: "AddressManager.Sync.Queue", target: .global())
        addresses = [:]
        accountAddresses = [:]
        accountChangeAddresses = [:]
    }
    
    public func bootstrap(cardano: CardanoProtocol) throws {
        self.cardano = cardano
    }
    
    private func fromIndex(for account: Account, change: Bool) -> Int {
        return syncQueue.sync {
            let addresses = (change ? accountChangeAddresses : accountAddresses)[account] ?? []
            return addresses.count
        }
    }
    
    public func accounts(_ cb: @escaping (Result<[Account], Error>) -> Void) {
        cardano.signer.accounts(cb)
    }
    
    public func new(for account: Account, change: Bool) throws -> Address {
        let from = fromIndex(for: account, change: change)
        let extended = account.derive(index: UInt32(from), change: change)
        try syncQueue.sync {
            guard var addresses = (change ? accountChangeAddresses : accountAddresses)[account] else {
                throw AddressManagerError.notInCache(account: account)
            }
            addresses.append(extended.address)
            if change {
                accountChangeAddresses[account] = addresses
            } else {
                accountAddresses[account] = addresses
            }
            self.addresses[extended.address] = extended.path
        }
        return extended.address
    }
    
    public func get(cached account: Account, change: Bool) throws -> [Address] {
        try syncQueue.sync {
            guard let addresses = (change ? accountChangeAddresses : accountAddresses)[account] else {
                throw AddressManagerError.notInCache(account: account)
            }
            return addresses
        }
    }
    
    public func get(for account: Account,
                    change: Bool,
                    _ cb: @escaping (Result<[Address], Error>) -> Void) {
        fetch(for: [account]) { res in
            cb(res.flatMap {
                Result { try self.get(cached: account, change: change) }
            })
        }
    }
    
    private func fetchNext(for account: Account,
                           index: Int,
                           all: [ExtendedAddress],
                           change: Bool,
                           _ cb: @escaping (Result<[ExtendedAddress], Error>) -> Void) {
        (1...fetchChunkSize).map { (Int) -> ExtendedAddress in
            account.derive(index: UInt32(index), change: change)
        }.asyncMap { address, mapped in
            self.cardano.network.getTransactionCount(for: address.address) { res in
                mapped(res.map { $0 > 0 ? address : nil })
            }
        }.exec { res in
            switch res {
            case .success(let addresses):
                let addresses = addresses.compactMap { $0 }
                if addresses.isEmpty {
                    cb(.success(all))
                } else {
                    self.fetchNext(for: account, index: index + 1, all: all + addresses, change: change, cb)
                }
            case .failure(let error):
                cb(.failure(error))
            }
        }
    }
    
    public func fetch(for accounts: [Account],
                      _ cb: @escaping (Result<Void, Error>) -> Void) {
        accounts.asyncMap { account, mapped in
            self.fetchNext(
                for: account,
                index: self.fromIndex(for: account, change: false),
                all: [],
                change: false
            ) { res in
                mapped(res.map { addresses in
                    self.syncQueue.sync {
                        addresses.forEach { address in
                            self.addresses[address.address] = address.path
                        }
                        self.accountAddresses[account] = addresses.map { $0.address }
                    }
                })
            }
        }.exec { cb($0.map { _ in }) }
    }
    
    public func fetchedAccounts() -> [Account] {
        syncQueue.sync {
            Array(accountAddresses.keys) + accountChangeAddresses.keys.filter {
                !accountAddresses.keys.contains($0)
            }
        }
    }
    
    public func extended(addresses: [Address]) throws -> [ExtendedAddress] {
        try syncQueue.sync {
            try addresses.map { address in
                guard let path = self.addresses[address] else {
                    throw try AddressManagerError.notInCache(address: address.bech32())
                }
                return ExtendedAddress(address: address, path: path)
            }
        }
    }
}