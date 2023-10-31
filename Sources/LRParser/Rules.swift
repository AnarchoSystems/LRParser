//
//  Rules.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

public protocol Terminal : RawRepresentable, CustomDebugStringConvertible, CaseIterable, Codable, Hashable where RawValue == Character {}

public extension Terminal {
    init(from decoder: Decoder) throws {
        let char = try String(from: decoder)
        guard char.count == 1 else {throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "\(char) is not a character!"))}
        guard let this = Self(rawValue: char.first!) else {throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid character \(char) recognized!"))}
        self = this
    }
    func encode(to encoder: Encoder) throws {
        try String(rawValue).encode(to: encoder)
    }
    var debugDescription: String {
        String(rawValue)
    }
}

public protocol NonTerminal : RawRepresentable, CustomDebugStringConvertible, CaseIterable, Codable, Hashable where RawValue == String {}

public extension NonTerminal {
    var debugDescription: String {
        rawValue
    }
}

public protocol Rules<Term, NTerm> : RawRepresentable, CaseIterable, Codable, Hashable where RawValue == String {
    associatedtype Term : Terminal
    associatedtype NTerm : NonTerminal
    static var goal : NTerm {get}
    var rule : Rule<Self> {get}
}


public struct Rule<R: Rules> {
    public let lhs : R.NTerm
    public let rhs : [Expr<R>]
    public let transform : (AST<R>) throws -> AST<R>
    public init(_ lhs: R.NTerm, expression rhs: Expr<R>..., transform: @escaping (AST<R>) throws -> AST<R> = {$0}) {
        self.lhs = lhs
        self.rhs = rhs
        self.transform = transform
    }
    public init(_ lhs: R.NTerm, rhs: [Expr<R>], transform: @escaping (AST<R>) throws -> AST<R> = {$0}) {
        self.lhs = lhs
        self.rhs = rhs
        self.transform = transform
    }
}

public extension Rules {
    
    var printed : String {
        let rule = self.rule
        return rawValue + ":\n\t" + rule.lhs.rawValue + " -> " + rule.rhs.map{
            switch $0 {
            case .term(let term):
                return "\'\(term.rawValue)\'"
            case .nonTerm(let nonTerm):
                return "<\(nonTerm.rawValue)>"
            }
        }.joined(separator: " ")
    }
    
    static var printed : String {
        allCases.lazy.map(\.printed).joined(separator: "\n")
    }
    
}
