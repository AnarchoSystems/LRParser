//
//  Expr.swift
//  
//
//  Created by Markus Kasperczyk on 28.10.23.
//

public enum Expr<R : Rules> : Hashable {
    case term(R.Term)
    case nonTerm(R.NTerm)
}

prefix operator /

public prefix func /<R : Rules>(_ t: R.Term) -> Expr<R> {
    .term(t)
}

public prefix func /<R : Rules>(_ nt: R.NTerm) -> Expr<R> {
    .nonTerm(nt)
}
