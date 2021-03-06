--[[ grammar.lua

  A simple LPeg grammar for scheme.

  In order to be as flexible as possible, this grammar only parses tokens from
  input. All interpretation and evaluation tasks are handled by the interpreter
  which is provided as an argument to the main function returned by this
  module.

  Copyright (c) 2014, Joshua Ballanco.

  Licensed under the BSD 2-Clause License. See COPYING for full license details.

--]]

local tu = require("util/table")
local lp = require("lpeg")
local P, R, S, V, C, Cg, Ct, locale
      = lp.P, lp.R, lp.S, lp.V, lp.C, lp.Cg, lp.Ct, lp.locale

local grammar = {
  "Program",
  Program = V("CommandOrDefinition")
}

local tokens = require("grammar/tokens")
local cod = require("grammar/command_or_definition")

tu.merge(grammar, tokens)
tu.merge(grammar, cod)

return grammar

--[=[
local re = require("re")
local function grammar(parse)
  -- Use locale for matching; generates rules: alnum, alpha, cntrl, digit, graph, lower,
  -- print, punct, space, upper, and xdigit
  re.updatelocale()

  return re.compile([[
    -- "Program" is the top-level construct in Scheme, but for now we're using it to proxy
    -- to other forms for testing...
    Program             <- --ImportDecl
                           CommandOrDefinition

    CommandOrDefinition <- Definition
                         / Command
                         / open "begin"
                           (intraline_whitespace+ CommandOrDefinition)+
                           close
    Command             <- Expression

    -- "Expression" encompases most valid forms, including everything that counts as a
    -- "Datum" for processing by the REPL. More elements will be added to this list as
    -- more of the grammar is defined.
    Expression          <- LambdaExpression
                         / ProcedureCall
                         / Literal
                         / Identifier

    LambdaExpression    <- { {}
                             {| open "lambda"
                                {:params: formals :}
                                {:body: body :}
                                close |}
                           } -> parse_lambda
    formals             <- open Symbol* close
                         / Symbol
                         / open Symbol+ dot Symbol close
    body                <- Expression

    ProcedureCall       <- { {}
                             {| open
                                {:op: operator :}
                                {:args: {| (intraline_whitespace+ { operand })* |} :}
                                close |}
                           } -> parse_call
    operator            <- Expression
    operand             <- Expression

    Literal             <- Quotation
                         / SelfEvaluating

    Quotation           <- { {} "'" Datum
                         / open "quote" intraline_whitespace+ Datum close
                         } -> parse_quotation
    SelfEvaluating      <- Boolean
                         / Number
                         / Vector
                         / Character
                         / String
                         / Bytevector

    -- Some useful tokens
    explicit_sign       <- [+-]
    open                <- intraline_whitespace* [(] intraline_whitespace*
    close               <- intraline_whitespace* [)] intraline_whitespace*
    slash               <- [/]
    backslash           <- [\\]
    quote               <- ["]
    dot                 <- [.]
    minus               <- [-]

    -- Other basic elements
    initial             <- %alpha / special_initial
    special_initial     <- [!$%&*/:<=>?^_~]
    subsequent          <- initial / digit / special_subsequent
    special_subsequent  <- explicit_sign / [.@]
    space               <- [ ]
    tab                 <- [\t]
    newline             <- [\n]
    return              <- [\r]
    intraline_whitespace<- space / tab
    vertical_line       <- [|]
    line_ending         <- newline / return newline / return
    xscalar             <- xdigit+
    inline_hex_escape   <- backslash [x] xscalar [;]
    mnemonic_escape     <- backslash [abtnr]
    symbol_element      <- [^|\\] / inline_hex_escape / mnemonic_escape / "\\|"

    Boolean             <- { {} "#true" / "#t" } -> parse_true
                         / { {} "#false" / "#f" } -> parse_false

    -- Rules for the R7RS numeric tower
    -- NOTE: For a true full numeric tower, we would have to implement all the variations
    -- on complex number forms. For now, we only consider simple real numbers.
    Number              <- bnum / onum / num / xnum
    bnum                <- { {}
                             {| {:prefix: bprefix :} {:num: breal :} |}
                           } -> parse_bnum
    onum                <- { {}
                             {| {:prefix: oprefix :} {:num: oreal :} |}
                           } -> parse_onum
    num                 <- { {}
                             {| {:prefix: prefix :} {:num: real :} |}
                           } -> parse_num
    xnum                <- { {}
                             {| {:prefix: xprefix :} {:num: xreal :} |}
                           } -> parse_xnum
    breal               <- {| {:sign: sign :} bureal |} / infnan
    oreal               <- {| {:sign: sign :} oureal |} / infnan
    real                <- {| {:sign: sign :} ureal |} / infnan
    xreal               <- {| {:sign: sign :} xureal |} / infnan
    bureal              <- {:numerator: buint :} slash {:denominator: buint :}
                         / {:whole: buint :}
    oureal              <- {:numerator: ouint :} slash {:denominator: ouint :}
                         / {:whole: ouint :}
    ureal               <- decimal
                         / {:numerator: uint :} slash {:denominator: uint :}
                         / {:whole: uint :}
    xureal              <- {:numerator: xuint :} slash {:denominator: xuint :}
                         / {:whole: xuint :}
    decimal             <- {:whole: digit+ :} dot {:fraction: digit+ :} suffix
                         / dot {:fraction: digit+ :} suffix
                         / {:whole: uint :} suffix
    buint               <- bdigit +
    ouint               <- odigit +
    uint                <- digit +
    xuint               <- xdigit +
    bprefix             <- {:radix: bradix :} {:exactness: exactness :}
                         / {:exactness: exactness :} {:radix: bradix :}
    oprefix             <- {:radix: oradix :} {:exactness: exactness :}
                         / {:exactness: exactness :} {:radix: oradix :}
    prefix              <- {:radix: radix :} {:exactness: exactness :}
                         / {:exactness: exactness :} {:radix: radix :}
    xprefix             <- {:radix: xradix :} {:exactness: exactness :}
                         / {:exactness: exactness :} {:radix: xradix :}
    inf                 <- {:sign: explicit_sign :} [iI][nN][fF] dot '0'
    nan                 <- {:sign: explicit_sign :} [nN][aA][nN] dot '0'
    infnan              <- {|
                             {:inf: inf :}
                           / {:nan: nan :}
                           |}
    suffix              <- {:exp:
                             exp_marker
                             {|
                               {:sign: sign :}
                               {:value: digit+ :}
                             |}
                           :}?
    exp_marker          <- [eE]
    sign                <- explicit_sign?
    exactness           <- ([#] ([iI] / [eE]))?
    bradix              <- [#] [bB]
    oradix              <- [#] [oO]
    radix               <- ([#] [dD])?
    xradix              <- [#] [xX]
    bdigit              <- [01]
    odigit              <- [0-7]
    digit               <- %digit
    xdigit              <- %xdigit

    Vector              <- { {} "#("
                             {| Datum (intraline_whitespace+ Datum)* |}
                           ")" } -> parse_vector
    Datum               <- { {} simple_datum
                         / compound_datum
                         / {| {:label: label :} "=" {:datum: Datum :} |}
                         / {| {:label: label "#" :} |} }
    simple_datum        <- Boolean / Number / Character / String / Symbol / Bytevector
    compound_datum      <- List / Vector / Abbreviation
    label               <- { {} "#" uint } -> parse_label

    Abbreviation        <- { {} {| abbrev_prefix Datum |} } -> parse_abbreviation
    abbrev_prefix       <- {:prefix: "'" / "`" / "," / ",@" :}

    Character           <- { {} {| "#" backslash
                         ( "x" {:hex_character: hex_scalar_value :}
                         / {:named_character: character_name :}
                         / {:character: . :}) |} } -> parse_character
    character_name      <- "alarm" / "backspace" / "delete" / "escape" / "newline"
                         / "null" / "return" / "space" / "tab"
    hex_scalar_value    <- xdigit+

    String              <- { {} quote { string_element* } quote } -> parse_string
    string_element      <- [^"\\]
                         / mnemonic_escape
                         / backslash quote
                         / backslash backslash
                         / backslash intraline_whitespace* line_ending
                           intraline_whitespace*
                         / inline_hex_escape

    Bytevector          <- { {} "#u8" open
                             {| byte (intraline_whitespace+ byte)* |}
                           close } -> parse_bytevector
    byte                <- { "2" "5" [0-5]
                         / "2" [0-4] [0-9]
                         / "1" [0-9]^2
                         / [0-9]^-2 }

    -- Definitions
    Definition          <- { {} {|
                             open "define" intraline_whitespace+
                             {:name: Identifier :} intraline_whitespace+
                             {:value: Expression :}
                             close |}
                           } -> parse_simple_definition
                           / { {} {|
                             open "define" open
                             {:name: Identifier :} intraline_whitespace+
                             {:formals: def_formals :} close
                             {:body: body :} close |}
                           } -> parse_function_definition
                           / { {} {|
                             open "define-syntax" intraline_whitespace+
                             {:name: Keyword :} intraline_whitespace+
                             {:transform: transformer_spec :} close |}
                           } -> parse_syntax_definition
    def_formals         <- { {} {|
                             { Identifier }*
                           / { Identifier }* "." {:rest_arg: Identifier :}
                           |} }
    transformer_spec    <- { {} {|
                             (open "syntax-rules"
                             open {:identifier: Identifier :} close
                             syntax_rule* close)
                           |} }
    syntax_rule         <- { {} {| open {:pattern: pattern :}
                                   intraline_whitespace+
                                   {:template: template :}
                                   close |}
                           } -> parse_syntax_rule
    pattern             <- pattern_datum
    pattern_datum       <- String
                         / Character
                         / Boolean
                         / Number
    template            <- template_datum
    template_datum      <- pattern_datum


    -- Parsing constructs
    Identifier          <- { %alpha %alnum* } -> parse_symbol
    Symbol              <- Identifier
    Keyword             <- Identifier

    -- Simple forms
    Car                 <- Symbol
    Cdr                 <- List+ / Symbol / Number
    List                <- {|
                              open %space*
                              {:car: Car :} %space+
                              {:cdr: Cdr :} %space*
                              close
                           |} -> parse_list
  ]], parse)
end

return grammar
--]=]
