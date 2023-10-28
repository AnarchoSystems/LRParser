//
//  Constructions.swift
//  
//
//  Created by Markus Kasperczyk on 28.10.23.
//

public protocol Constructions : Rules {
    associatedtype Term
    associatedtype NTerm
    associatedtype Output
    var construction : Construction<Term, NTerm, Output> {get}
}

public extension Constructions {
    var rule: Rule<Term, NTerm> {
        let cons = construction
        return Rule(cons.lhs, rhs: cons.rhs)
    }
}

public struct Construction<T : Terminal, NT : NonTerminal, Output> {
    public let lhs : NT
    public let rhs : [Expr<T, NT>]
    public let parse : (inout Stack<Output>) throws -> Void
    public init(_ lhs: NT, expression rhs: Expr<T, NT>..., parse: @escaping (inout Stack<Output>) throws -> Void) {
        self.lhs = lhs
        self.rhs = rhs
        self.parse = parse
    }
}
