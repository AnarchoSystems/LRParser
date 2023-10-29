//
//  LR0Parser.swift
//
//
//  Created by Markus Kasperczyk on 28.10.23.
//

fileprivate struct Item<R : Rules> : Hashable {
    let rule : R?
    private let all : [Expr<R.Term, R.NTerm>]
    private var ptr = 0
    init(rule: R?, _ all: [Expr<R.Term, R.NTerm>]) {
        self.rule = rule
        self.all = all
        self.ptr = 0
    }
    mutating func advance() {
        guard all.indices.contains(ptr) else {return}
        ptr+=1
    }
    var tbd : some Collection<Expr<R.Term, R.NTerm>> {
        all[ptr...]
    }
}

public struct ReduceReduceConflict<R : Rules> : Error {
    let matching : [R]
}

fileprivate struct ItemSet<R : Rules> : Hashable {
    var rep : [Item<R>] = []
    
    private mutating func augment(accountedFor : inout Set<R.NTerm>, toBeAccountedFor: inout Set<R.NTerm>) {
        var news : [Item<R>] = []
        for nT in toBeAccountedFor {
            for rule in R.allCases {
                let rl = rule.rule
                if rl.lhs != nT {continue}
                news.append(Item(rule: rule, rl.rhs))
            }
        }
        rep.append(contentsOf: news)
        accountedFor.formUnion(toBeAccountedFor)
        toBeAccountedFor = []
        for item in news {
            guard let next = item.tbd.first, case .nonTerm(let nT) = next, !accountedFor.contains(nT) else {
                continue
            }
            toBeAccountedFor.insert(nT)
        }
    }
    
    init() {
        self = .init([.init(rule: nil, [.nonTerm(R.goal)])])
    }
    
    init(_ items: [Item<R>]) {
        rep = items
        var accountedFor : Set<R.NTerm> = []
        var toBeAccountedFor : Set<R.NTerm> = []
        for item in items {
            guard let next = item.tbd.first else {continue}
            switch next {
            case .term:
                return
            case .nonTerm(let nT):
                toBeAccountedFor.insert(nT)
            }
        }
        while !toBeAccountedFor.isEmpty {
            augment(accountedFor: &accountedFor, toBeAccountedFor: &toBeAccountedFor)
        }
    }
    
    func nexts(_ expr: Expr<R.Term, R.NTerm>) -> [Expr<R.Term, R.NTerm> : ItemSet<R>] {
        var items = rep.compactMap{item in item.tbd.first.flatMap{$0 == expr ? ($0, item) : nil}}
        for idx in items.indices {
            items[idx].1.advance()
        }
        return Dictionary(items.map{($0, [$1])}, uniquingKeysWith: +).mapValues{ItemSet($0)}
    }
    
    func reduceRule() throws -> R? {
        let results : [R] = rep.lazy.filter(\.tbd.isEmpty).compactMap(\.rule)
        if results.count > 1 {
            throw ReduceReduceConflict(matching: results)
        }
        return results.first
    }
    
}

public enum LR0Action<R : Rules> : Codable, Equatable {
    case shift(Int)
    case reduce(R)
    case accept
    
    enum RawType : String, Codable {
        case shift, reduce, accept
    }
    struct TypeCoder : Codable {
        let type : RawType
    }
    enum _Shift : String, Codable {case shift}
    struct Shift : Codable {
        let type : _Shift
        let newState : Int
    }
    enum _Reduce : String, Codable {case reduce}
    struct Reduce : Codable {
        let type : _Reduce
        let rule : R
    }
    
    public init(from decoder: Decoder) throws {
        let type = try TypeCoder(from: decoder)
        switch type.type {
        case .shift:
            let this = try Shift(from: decoder)
            self = .shift(this.newState)
        case .reduce:
            let this = try Reduce(from: decoder)
            self = .reduce(this.rule)
        case .accept:
            self = .accept
        }
    }
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .shift(let newState):
            try Shift(type: .shift, newState: newState).encode(to: encoder)
        case .reduce(let rule):
            try Reduce(type: .reduce, rule: rule).encode(to: encoder)
        case .accept:
            try TypeCoder(type: .accept).encode(to: encoder)
        }
    }
}

public struct ShiftReduceConflict : Error {}
public struct AcceptConflict : Error {}

fileprivate struct ItemSetTable<R : Rules> {
    
    struct _Edge : Hashable {
        let start : ItemSet<R>
        let symb : Expr<R.Term, R.NTerm>
        let end : ItemSet<R>
    }
    
    var states : [ItemSet<R>] = []
    var edges : [Expr<R.Term, R.NTerm> : [Int : Int]] = [:]
    
    init(rules: R.Type) {
        states.append(.init())
        var newStates = states
        var _states = Set(states)
        var _edges = Set<_Edge>()
        while true {
            var newNewStates = [ItemSet<R>]()
            var didSomething = false
            for state in newStates {
                for expr in R.Term.allCases.map(Expr.term) + R.NTerm.allCases.map(Expr.nonTerm) {
                    for (symb, end) in state.nexts(expr) {
                        if !_states.contains(end) {
                            didSomething = true
                            newNewStates.append(end)
                            _states.insert(end)
                        }
                        let edge = _Edge(start: state, symb: symb, end: end)
                        if !_edges.contains(edge) {
                            didSomething = true
                            _edges.insert(edge)
                        }
                    }
                }
            }
            newStates = newNewStates
            states.append(contentsOf: newStates)
            if (!didSomething)
            {
                break
            }
        }
        for _edge in _edges {
            let start = states.firstIndex(of: _edge.start)!
            let end = states.firstIndex(of: _edge.end)!
            if edges[_edge.symb] == nil {
                edges[_edge.symb] = [start: end]
            }
            else {
                edges[_edge.symb]?[start] = end
            }
        }
    }
    
    func actionTable() throws -> [R.Term? : [Int : LR0Action<R>]] {
        let keyAndVals = edges.compactMap{(key : Expr<R.Term, R.NTerm>, val : [Int : Int]) -> (R.Term, [Int : LR0Action<R>])? in
            guard case .term(let t) = key else {return nil}
            let dict = Dictionary(uniqueKeysWithValues: val.map{start, end in
                (start, LR0Action<R>.shift(end))
            })
            return (t, dict)
        }
        var dict = Dictionary(uniqueKeysWithValues: keyAndVals) as [R.Term? : [Int : LR0Action<R>]]
        for start in states.indices {
            if let rule = try states[start].reduceRule() {
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
            if states[start].rep.contains(where: {$0.rule == nil && $0.tbd.isEmpty}) {
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
        Dictionary(uniqueKeysWithValues: edges.compactMap{key, val in
            guard case .nonTerm(let nT) = key else {return nil}
            return (nT, val)
        })
    }
    
}

public struct UndefinedState : Error {}
public struct InvalidChar : Error {
    public let char : Character
}
public struct NoGoTo<NT> : Error {
    public let nonTerm : NT
    public let state : Int
}



public struct LR0Parser<R : Rules> : Codable, Equatable {
    
    public let actions : [R.Term? : [Int : LR0Action<R>]]
    public let gotos : [R.NTerm : [Int : Int]]
    
    public init(rules: R.Type) throws {
        let table = ItemSetTable(rules: rules)
        self.actions = try table.actionTable()
        self.gotos = table.gotoTable
    }
    
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
