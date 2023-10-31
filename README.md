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
        XCTAssertNoThrow(try parser.parse("111111"))
    }
    
```

One can also specify AST transformations in the rules.


# Further Reading

[Wiki](https://en.wikipedia.org/wiki/LR_parser#Additional_example_1+1)

[Geeks for Geeks](https://www.youtube.com/live/SyTXugfG9nw?si=sQRh1n5SD_LXWbSh)

[Geeks for Geeks](https://www.youtube.com/live/ZqRQaCeKs2Y?si=SqQe7Y6ozduaAsfY)

[Geeks for Geeks](https://www.youtube.com/live/0rUJvQ3-GwI?si=o-zoad_hNzWdrq92)
