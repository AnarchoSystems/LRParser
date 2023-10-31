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
        XCTAssertNoThrow(try parser.buildAST("111111"))
    }
    
    func testCLR1() throws {
        let parser = try Parser.CLR1(rules: CLR1Rules.self)
        XCTAssertNoThrow(try parser.buildAST("aabaaab"))
    }
    
    func testLL() {
        XCTAssertNoThrow(try Parser.LR0(rules: NonLL.self))
    }
    
    func testGrammar() throws {
        XCTAssertThrowsError(try Parser.LR0(rules: Grammar.self))
        let parser = try Parser.CLR1(rules: Grammar.self)
        XCTAssertNoThrow(try parser.buildAST("Foo"))
        XCTAssertNoThrow(try parser.buildAST("Bar1345"))
        XCTAssertNoThrow(try parser.buildAST("102345432345432543234565403"))
        XCTAssertThrowsError(try parser.buildAST("5465423564a"))
        XCTAssertThrowsError(try parser.buildAST("0142565432364"))
    }
    
}

// examples from https://en.wikipedia.org/wiki/LR_parser#Additional_example_1+1

enum NonLLTerminal : Character, Terminal {
    case a = "a"
}

enum NonLLNTerminal : String, NonTerminal {
    case A
}

enum NonLL : String, Rules {
    case ouch
    case term
    static var goal : NonLLNTerminal {.A}
    var rule : Rule<NonLLTerminal, NonLLNTerminal> {
        switch self {
        case .ouch:
            Rule(.A, expression: /.A, /.a)
        case .term:
            Rule(.A, expression: /.a)
        }
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

// bigger example

enum Grammar : String, Rules {
    
    typealias Term = Terminals
    typealias NTerm = NonTerminals
    
    static var goal: NonTerminals {
        .intOrId
    }
    
    case aLower, AUpper, bLower, BUpper, cLower, CUpper, dLower, DUpper, eLower, EUpper, fLower, FUpper, gLower, GUpper, hLower, HUpper, iLower, IUpper, jLower, JUpper, kLower, KUpper, lLower, LUpper, mLower, MUpper, nLower, NUpper, oLower, OUpper, pLower, PUpper, qLower, QUpper, rLower, RUpper, sLower, SUpper, tLower, TUpper, uLower, UUpper, vLower, VUpper, wLower, WUpper, xLower, XUpper, yLower, YUpper, zLower, zUpper,
         
         letterUpper,
         letterLower,
         
         oneOneNine,
         twoOneNine,
         threeOneNine,
         fourOneNine,
         fiveOneNine,
         sixOneNine,
         sevenOneNine,
         eightOneNine,
         nineOneNine,
         
         zeroDigit,
         oneNineDigit,
         
         digitDigits,
         digitDigitsDigits,
         
         oneNineDigitsInt,
         zeroInt,
         
         digitDigitOrLetter,
         letterDigitOrLetter,
         
         letterId,
         letterDigitsOrLettersId,
         
         idIntOrId,
         intIntOrId
    
    var rule: Rule<Terminals, NonTerminals> {
        switch self {
        case .aLower:
            Rule(.lowercaseLetter, expression: /.a)
        case .AUpper:
            Rule(.uppercaseLetter, expression: /.A)
        case .bLower:
            Rule(.lowercaseLetter, expression: /.b)
        case .BUpper:
            Rule(.uppercaseLetter, expression: /.B)
        case .cLower:
            Rule(.lowercaseLetter, expression: /.c)
        case .CUpper:
            Rule(.uppercaseLetter, expression: /.C)
        case .dLower:
            Rule(.lowercaseLetter, expression: /.d)
        case .DUpper:
            Rule(.uppercaseLetter, expression: /.D)
        case .eLower:
            Rule(.lowercaseLetter, expression: /.e)
        case .EUpper:
            Rule(.uppercaseLetter, expression: /.E)
        case .fLower:
            Rule(.lowercaseLetter, expression: /.f)
        case .FUpper:
            Rule(.uppercaseLetter, expression: /.F)
        case .gLower:
            Rule(.lowercaseLetter, expression: /.g)
        case .GUpper:
            Rule(.uppercaseLetter, expression: /.G)
        case .hLower:
            Rule(.lowercaseLetter, expression: /.h)
        case .HUpper:
            Rule(.uppercaseLetter, expression: /.H)
        case .iLower:
            Rule(.lowercaseLetter, expression: /.i)
        case .IUpper:
            Rule(.uppercaseLetter, expression: /.I)
        case .jLower:
            Rule(.lowercaseLetter, expression: /.j)
        case .JUpper:
            Rule(.uppercaseLetter, expression: /.J)
        case .kLower:
            Rule(.lowercaseLetter, expression: /.k)
        case .KUpper:
            Rule(.uppercaseLetter, expression: /.K)
        case .lLower:
            Rule(.lowercaseLetter, expression: /.l)
        case .LUpper:
            Rule(.uppercaseLetter, expression: /.L)
        case .mLower:
            Rule(.lowercaseLetter, expression: /.m)
        case .MUpper:
            Rule(.uppercaseLetter, expression: /.M)
        case .nLower:
            Rule(.lowercaseLetter, expression: /.n)
        case .NUpper:
            Rule(.uppercaseLetter, expression: /.N)
        case .oLower:
            Rule(.lowercaseLetter, expression: /.o)
        case .OUpper:
            Rule(.uppercaseLetter, expression: /.O)
        case .pLower:
            Rule(.lowercaseLetter, expression: /.p)
        case .PUpper:
            Rule(.uppercaseLetter, expression: /.P)
        case .qLower:
            Rule(.lowercaseLetter, expression: /.q)
        case .QUpper:
            Rule(.uppercaseLetter, expression: /.Q)
        case .rLower:
            Rule(.lowercaseLetter, expression: /.r)
        case .RUpper:
            Rule(.uppercaseLetter, expression: /.R)
        case .sLower:
            Rule(.lowercaseLetter, expression: /.s)
        case .SUpper:
            Rule(.uppercaseLetter, expression: /.S)
        case .tLower:
            Rule(.lowercaseLetter, expression: /.t)
        case .TUpper:
            Rule(.uppercaseLetter, expression: /.T)
        case .uLower:
            Rule(.lowercaseLetter, expression: /.u)
        case .UUpper:
            Rule(.uppercaseLetter, expression: /.U)
        case .vLower:
            Rule(.lowercaseLetter, expression: /.v)
        case .VUpper:
            Rule(.uppercaseLetter, expression: /.V)
        case .wLower:
            Rule(.lowercaseLetter, expression: /.w)
        case .WUpper:
            Rule(.uppercaseLetter, expression: /.W)
        case .xLower:
            Rule(.lowercaseLetter, expression: /.x)
        case .XUpper:
            Rule(.uppercaseLetter, expression: /.X)
        case .yLower:
            Rule(.lowercaseLetter, expression: /.y)
        case .YUpper:
            Rule(.uppercaseLetter, expression: /.Y)
        case .zLower:
            Rule(.lowercaseLetter, expression: /.z)
        case .zUpper:
            Rule(.uppercaseLetter, expression: /.Z)
            
            
        case .letterUpper:
            Rule(.letter, expression: /.uppercaseLetter)
        case .letterLower:
            Rule(.letter, expression: /.lowercaseLetter)
            
            
        case .oneOneNine:
            Rule(.oneNine, expression: /.one)
        case .twoOneNine:
            Rule(.oneNine, expression: /.two)
        case .threeOneNine:
            Rule(.oneNine, expression: /.three)
        case .fourOneNine:
            Rule(.oneNine, expression: /.four)
        case .fiveOneNine:
            Rule(.oneNine, expression: /.five)
        case .sixOneNine:
            Rule(.oneNine, expression: /.six)
        case .sevenOneNine:
            Rule(.oneNine, expression: /.seven)
        case .eightOneNine:
            Rule(.oneNine, expression: /.eight)
        case .nineOneNine:
            Rule(.oneNine, expression: /.nine)
            
            
        case .zeroDigit:
            Rule(.digit, expression: /.zero)
        case .oneNineDigit:
            Rule(.digit, expression: /.oneNine)
            
            
        case .digitDigits:
            Rule(.digits, expression: /.digit)
        case .digitDigitsDigits:
            Rule(.digits, expression: /.digit, /.digits)
            
            
        case .oneNineDigitsInt:
            Rule(.integer, expression: /.oneNine, /.digits)
        case .zeroInt:
            Rule(.integer, expression: /.zero)
            
            
        case .digitDigitOrLetter:
            Rule(.digitOrLetter, expression: /.digit)
        case .letterDigitOrLetter:
            Rule(.digitOrLetter, expression: /.letter)
            
            
        case .letterId:
            Rule(.identifier, expression: /.letter)
        case .letterDigitsOrLettersId:
            Rule(.identifier, expression: /.identifier, /.digitOrLetter)
            
        case .idIntOrId:
            Rule(.intOrId, expression: /.identifier)
            
        case .intIntOrId:
            Rule(.intOrId, expression: /.integer)
        }
    }
    
    
}

enum Terminals : Character, Terminal {
    case a = "a"
    case A = "A"
    case b = "b"
    case B = "B"
    case c = "c"
    case C = "C"
    case d = "d"
    case D = "D"
    case e = "e"
    case E = "E"
    case f = "f"
    case F = "F"
    case g = "g"
    case G = "G"
    case h = "h"
    case H = "H"
    case i = "i"
    case I = "I"
    case j = "j"
    case J = "J"
    case k = "k"
    case K = "K"
    case l = "l"
    case L = "L"
    case m = "m"
    case M = "M"
    case n = "n"
    case N = "N"
    case o = "o"
    case O = "O"
    case p = "p"
    case P = "P"
    case q = "q"
    case Q = "Q"
    case r = "r"
    case R = "R"
    case s = "s"
    case S = "S"
    case t = "t"
    case T = "T"
    case u = "u"
    case U = "U"
    case v = "v"
    case V = "V"
    case w = "w"
    case W = "W"
    case x = "x"
    case X = "X"
    case y = "y"
    case Y = "Y"
    case z = "z"
    case Z = "Z"
    
    case zero = "0"
    case one = "1"
    case two = "2"
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
}

enum NonTerminals : String, NonTerminal {
    case uppercaseLetter, lowercaseLetter, letter, oneNine, digit, digits, integer, digitOrLetter, digitsOrLetters, identifier, intOrId
}
