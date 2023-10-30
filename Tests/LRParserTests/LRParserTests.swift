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
    
    func testLL() {
        XCTAssertNoThrow(try Parser.LR0(rules: NonLL.self))
    }
    
    func testGrammar() throws {
        XCTAssertThrowsError(try Parser.LR0(rules: Grammar.self))
        let parser = try Parser.CLR1(rules: Grammar.self)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(parser)
        print(String(data: data, encoding: .utf8)!)
        XCTAssertNoThrow(try parser.buildStack("Foo"))
        XCTAssertNoThrow(try parser.buildStack("Bar1345"))
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

enum Grammar : String, Constructions {
    
    typealias Term = Terminals
    typealias NTerm = NonTerminals
    typealias Output = IdOrInt
    
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
         idDigitOrLetterId,
         
         idIntOrId,
         intIntOrId
    
    var construction: Construction<Terminals, NonTerminals, Output> {
        switch self {
        case .aLower:
            Construction(.lowercaseLetter, expression: /.a) {stack in stack.push(.id("a"))}
        case .AUpper:
            Construction(.uppercaseLetter, expression: /.A) {stack in stack.push(.id("A"))}
        case .bLower:
            Construction(.lowercaseLetter, expression: /.b) {stack in stack.push(.id("b"))}
        case .BUpper:
            Construction(.uppercaseLetter, expression: /.B) {stack in stack.push(.id("B"))}
        case .cLower:
            Construction(.lowercaseLetter, expression: /.c) {stack in stack.push(.id("c"))}
        case .CUpper:
            Construction(.uppercaseLetter, expression: /.C) {stack in stack.push(.id("C"))}
        case .dLower:
            Construction(.lowercaseLetter, expression: /.d) {stack in stack.push(.id("d"))}
        case .DUpper:
            Construction(.uppercaseLetter, expression: /.D) {stack in stack.push(.id("D"))}
        case .eLower:
            Construction(.lowercaseLetter, expression: /.e) {stack in stack.push(.id("e"))}
        case .EUpper:
            Construction(.uppercaseLetter, expression: /.E) {stack in stack.push(.id("E"))}
        case .fLower:
            Construction(.lowercaseLetter, expression: /.f) {stack in stack.push(.id("f"))}
        case .FUpper:
            Construction(.uppercaseLetter, expression: /.F) {stack in stack.push(.id("F"))}
        case .gLower:
            Construction(.lowercaseLetter, expression: /.g) {stack in stack.push(.id("g"))}
        case .GUpper:
            Construction(.uppercaseLetter, expression: /.G) {stack in stack.push(.id("G"))}
        case .hLower:
            Construction(.lowercaseLetter, expression: /.h) {stack in stack.push(.id("h"))}
        case .HUpper:
            Construction(.uppercaseLetter, expression: /.H) {stack in stack.push(.id("H"))}
        case .iLower:
            Construction(.lowercaseLetter, expression: /.i) {stack in stack.push(.id("i"))}
        case .IUpper:
            Construction(.uppercaseLetter, expression: /.I) {stack in stack.push(.id("I"))}
        case .jLower:
            Construction(.lowercaseLetter, expression: /.j) {stack in stack.push(.id("j"))}
        case .JUpper:
            Construction(.uppercaseLetter, expression: /.J) {stack in stack.push(.id("J"))}
        case .kLower:
            Construction(.lowercaseLetter, expression: /.k) {stack in stack.push(.id("k"))}
        case .KUpper:
            Construction(.uppercaseLetter, expression: /.K) {stack in stack.push(.id("K"))}
        case .lLower:
            Construction(.lowercaseLetter, expression: /.l) {stack in stack.push(.id("l"))}
        case .LUpper:
            Construction(.uppercaseLetter, expression: /.L) {stack in stack.push(.id("L"))}
        case .mLower:
            Construction(.lowercaseLetter, expression: /.m) {stack in stack.push(.id("m"))}
        case .MUpper:
            Construction(.uppercaseLetter, expression: /.M) {stack in stack.push(.id("M"))}
        case .nLower:
            Construction(.lowercaseLetter, expression: /.n) {stack in stack.push(.id("n"))}
        case .NUpper:
            Construction(.uppercaseLetter, expression: /.N) {stack in stack.push(.id("N"))}
        case .oLower:
            Construction(.lowercaseLetter, expression: /.o) {stack in stack.push(.id("o"))}
        case .OUpper:
            Construction(.uppercaseLetter, expression: /.O) {stack in stack.push(.id("O"))}
        case .pLower:
            Construction(.lowercaseLetter, expression: /.p) {stack in stack.push(.id("p"))}
        case .PUpper:
            Construction(.uppercaseLetter, expression: /.P) {stack in stack.push(.id("P"))}
        case .qLower:
            Construction(.lowercaseLetter, expression: /.q) {stack in stack.push(.id("q"))}
        case .QUpper:
            Construction(.uppercaseLetter, expression: /.Q) {stack in stack.push(.id("Q"))}
        case .rLower:
            Construction(.lowercaseLetter, expression: /.r) {stack in stack.push(.id("r"))}
        case .RUpper:
            Construction(.uppercaseLetter, expression: /.R) {stack in stack.push(.id("R"))}
        case .sLower:
            Construction(.lowercaseLetter, expression: /.s) {stack in stack.push(.id("s"))}
        case .SUpper:
            Construction(.uppercaseLetter, expression: /.S) {stack in stack.push(.id("S"))}
        case .tLower:
            Construction(.lowercaseLetter, expression: /.t) {stack in stack.push(.id("t"))}
        case .TUpper:
            Construction(.uppercaseLetter, expression: /.T) {stack in stack.push(.id("T"))}
        case .uLower:
            Construction(.lowercaseLetter, expression: /.u) {stack in stack.push(.id("u"))}
        case .UUpper:
            Construction(.uppercaseLetter, expression: /.U) {stack in stack.push(.id("U"))}
        case .vLower:
            Construction(.lowercaseLetter, expression: /.v) {stack in stack.push(.id("v"))}
        case .VUpper:
            Construction(.uppercaseLetter, expression: /.V) {stack in stack.push(.id("V"))}
        case .wLower:
            Construction(.lowercaseLetter, expression: /.w) {stack in stack.push(.id("w"))}
        case .WUpper:
            Construction(.uppercaseLetter, expression: /.W) {stack in stack.push(.id("W"))}
        case .xLower:
            Construction(.lowercaseLetter, expression: /.x) {stack in stack.push(.id("x"))}
        case .XUpper:
            Construction(.uppercaseLetter, expression: /.X) {stack in stack.push(.id("X"))}
        case .yLower:
            Construction(.lowercaseLetter, expression: /.y) {stack in stack.push(.id("y"))}
        case .YUpper:
            Construction(.uppercaseLetter, expression: /.Y) {stack in stack.push(.id("Y"))}
        case .zLower:
            Construction(.lowercaseLetter, expression: /.z) {stack in stack.push(.id("z"))}
        case .zUpper:
            Construction(.uppercaseLetter, expression: /.Z) {stack in stack.push(.id("Z"))}
            
            
        case .letterUpper:
            Construction(.letter, expression: /.uppercaseLetter) {stack in
                guard let peek = stack.peek(), case .id(let str) = peek, str.count == 1, !str.first!.isLowercase else {
                    throw NSError()
                }
            }
        case .letterLower:
            Construction(.letter, expression: /.lowercaseLetter) {stack in
                guard let peek = stack.peek(), case .id(let str) = peek, str.count == 1, str.first!.isLowercase else {
                    throw NSError()
                }
            }
            
            
        case .oneOneNine:
            Construction(.oneNine, expression: /.one) {stack in stack.push(.int(1))}
        case .twoOneNine:
            Construction(.oneNine, expression: /.two) {stack in stack.push(.int(2))}
        case .threeOneNine:
            Construction(.oneNine, expression: /.three) {stack in stack.push(.int(3))}
        case .fourOneNine:
            Construction(.oneNine, expression: /.four) {stack in stack.push(.int(4))}
        case .fiveOneNine:
            Construction(.oneNine, expression: /.five) {stack in stack.push(.int(5))}
        case .sixOneNine:
            Construction(.oneNine, expression: /.six) {stack in stack.push(.int(6))}
        case .sevenOneNine:
            Construction(.oneNine, expression: /.seven) {stack in stack.push(.int(7))}
        case .eightOneNine:
            Construction(.oneNine, expression: /.eight) {stack in stack.push(.int(8))}
        case .nineOneNine:
            Construction(.oneNine, expression: /.nine) {stack in stack.push(.int(9))}
            
            
        case .zeroDigit:
            Construction(.digit, expression: /.zero) {stack in stack.push(.int(0))}
        case .oneNineDigit:
            Construction(.digit, expression: /.oneNine) {stack in
                guard let peek = stack.peek(), case .int = peek else {
                    throw NSError()
                }
            }
            
            
        case .digitDigits:
            Construction(.digits, expression: /.digit) { stack in
                guard let peek = stack.peek(), case .int = peek else {
                    throw NSError()
                }
            }
        case .digitDigitsDigits:
            Construction(.digits, expression: /.digit, /.digits) {stack in
                guard let digits = stack.pop(),
                      case .int(let digits) = digits,
                      let digit = stack.pop(),
                      case .int(let digit) = digit else {
                    throw NSError()
                }
                stack.push(.int(Int("\(digit)\(digits)")!))
            }
            
            
        case .oneNineDigitsInt:
            Construction(.integer, expression: /.oneNine, /.digits) { stack in
                guard let digits = stack.pop(),
                      case .int(let digits) = digits,
                      let oneNine = stack.pop(),
                      case .int(let oneNine) = oneNine else {
                    throw NSError()
                }
                stack.push(.int(Int("\(oneNine)\(digits)")!))
            }
        case .zeroInt:
            Construction(.integer, expression: /.zero) { stack in
                guard let peek = stack.peek(), case .int(let zero) = peek, zero == 0 else {
                    throw NSError()
                }
            }
            
            
        case .digitDigitOrLetter:
            Construction(.digitOrLetter, expression: /.digit) { stack in
                // todo
            }
        case .letterDigitOrLetter:
            Construction(.digitOrLetter, expression: /.letter) { stack in
                // todo
            }
            
            
        case .letterId:
            Construction(.identifier, expression: /.letter) {stack in
                guard let letter = stack.peek(), case .id = letter else {
                    throw NSError()
                }
            }
        case .idDigitOrLetterId:
            Construction(.identifier, expression: /.identifier, /.digitOrLetter) { stack in
                guard let digitOrLetter = stack.pop(),
                      let id = stack.pop(),
                      case .id(let id) = id else {
                    throw NSError()
                }
                switch digitOrLetter {
                case .id(let str):
                    stack.push(.id(id + str))
                case .int(let int):
                    stack.push(.id(id + "\(int)"))
                }
            }
            
        case .idIntOrId:
            Construction(.intOrId, expression: /.identifier) {stack in
                //todo
            }
            
        case .intIntOrId:
            Construction(.intOrId, expression: /.integer) {stack in
                //todo
            }
            
        }
    }
    
    
}

enum IdOrInt {
    case id(String)
    case int(Int)
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
    case uppercaseLetter, lowercaseLetter, letter, oneNine, digit, digits, integer, digitOrLetter, identifier, intOrId
}
