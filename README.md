# LRParser

This library allows you to specify grammars like so:

```Swift

enum NonLR0Term : Character, Terminal {
    case one = "1"
}

enum NonLR0NTerm : String, NonTerminal {
    case E
}

enum NonLR0 : String, Rules {
    
    case eIsOne
    case oneE
    
    static var goal : NonLR0NTerm {.E}
    
    var rule: Rule<NonLR0Term, NonLR0NTerm> {
        switch self {
        case .eIsOne:
            return Rule(.E, expression: /.one)
        case .oneE:
            return Rule(.E, expression: /.one, /.E)
        }
    }
    
}

// Test


    func testNonLR() {
        XCTAssertThrowsError(try Parser.LR0(rules: NonLR0.self))
        XCTAssertNoThrow(try Parser.CLR1(rules: NonLR0.self))
    }
    
    func testOnes() throws {
        let parser = try Parser.CLR1(rules: NonLR0.self)
        XCTAssertNoThrow(try parser.buildStack("111111"))
    }
    
```

One can also immediately specify what to do with the parser output *while* defining the grammar:

```Swift

enum MyTerm : Character, Terminal {
    case zero = "0"
    case one = "1"
    case plus = "+"
    case times = "*"
}

enum MyNTerm : String, NonTerminal {
    case E
    case B
}

extension String : Error {}

enum MyRules : String, Constructions {
    
    case eTimes
    case ePlus
    case eB
    case bZero
    case bOne
    
    static var goal: MyNTerm {.E}
    
    var construction: Construction<MyTerm, MyNTerm, eAST> {
        switch self {
        case .eTimes:
            Construction(.E, expression: /.E, /.times, /.B) {stack in
                guard let eb = stack.pop(),
                      let b = eb.asB,
                      let e = stack.pop() else {
                    throw "Ouch"
                }
                stack.push(.times(e, b))
            }
        case .ePlus:
            Construction(.E, expression: /.E, /.plus, /.B) {stack in
                guard let eb = stack.pop(),
                      let b = eb.asB,
                      let e = stack.pop() else {
                    throw "Ouch"
                }
                stack.push(.plus(e, b))
            }
        case .eB:
            Construction(.E, expression: /.B) {stack in
                guard let eb = stack.peek(),
                      nil != eb.asB else {
                    throw "Ouch"
                }
            }
        case .bZero:
            Construction(.B, expression: /.zero) {stack in
                stack.push(.b(.zero))
            }
        case .bOne:
            Construction(.B, expression: /.one) {stack in
                stack.push(.b(.one))
            }
        }
    }
}

enum bAST : Equatable {
    case zero
    case one
}

indirect enum eAST : Equatable {
    case b(bAST)
    case plus(Self, bAST)
    case times(Self, bAST)
    var asB : bAST? {
        guard case .b(let b) = self else {
            return nil
        }
        return b
    }
}

// Test


    func testOnePlusOneLR0() throws {
        let parser = try Parser.LR0(rules: MyRules.self)
        let ast = try parser.parse("1+1")
        XCTAssertEqual(ast, .plus(.b(.one), .one))
    }
    
```

# Further Reading

[Wiki](https://en.wikipedia.org/wiki/LR_parser#Additional_example_1+1)

[Geeks for Geeks](https://www.youtube.com/live/SyTXugfG9nw?si=sQRh1n5SD_LXWbSh)

[Geeks for Geeks](https://www.youtube.com/live/ZqRQaCeKs2Y?si=SqQe7Y6ozduaAsfY)

[Geeks for Geeks](https://www.youtube.com/live/0rUJvQ3-GwI?si=o-zoad_hNzWdrq92)
