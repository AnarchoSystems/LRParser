//
//  Stack.swift
//  
//
//  Created by Markus Kasperczyk on 28.10.23.
//

public struct Stack<T> {
    
    var rep : [T] = []
    public init() {}
    
    mutating func push(_ t: T) {
        rep.append(t)
    }
    
    mutating func pop() -> T? {
        guard peek() != nil else {return nil}
        return rep.removeLast()
    }
    
    func peek() -> T? {
        rep.last
    }
    
}
