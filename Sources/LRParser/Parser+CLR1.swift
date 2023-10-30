//
//  Parser+CLR1.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

// MARK: FIRST

fileprivate extension Rules {
    static func first(_ expr: Expr<Term, NTerm>) -> Set<Term?> {
        switch expr {
        case .term(let term):
            return [term]
        case .nonTerm(let nT):
            var results : Set<Term?> = []
            var nTermsLookedAt : Set<NTerm> = []
            var nTermsToLookAt : Set<NTerm> = [nT]
            while !nTermsToLookAt.isEmpty {
                var newNTermsToLookAt : Set<NTerm> = []
                for nT in nTermsToLookAt {
                    for rule in allCases.lazy.map(\.rule) where rule.lhs == nT {
                        guard let next = rule.rhs.first else {
                            results.insert(nil)
                            continue
                        }
                        switch next {
                        case .term(let term):
                            results.insert(term)
                        case .nonTerm(let newNT):
                            if !nTermsLookedAt.contains(newNT) {
                                newNTermsToLookAt.insert(newNT)
                            }
                        }
                    }
                }
                nTermsLookedAt.formUnion(nTermsToLookAt)
                nTermsToLookAt = newNTermsToLookAt
            }
            return results
        }
    }
}

// MARK: CLR(1) ITEMS

fileprivate struct Item<R : Rules> : Node {
    
    let rule : R?
    let all : [Expr<R.Term, R.NTerm>]
    let lookAheads : Set<R.Term?>
    let ptr : Int
    let firsts : [Expr<R.Term, R.NTerm> : Set<R.Term?>]
    
    func canReach () -> [R.NTerm : [Item<R>]] {
        guard let next = tbd.first, case .nonTerm(let nT) = next else {
            return [:]
        }
        var lookAheads = self.lookAheads
        if let la = tbd.dropFirst().first {
            lookAheads = firsts[la]!
        }
        return [nT : R.allCases.compactMap {rule in
            let ru = rule.rule
            guard ru.lhs == nT else {return nil}
            return Item(rule: rule, all: ru.rhs, lookAheads: lookAheads, ptr: 0, firsts: firsts)
        }]
    }
    
}

// MARK: CLR(1) ITEM SETS

fileprivate struct ItemSet<R : Rules> {
    
    let graph : ClosedGraph<Item<R>>
    
}

// MARK: HELPERS

extension Item {
    
    func tryAdvance(_ expr: Expr<R.Term, R.NTerm>) -> Item<R>? {
        tbd.first.flatMap{$0 == expr ? Item(rule: rule, all: all, lookAheads: lookAheads, ptr: ptr + 1, firsts: firsts) : nil}
    }
    var tbd : some Collection<Expr<R.Term, R.NTerm>> {
        all[ptr...]
    }
    
}

extension ItemSet : Node {
    
    func canReach() throws -> [Expr<R.Term, R.NTerm> : [ItemSet<R>]] {
        let exprs = Set(graph.nodes.compactMap(\.tbd.first))
        let terms = Set(exprs.compactMap{expr -> R.Term? in
            guard case .term(let t) = expr else {return nil}
            return t
        }) as Set<R.Term?>
        let rules = try reduceRules()
        if !terms.intersection(rules.keys).isEmpty {
            throw ShiftReduceConflict()
        }
        if exprs.isEmpty {
            return [:]
        }
        return try Dictionary(uniqueKeysWithValues: exprs.map{expr in
            try (expr, [ItemSet(graph: ClosedGraph(seeds: graph.nodes.compactMap{$0.tryAdvance(expr)}))])
        })
    }
}

// MARK: CLR(1) GRAPH

fileprivate struct ItemSetTable<R : Rules> {
    
    let graph : ClosedGraph<ItemSet<R>>
    
    init(rules: R.Type) throws {
        let augmentedRule = Item<R>(rule: nil, all: [.nonTerm(R.goal)],
                                    lookAheads: [nil],
                                    ptr: 0,
                                    firsts: Dictionary(uniqueKeysWithValues: R.Term.allCases.map(Expr.term).map{($0, R.first($0))} + R.NTerm.allCases.map(Expr.nonTerm).map{($0, R.first($0))}))
        let itemSetGraph = try ClosedGraph(seeds: [augmentedRule])
        graph = try ClosedGraph(seeds: [ItemSet(graph: itemSetGraph)])
    }
    
}

// MARK: HELPER

extension ItemSet {
    
    func reduceRules() throws -> [R.Term? : R] {
        let results = graph.nodes.lazy.filter(\.tbd.isEmpty).flatMap{rule in rule.rule.map{val in rule.lookAheads.map{key in (key, val)}} ?? []}
        return try Dictionary(results) {val1, val2 in
            if val1 == val2 {
                return val1
            }
            throw ReduceReduceConflict(matching: [val1, val2])
        }
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
            
            for (term, rule) in try graph.nodes[start].reduceRules() {
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

// MARK: CLR(1) PARSER

public extension Parser {
    
    static func CLR1(rules: R.Type) throws -> Self {
        let table = try ItemSetTable(rules: rules)
        return Parser(actions: try table.actionTable(),
                      gotos: table.gotoTable)
    }
    
}
