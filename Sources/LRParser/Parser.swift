//
//  Parser.swift
//
//
//  Created by Markus Kasperczyk on 29.10.23.
//

public struct Parser<R : Rules> : Codable, Equatable {
    
    public let actions : [R.Term? : [Int : Action<R>]]
    public let gotos : [R.NTerm : [Int : Int]]
    
    public init(actions: [R.Term? : [Int : Action<R>]],
                gotos: [R.NTerm : [Int : Int]]) {
        self.actions = actions
        self.gotos = gotos
    }
    
}

public extension Parser {
    
    func parse<Out>(_ stream: String, do construction: (R, inout Stack<Out>) throws -> Void) throws ->Stack<Out> {
        
        var iterator = stream.makeIterator()
        var current = iterator.next()
        
        var stateStack = Stack<Int>()
        stateStack.push(0)
        var outStack = Stack<Out>()
        
    loop:
        while true {
            
            let term = try current.map{char in
                guard let res = R.Term(rawValue: char) else {throw InvalidChar(char: char)}
                return res
            }
            guard let stateBefore = stateStack.peek() else {
                throw UndefinedState()
            }
            guard let dict = actions[term] else {throw InvalidChar(char: current ?? "$")}
            guard let action = dict[stateBefore] else {
                throw UndefinedState()
            }
            
            switch action {
                
            case .shift(let shift):
                stateStack.push(shift)
                current = iterator.next()
                
            case .reduce(let reduce):
                let rule = reduce.rule
                for _ in rule.rhs {
                    _ = stateStack.pop()
                }
                guard let stateAfter = stateStack.peek() else {
                    throw UndefinedState()
                }
                try construction(reduce, &outStack)
                guard let nextState = gotos[rule.lhs]?[stateAfter] else {throw NoGoTo(nonTerm: rule.lhs, state: stateAfter)}
                stateStack.push(nextState)
                
            case .accept:
                break loop
            }
            
        }
        return outStack
    }
    
    func buildStack(_ stream: String) throws -> Stack<R> {
        try parse(stream, do: {$1.push($0)})
    }
    
    func parse(_ stream: String) throws -> R.Output? where R : Constructions {
        var stack = try parse(stream, do: {try $0.construction.parse(&$1)})
        return stack.pop()
    }
    
}
