//
//  Expr.swift
//  
//
//  Created by Markus Kasperczyk on 28.10.23.
//

public enum Expr<T : Hashable, NT : Hashable> : Hashable {
    case term(T)
    case nonTerm(NT)
}

prefix operator /

public prefix func /<T, NT>(_ t: T) -> Expr<T, NT> {
    .term(t)
}

public prefix func /<T, NT>(_ nt: NT) -> Expr<T, NT> {
    .nonTerm(nt)
}
