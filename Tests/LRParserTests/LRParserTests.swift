import XCTest
@testable import LRParser

final class LRParserTests: XCTestCase {
    
    func testOnePlusOneLR0() throws {
        let parser = LR0Parser(rules: MyRules.self)
        let ast = try parser.parse("1+1")
        XCTAssertEqual(ast, .plus(.b(.one), .one))
    }
    
    func testDecodeEncodeEqual() throws {
        let parser = LR0Parser(rules: MyRules.self)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(parser)
        print(String(data: data, encoding: .utf8)!)
        let newParser = try JSONDecoder().decode(LR0Parser<MyRules>.self, from: data)
        XCTAssertEqual(parser, newParser)
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
                    throw "Menno"
                }
                stack.push(.times(e, b))
            }
        case .ePlus:
            Construction(.E, expression: /.E, /.plus, /.B) {stack in
                guard let eb = stack.pop(),
                      let b = eb.asB,
                      let e = stack.pop() else {
                    throw "Menno"
                }
                stack.push(.plus(e, b))
            }
        case .eB:
            Construction(.E, expression: /.B) {stack in
                guard let eb = stack.peek(),
                      nil != eb.asB else {
                    throw "Menno"
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
