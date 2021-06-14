//
//  BootstrapWitness.swift
//  
//
//  Created by Ostap Danylovych on 15.06.2021.
//

import Foundation
import CCardano

public struct BootstrapWitness {
    public private(set) var vkey: Vkey
    public private(set) var signature: Ed25519Signature
    public private(set) var chainCode: Data
    public private(set) var attributes: Data
    
    init(bootstrapWitness: CCardano.BootstrapWitness) {
        vkey = bootstrapWitness.vkey.copied()
        signature = bootstrapWitness.signature.copied()
        chainCode = bootstrapWitness.chain_code.copied()
        attributes = bootstrapWitness.attributes.copied()
    }
    
    public init(vkey: Vkey, signature: Ed25519Signature, chainCode: Data, attributes: Data) {
        self.vkey = vkey
        self.signature = signature
        self.chainCode = chainCode
        self.attributes = attributes
    }
    
    func clonedCBootstrapWitness() throws -> CCardano.BootstrapWitness {
        try withCBootstrapWitness { try $0.clone() }
    }
    
    func withCBootstrapWitness<T>(
        fn: @escaping (CCardano.BootstrapWitness) throws -> T
    ) rethrows -> T {
        try vkey.withCVkey { vkey in
            try signature.withCSignature { signature in
                try chainCode.withCData { chainCode in
                    try attributes.withCData { attributes in
                        try fn(CCardano.BootstrapWitness(vkey: vkey, signature: signature, chain_code: chainCode, attributes: attributes))
                    }
                }
            }
        }
    }
}

extension CCardano.BootstrapWitness: CPtr {
    typealias Value = BootstrapWitness
    
    func copied() -> BootstrapWitness {
        BootstrapWitness(bootstrapWitness: self)
    }
    
    mutating func free() {
        cardano_bootstrap_witness_free(&self)
    }
}

extension CCardano.BootstrapWitness {
    public func clone() throws -> Self {
        try RustResult<Self>.wrap { result, error in
            cardano_bootstrap_witness_clone(self, result, error)
        }.get()
    }
}