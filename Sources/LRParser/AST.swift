//
//  AST.swift
//
//
//  Created by Markus Kasperczyk on 31.10.23.
//

public enum ASTChildType<R : Rules> {
    indirect case ast(ast: AST<R>, variable: R.NTerm)
    case leave(terminal: R.Term)
}

public struct AST<R : Rules> {
    
    public let rule : R
    public let children : [ASTChildType<R>]
    
    public init(rule: R, children: [ASTChildType<R>]) {
        self.rule = rule
        self.children = children
    }
    
}
