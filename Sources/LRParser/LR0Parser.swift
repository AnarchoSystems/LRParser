//
//  LR0Parser.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

// MARK: LR(0) ITEMS

fileprivate struct Item<R : Rules> : Node {
    
    let rule : R?
    let all : [Expr<R.Term, R.NTerm>]
    let ptr : Int
    
    var canReach: [R.NTerm : [Item<R>]] {
        guard let next = tbd.first, case .nonTerm(let nT) = next else {
            return [:]
        }
        return [nT : R.allCases.compactMap {rule in
            let ru = rule.rule
            guard ru.lhs == nT else {return nil}
            return Item(rule: rule, all: ru.rhs, ptr: 0)
        }]
    }
    
}

// MARK: LR(0) ITEM SETS

fileprivate struct ItemSet<R : Rules> {
    
    let graph : ClosedGraph<Item<R>>
    
}

// MARK: HELPERS

extension Item {
    
    func tryAdvance(_ expr: Expr<R.Term, R.NTerm>) -> Item<R>? {
        tbd.first.flatMap{$0 == expr ? Item(rule: rule, all: all, ptr: ptr + 1) : nil}
    }
    var tbd : some Collection<Expr<R.Term, R.NTerm>> {
        all[ptr...]
    }
    
}

extension ItemSet : Node {
    
    var canReach: [Expr<R.Term, R.NTerm> : [ItemSet<R>]] {
        let exprs = Set(graph.nodes.compactMap(\.tbd.first))
        return Dictionary(uniqueKeysWithValues: exprs.map{expr in
            (expr, [ItemSet(graph: ClosedGraph(seeds: graph.nodes.compactMap{$0.tryAdvance(expr)}))])
        })
    }
}

// MARK: LR(0) GRAPH

fileprivate struct ItemSetTable<R : Rules> {
    
    let graph : ClosedGraph<ItemSet<R>>
    
    init(rules: R.Type) {
        let augmentedRule = Item<R>(rule: nil, all: [.nonTerm(R.goal)], ptr: 0)
        let itemSetGraph = ClosedGraph(seeds: [augmentedRule])
        graph = ClosedGraph(seeds: [ItemSet(graph: itemSetGraph)])
    }
    
}

// MARK: HELPER

extension ItemSet {
    
    func reduceRule() throws -> R? {
        let results : [R] = graph.nodes.lazy.filter(\.tbd.isEmpty).compactMap(\.rule)
        if results.count > 1 {
            throw ReduceReduceConflict(matching: results)
        }
        return results.first
    }
    
    
}

// MARK: ACTION + GOTO TABLES

extension ItemSetTable {
    
    func actionTable() throws -> [R.Term? : [Int : Action<R>]] {
        
        // shifts
        
        let keyAndVals = graph.edges.compactMap{(key : Expr<R.Term, R.NTerm>, vals : [Int : [Int]]) -> (R.Term, [Int : Action<R>])? in
            guard case .term(let t) = key else {return nil}
            let dict = Dictionary(uniqueKeysWithValues: vals.map{start, ends in
                assert(ends.count == 1)
                return (start, Action<R>.shift(ends.first!))
            })
            return (t, dict)
        }
        
        var dict = Dictionary(uniqueKeysWithValues: keyAndVals) as [R.Term? : [Int : Action<R>]]
        
        for start in graph.nodes.indices {
            
            // reductions
            
            if let rule = try graph.nodes[start].reduceRule() {
                for term in Array(R.Term.allCases) as [R.Term?] + [nil] {
                    if dict[term] == nil {
                        dict[term] = [start: .reduce(rule)]
                    }
                    else {
                        if dict[term]?[start] != nil {
                            throw ShiftReduceConflict()
                        }
                        dict[term]?[start] = .reduce(rule)
                    }
                }
            }
            
            // accepts
            
            if graph.nodes[start].graph.nodes.contains(where: {$0.rule == nil && $0.tbd.isEmpty}) {
                if dict[nil] == nil {
                    dict[nil] = [start : .accept]
                }
                else {
                    if dict[nil]?[start] != nil {
                        throw AcceptConflict()
                    }
                    dict[nil]?[start] = .accept
                }
            }
        }
        return dict
    }
    
    var gotoTable : [R.NTerm : [Int : Int]] {
        Dictionary(uniqueKeysWithValues: graph.edges.compactMap{(key : Expr<R.Term, R.NTerm>, vals : [Int : [Int]]) in
            guard case .nonTerm(let nT) = key else {return nil}
            return (nT, vals.mapValues{ints in
                assert(ints.count == 1)
                return ints.first!
            })
        })
    }
    
}

// MARK: LR(0) PARSER

public struct LR0Parser<R : Rules> : Codable, Equatable {
    
    public let actions : [R.Term? : [Int : Action<R>]]
    public let gotos : [R.NTerm : [Int : Int]]
    
    public init(rules: R.Type) throws {
        let table = ItemSetTable(rules: rules)
        self.actions = try table.actionTable()
        self.gotos = table.gotoTable
    }
    
}

public extension LR0Parser {
    
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
            guard let stateBefore = stateStack.peek() else {throw UndefinedState()}
            guard let dict = actions[term] else {throw InvalidChar(char: current ?? "$")}
            guard let action = dict[stateBefore] else {throw UndefinedState()}
            
            switch action {
                
            case .shift(let shift):
                stateStack.push(shift)
                current = iterator.next()
                
            case .reduce(let reduce):
                let rule = reduce.rule
                for _ in rule.rhs {
                    _ = stateStack.pop()
                }
                guard let stateAfter = stateStack.peek() else {throw UndefinedState()}
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
