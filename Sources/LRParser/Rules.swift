//
//  Rules.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

public protocol Terminal : RawRepresentable, CaseIterable, Codable, Hashable where RawValue == Character {}

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
}

public protocol NonTerminal : RawRepresentable, CaseIterable, Codable, Hashable where RawValue == String {}

public protocol Rules : RawRepresentable, CaseIterable, Codable, Hashable where RawValue == String {
    associatedtype Term : Terminal
    associatedtype NTerm : NonTerminal
    static var goal : NTerm {get}
    var rule : Rule<Term, NTerm> {get}
}


public struct Rule<T : Terminal, NT : NonTerminal> {
    public let lhs : NT
    public let rhs : [Expr<T, NT>]
    public init(_ lhs: NT, expression rhs: Expr<T, NT>...) {
        self.lhs = lhs
        self.rhs = rhs
    }
    init(_ lhs: NT, rhs: [Expr<T, NT>]) {
        self.lhs = lhs
        self.rhs = rhs
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
