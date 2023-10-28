

public protocol Terminal : RawRepresentable, CaseIterable, Codable, Hashable where RawValue == Character {}

public protocol NonTerminal : RawRepresentable, CaseIterable, Codable, Hashable where RawValue == String {}

public protocol Rules : RawRepresentable, CaseIterable, Codable, Hashable where RawValue == String {
    associatedtype Term : Terminal
    associatedtype NTerm : NonTerminal
    associatedtype Output
    static var goal : NTerm {get}
    var rule : Rule<Term, NTerm, Output> {get}
}

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

public struct Rule<T : Terminal, NT : NonTerminal, Output> {
    public let lhs : NT
    public let rhs : [Expr<T, NT>]
    public let parse : (inout Stack<Output>) throws -> Void
    public init(_ lhs: NT, expression rhs: Expr<T, NT>..., parse: @escaping (inout Stack<Output>) throws -> Void) {
        self.lhs = lhs
        self.rhs = rhs
        self.parse = parse
    }
}

public enum Expr<T : Hashable, NT : Hashable> : Hashable {
    case term(T)
    case nonTerm(NT)
}

prefix operator /

public prefix func /<T, NT>(_ t: T) -> Expr<T, NT> {
    .term(t)
}

public prefix func /<T, NT>(_ nt: NT) -> Expr<T, NT> {
    .nonTerm(nt)
}

struct Item<R : Rules> : Hashable {
    let rule : R?
    var recognized : [Expr<R.Term, R.NTerm>]
    var tbd : [Expr<R.Term, R.NTerm>]
    mutating func advance() {
        guard !tbd.isEmpty else {return}
        recognized.append(tbd.removeFirst())
    }
}

struct ItemSet<R : Rules> : Hashable {
    var rep : [Item<R>] = []
    
    private mutating func augment(accountedFor : inout Set<R.NTerm>, toBeAccountedFor: inout Set<R.NTerm>) {
        var news : [Item<R>] = []
        for nT in toBeAccountedFor {
            for rule in R.allCases {
                let rl = rule.rule
                if rl.lhs != nT {continue}
                news.append(Item(rule: rule, recognized: [], tbd: rl.rhs))
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
        self = .init([.init(rule: nil, recognized: [], tbd: [.nonTerm(R.goal)])])
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
    
    func nexts() -> [Expr<R.Term, R.NTerm> : ItemSet<R>] {
        var items = rep.compactMap{item in item.tbd.first.map{($0, item)}}
        for idx in items.indices {
            items[idx].1.advance()
        }
        return Dictionary(items.map{($0, [$1])}, uniquingKeysWith: +).mapValues{ItemSet($0)}
    }
    
    var reduceRule : R? {
        rep.first(where: {$0.tbd.isEmpty})?.rule
    }
    
}

public enum Action<R : Rules> : Codable {
    case shift(Int)
    case reduce(R)
    case accept
}

struct ItemSetTable<R : Rules> {
    
    struct _Edge : Hashable {
        let start : ItemSet<R>
        let symb : Expr<R.Term, R.NTerm>
        let end : ItemSet<R>
    }
    
    struct Tail : Hashable {
        let symb : Expr<R.Term, R.NTerm>
        let end : Int
    }
    
    var states : [ItemSet<R>] = []
    var edges : [Expr<R.Term, R.NTerm> : [Int : Int]] = [:]
    
    init(rules: R.Type) {
        states.append(.init())
        var _states = Set(states)
        var _edges = Set<_Edge>()
        while true {
            var didSomething = false
            for state in states {
                for (symb, end) in state.nexts() {
                    if !_states.contains(end) {
                        didSomething = true
                        states.append(end)
                        _states.insert(end)
                    }
                    let edge = _Edge(start: state, symb: symb, end: end)
                    if !_edges.contains(edge) {
                        didSomething = true
                        _edges.insert(edge)
                    }
                }
            }
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
    
    var actionTable : [R.Term? : [Int : Action<R>]] {
        let keyAndVals = edges.compactMap{(key : Expr<R.Term, R.NTerm>, val : [Int : Int]) -> (R.Term, [Int : Action<R>])? in
            guard case .term(let t) = key else {return nil}
            let dict = Dictionary(uniqueKeysWithValues: val.map{start, end in
                (start, states[start].reduceRule.map{Action.reduce($0)} ?? .shift(end))
            })
            return (t, dict)
        }
        var dict = Dictionary(uniqueKeysWithValues: keyAndVals) as [R.Term? : [Int : Action<R>]]
        for start in states.indices {
            if let rule = states[start].reduceRule {
                for term in Array(R.Term.allCases) as [R.Term?] + [nil] {
                    if dict[term] == nil {
                        dict[term] = [start: .reduce(rule)]
                    }
                    else {
                        dict[term]?[start] = .reduce(rule)
                    }
                }
            }
            if states[start].rep.contains(where: {$0.rule == nil}) {
                if dict[nil] == nil {
                    dict[nil] = [start : .accept]
                }
                else {
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



public struct LR0Parser<R : Rules> : Codable {
    
    public let actions : [R.Term? : [Int : Action<R>]]
    public let gotos : [R.NTerm : [Int : Int]]
    
    public init(rules: R.Type) {
        let table = ItemSetTable(rules: rules)
        self.actions = table.actionTable
        self.gotos = table.gotoTable
    }
    
    func parse(_ stream: String) throws -> R.Output {
        
        var iterator = stream.makeIterator()
        var current = iterator.next()
        
        var stateStack = Stack<Int>()
        stateStack.push(0)
        var outStack = Stack<R.Output>()
        
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
                try rule.parse(&outStack)
                guard let nextState = gotos[rule.lhs]?[stateAfter] else {throw NoGoTo(nonTerm: rule.lhs, state: stateAfter)}
                stateStack.push(nextState)
                
            case .accept:
                break loop
            }
            
        }
        return outStack.pop()!
    }
    
}
