//
//  Parser+LR0.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

// MARK: LR(0) ITEMS

fileprivate struct Item<R : Rules> : Node {
    
    let rule : R?
    let all : [Expr<R>]
    let ptr : Int
    
    func canReach (lookup: inout Void) -> [R.NTerm : [Item<R>]] {
        guard let next = tbd.first, case .nonTerm(let nT) = next else {
            return [:]
        }
        return [nT : R.allCases.compactMap {(rule) -> Item<R>? in
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
    
    func tryAdvance(_ expr: Expr<R>) -> Item<R>? {
        tbd.first.flatMap{$0 == expr ? Item(rule: rule, all: all, ptr: ptr + 1) : nil}
    }
    var tbd : some Collection<Expr<R>> {
        all[ptr...]
    }
    
}

extension ItemSet : Node {
    
    func canReach(lookup: inout Void) throws -> [Expr<R> : [ItemSet<R>]] {
        let exprs = Set(graph.nodes.compactMap(\.tbd.first))
        if exprs.isEmpty {
            _ = try reduceRule()
            return [:]
        }
        guard try reduceRule() == nil else {throw ShiftReduceConflict()}
        return try Dictionary(uniqueKeysWithValues: exprs.map{expr in
            try (expr, [ItemSet(graph: ClosedGraph(seeds: graph.nodes.compactMap{$0.tryAdvance(expr)}, lookup: &lookup))])
        })
    }
}

// MARK: LR(0) GRAPH

fileprivate struct ItemSetTable<R : Rules> {
    
    let graph : ClosedGraph<ItemSet<R>>
    
    init(rules: R.Type) throws {
        let augmentedRule = Item<R>(rule: nil, all: [.nonTerm(R.goal)], ptr: 0)
        var void: () = ()
        let itemSetGraph = try ClosedGraph(seeds: [augmentedRule], lookup: &void)
        graph = try ClosedGraph(seeds: [ItemSet(graph: itemSetGraph)], lookup: &void)
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
        
        let keyAndVals = graph.edges.compactMap{(key : Expr<R>, vals : [Int : [Int]]) -> (R.Term, [Int : Action<R>])? in
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
        Dictionary(uniqueKeysWithValues: graph.edges.compactMap{(key : Expr<R>, vals : [Int : [Int]]) in
            guard case .nonTerm(let nT) = key else {return nil}
            return (nT, vals.mapValues{ints in
                assert(ints.count == 1)
                return ints.first!
            })
        })
    }
    
}

// MARK: LR(0) PARSER

public extension Parser {
    
    static func LR0(rules: R.Type) throws -> Self {
        let table = try ItemSetTable(rules: rules)
        return Parser(actions: try table.actionTable(),
                      gotos: table.gotoTable)
    }
    
}
