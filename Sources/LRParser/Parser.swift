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

private extension Parser {
    
    func gatherExeptionData(_ state: Int, current: R.Term?) -> Error {
        var nonTerms = Set<R.NTerm>()
        var nextStates : Set<Int> = [state]
        while !nextStates.isEmpty {
            var nextNextStates : Set<Int> = []
            for ns in nextStates {
                let actions = self.actions.compactMap({ (key: R.Term?, value: [Int : Action<R>]) in
                    value[ns].map{(key, $0)}
                })
                for (_, action) in actions {
                    switch action {
                    case .shift(let int):
                        nextNextStates.insert(int)
                    case .reduce(let r):
                        nonTerms.insert(r.rule.lhs)
                    case .accept:
                        continue
                    }
                }
            }
            nextStates = nextNextStates
        }
        return UnexpectedChar(char: current?.rawValue, expecting: Set(nonTerms.map(\.rawValue)))
    }
    
}

public extension Parser {
    
    func withStack<Out>(_ stream: String, do construction: (R, inout Stack<Out>) throws -> Void) throws ->Stack<Out> {
        
        var index = stream.startIndex
        var current = stream.first
        
        var stateStack = Stack<Int>()
        stateStack.push(0)
        var outStack = Stack<Out>()
        
    loop:
        while true {
            
            let term = try current.map{char in
                guard let res = R.Term(rawValue: char) else {
                    throw InvalidChar(position: index, char: char)
                }
                return res
            }
            guard let stateBefore = stateStack.peek() else {
                throw UndefinedState(position: index)
            }
            guard let dict = actions[term] else {
                throw InvalidChar(position: index, char: current ?? "$")
            }
            guard let action = dict[stateBefore] else {
                var parent = stateBefore
                while let p = stateStack.pop() {
                    if nil != stateStack.peek() {
                        parent = p
                    }
                }
                throw gatherExeptionData(parent, current: term)
            }
            
            switch action {
                
            case .shift(let shift):
                stateStack.push(shift)
                index = stream.index(after: index)
                current = stream.indices.contains(index) ? stream[index] : nil
                
            case .reduce(let reduce):
                let rule = reduce.rule
                for _ in rule.rhs {
                    _ = stateStack.pop()
                }
                guard let stateAfter = stateStack.peek() else {
                    throw UndefinedState(position: index)
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
        try withStack(stream, do: {$1.push($0)})
    }
    
    func parse(_ stream: String) throws -> AST<R>? {
        var stack = try withStack(stream) { (rule, stack : inout Stack<AST<R>>) in
            let constr = rule.rule
            
            var children = [ASTChildType<R>]()
            
            for rhs in constr.rhs {
                switch rhs {
                case .term(let t):
                    children.append(.leave(terminal: t))
                case .nonTerm:
                    guard let pop = stack.pop() else {
                        throw StackIsEmpty(rule: rule)
                    }
                    children.append(.ast(ast: pop))
                }
            }
            
            children.reverse()
            
            let newAst = try constr.transform(AST(rule: rule, children: children))
            if newAst.rule.rule.lhs != constr.lhs {
                throw InvalidASTTransform(lhsBefore: newAst.rule.rule.lhs, lhsAfter: constr.lhs)
            }
            stack.push(newAst)
            
        }
        return stack.pop()
    }
    
}

public struct StackIsEmpty<R: Rules> : Error {
    public let rule : R
}

public struct InvalidASTTransform<NTerm : NonTerminal> : Error {
    public let lhsBefore : NTerm
    public let lhsAfter : NTerm
}
