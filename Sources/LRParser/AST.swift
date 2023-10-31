//
//  AST.swift
//
//
//  Created by Markus Kasperczyk on 31.10.23.
//

public enum ASTChildType<R : Rules> : Equatable {
    indirect case ast(ast: AST<R>)
    case leaf(terminal: R.Term)
}

public struct AST<R : Rules> : Equatable {
    
    public let rule : R
    public let children : [ASTChildType<R>]
    
    public init(rule: R, children: [ASTChildType<R>]) {
        self.rule = rule
        self.children = children
    }
    
}
