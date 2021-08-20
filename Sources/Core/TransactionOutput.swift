//
//  TransactionOutput.swift
//  
//
//  Created by Ostap Danylovych on 30.06.2021.
//

import Foundation
import CCardano

public struct TransactionOutput {
    public private(set) var address: Address
    public private(set) var amount: Value
    
    init(transactionOutput: CCardano.TransactionOutput) {
        address = transactionOutput.address.copied()
        amount = transactionOutput.amount.copied()
    }
    
    public init(address: Address, amount: Value) {
        self.address = address
        self.amount = amount
    }
    
    func clonedTransactionOutput() throws -> CCardano.TransactionOutput {
        try withCTransactionOutput { try $0.clone() }
    }

    func withCTransactionOutput<T>(
        fn: @escaping (CCardano.TransactionOutput) throws -> T
    ) rethrows -> T {
        try address.withCAddress { address in
            try amount.withCValue { amount in
                try fn(CCardano.TransactionOutput(
                    address: address,
                    amount: amount
                ))
            }
        }
    }
}

extension CCardano.TransactionOutput: CPtr {
    typealias Val = TransactionOutput

    func copied() -> TransactionOutput {
        TransactionOutput(transactionOutput: self)
    }

    mutating func free() {
        cardano_transaction_output_free(&self)
    }
}

extension CCardano.TransactionOutput {
    public init(bytes: Data) throws {
        self = try bytes.withCData { bytes in
            RustResult<Self>.wrap { result, error in
                cardano_transaction_output_from_bytes(bytes, result, error)
            }
        }.get()
    }
    
    public func bytes() throws -> Data {
        var bytes = try RustResult<CData>.wrap { result, error in
            cardano_transaction_output_to_bytes(self, result, error)
        }.get()
        return bytes.owned()
    }
    
    public func clone() throws -> Self {
        try RustResult<Self>.wrap { result, error in
            cardano_transaction_output_clone(self, result, error)
        }.get()
    }
}

public typealias TransactionOutputs = Array<TransactionOutput>

extension CCardano.TransactionOutputs: CArray {
    typealias CElement = CCardano.TransactionOutput

    mutating func free() {
        cardano_transaction_outputs_free(&self)
    }
}

extension TransactionOutputs {
    func withCArray<T>(fn: @escaping (CCardano.TransactionOutputs) throws -> T) rethrows -> T {
        try withCArray(with: { try $0.withCTransactionOutput(fn: $1) }, fn: fn)
    }
}