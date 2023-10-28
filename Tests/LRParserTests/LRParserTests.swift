import XCTest
@testable import LRParser

final class LRParserTests: XCTestCase {
    
    let parser = LR0Parser(rules: MyRules.self)
    
    func testExample() throws {
        let ast = try parser.parse("1+1")
        XCTAssertEqual(ast, .plus(.b(.one), .one))
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

enum MyRules : String, Rules {
    
    case eTimes
    case ePlus
    case eB
    case bZero
    case bOne
    
    static var goal: MyNTerm {.E}
    
    var rule: Rule<MyTerm, MyNTerm, eAST> {
        switch self {
        case .eTimes:
            Rule(.E, expression: /.E, /.times, /.B) {stack in
                guard let eb = stack.pop(),
                      let b = eb.asB,
                      let e = stack.pop() else {
                    throw "Menno"
                }
                stack.push(.times(e, b))
            }
        case .ePlus:
            Rule(.E, expression: /.E, /.plus, /.B) {stack in
                guard let eb = stack.pop(),
                      let b = eb.asB,
                      let e = stack.pop() else {
                    throw "Menno"
                }
                stack.push(.plus(e, b))
            }
        case .eB:
            Rule(.E, expression: /.B) {stack in
                guard let eb = stack.peek(),
                      nil != eb.asB else {
                    throw "Menno"
                }
            }
        case .bZero:
            Rule(.B, expression: /.zero) {stack in
                stack.push(.b(.zero))
            }
        case .bOne:
            Rule(.B, expression: /.one) {stack in
                stack.push(.b(.one))
            }
        }
    }
}
