//
//  Action.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public enum Action<R : Rules> : Codable, Equatable {
    case shift(Int)
    case reduce(R)
    case accept
    
    enum RawType : String, Codable {
        case shift, reduce, accept
    }
    struct TypeCoder : Codable {
        let type : RawType
    }
    enum _Shift : String, Codable {case shift}
    struct Shift : Codable {
        let type : _Shift
        let newState : Int
    }
    enum _Reduce : String, Codable {case reduce}
    struct Reduce : Codable {
        let type : _Reduce
        let rule : R
    }
    
    public init(from decoder: Decoder) throws {
        let type = try TypeCoder(from: decoder)
        switch type.type {
        case .shift:
            let this = try Shift(from: decoder)
            self = .shift(this.newState)
        case .reduce:
            let this = try Reduce(from: decoder)
            self = .reduce(this.rule)
        case .accept:
            self = .accept
        }
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .shift(let newState):
            try Shift(type: .shift, newState: newState).encode(to: encoder)
        case .reduce(let rule):
            try Reduce(type: .reduce, rule: rule).encode(to: encoder)
        case .accept:
            try TypeCoder(type: .accept).encode(to: encoder)
        }
    }
}
