import XCTest
import LRParser

final class LRParserTests: XCTestCase {
    
    func testOnePlusOneLR0() throws {
        let parser = try Parser.LR0(rules: MyRules.self)
        let ast = try parser.parse("1+1")
        XCTAssertEqual(ast, .plus(.b(.one), .one))
    }
    
    func testDecodeEncodeEqual() throws {
        let parser = try Parser.LR0(rules: MyRules.self)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(parser)
        print(String(data: data, encoding: .utf8)!)
        let newParser = try JSONDecoder().decode(Parser<MyRules>.self, from: data)
        XCTAssertEqual(parser, newParser)
    }
    
    func testNonLR() {
        XCTAssertThrowsError(try Parser.LR0(rules: NonLR0.self))
        XCTAssertNoThrow(try Parser.CLR1(rules: NonLR0.self))
    }
    
    func testOnes() throws {
        let parser = try Parser.CLR1(rules: NonLR0.self)
        XCTAssertNoThrow(try parser.buildStack("111111"))
    }
    
    func testCLR1() throws {
        let parser = try Parser.CLR1(rules: CLR1Rules.self)
        XCTAssertNoThrow(try parser.buildStack("aabaaab"))
    }
    
}

// examples from https://en.wikipedia.org/wiki/LR_parser#Additional_example_1+1

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

// example from https://www.youtube.com/watch?v=0rUJvQ3-GwI&t=1873s

enum CLR1Term : Character, Terminal {
    case a = "a"
    case b = "b"
}

enum CLR1NTerm : String, NonTerminal {
    case S
    case A
}

enum CLR1Rules : String, Rules {
    case SAA
    case AaA
    case Ab
    static var goal : CLR1NTerm {
        .S
    }
    var rule: Rule<CLR1Term, CLR1NTerm> {
        switch self {
        case .SAA:
            Rule(.S, expression: /.A, /.A)
        case .AaA:
            Rule(.A, expression: /.a, /.A)
        case .Ab:
            Rule(.A, expression: /.b)
        }
    }
}
