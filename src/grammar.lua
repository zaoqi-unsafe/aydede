--[[ grammar.lua

  A simple LPeg grammar for scheme.

  In order to be as flexible as possible, this grammar only parses tokens from
  input. All interpretation and evaluation tasks are handled by the interpreter
  which is provided as an argument to the main function returned by this
  module.

  Copyright (c) 2014, Joshua Ballanco.

  Licensed under the BSD 2-Clause License. See COPYING for full license details.

--]]


local lp = require("lpeg")
local re = require("re")
local P, R, S, V, C, Cg, Ct, locale
      = lp.P, lp.R, lp.S, lp.V, lp.C, lp.Cg, lp.Ct, lp.locale

local function grammar(parse)
  local G

  -- Use locale for matching; generates rules: alnum, alpha, cntrl, digit, graph, lower,
  -- print, punct, space, upper, and xdigit
  re.updatelocale()

  G = re.compile([[
    -- "Program" is the top-level construct in Scheme, but for now we're using it to proxy
    -- to other forms for testing...
    Program             <- CommandOrDefinition

    -- TODO: need to add the "...OrDefinition" part. For now just proxying through to
    -- forms we want to test...
    CommandOrDefinition <- Command
    Command             <- Expression

    -- "Expression" encompases most valid forms, including everything that counts as a
    -- "Datum" for processing by the REPL. More elements will be added to this list as
    -- more of the grammar is defined.
    Expression          <- Literal  -- TODO: Literal should come after Symbol
                                    -- ...just here to test suffix for now
                         / Symbol   -- Synonymous with "Identifier"

    Literal             <- SelfEvaluating

    SelfEvaluating      <- suffix   -- just putting this here for an interim test...
                         / String
                         / Number

    suffix              <- {:exp: {| exp_marker sign exp_value |} :}
    exp_marker          <- [eE]
    explicit_sign       <- [+-]
    sign                <- {:sign: explicit_sign? :}
    exp_value           <- {:value: %digit+ :}

    open                <- [(]
    close               <- [)]
    quote               <- ["]
    not_quote           <- [^"]
    backslash           <- [\\]
    escaped_quote       <- backslash quote
    dot                 <- [.]
    minus               <- [-]

    -- Rules for the R7RS numeric tower
    exactness           <- ([#] ([iI] / [eE]))?
    bradix              <- [#] [bB]
    oradix              <- [#] [oO]
    radix               <- ([#] [dD])?
    xradix              <- [#] [xX]
    bdigit              <- [01]
    odigit              <- [0-7]

    -- Other basic elements
    initial             <- %alpha / special_initial
    special_initial     <- [!$%&*/:<=>?^_~]
    subsequent          <- initial / %digit / special_subsequent
    special_subsequent  <- explicit_sign / [.@]
    vertical_line       <- [|]
    xscalar             <- %xdigit+
    inline_hex_escape   <- backslash [x] xscalar [;]
    mnemonic_escape     <- backslash [abtnr]
    symbol_element      <- [^|\\] / inline_hex_escape / mnemonic_escape / "\\|"

    -- Parsing constructs
    String              <- { quote (escaped_quote / not_quote)* quote } -> parse_string
    Symbol              <- { %alpha %alnum* } -> parse_symbol
    Number              <- { sign %digit+ (dot %digit*)? } -> parse_number

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

  return G
end

return grammar
