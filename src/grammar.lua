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
local P, R, S, V, C, Cg, Ct, locale
      = lp.P, lp.R, lp.S, lp.V, lp.C, lp.Cg, lp.Ct, lp.locale

local function grammar(parse)
  local G = {"Program"}

  -- Use locale for matching; generates rules: alnum, alpha, cntrl, digit, graph, lower,
  -- print, punct, space, upper, and xdigit
  G = locale(G)
  G.open = P"("
  G.close = P")"
  G.quote = P"\""
  G.backslash = P"\\"
  G.escaped_quote = P(V"backslash" * V"quote")

  G.String = C(V"quote" * P(-V"quote"^0 + V"escaped_quote") * V"quote") / parse.string
  G.Symbol = C(V"alpha" * V"alnum"^0) / parse.symbol
  G.Number = P(V"digit"^1)

  G.Car = V"Symbol"
  G.Cdr = P(V"List"^1 + V"Symbol" + V"Number")
  G.List = Ct(V"open" * P" "^0 * Cg(V"Car", "car") * P" "^0
              * Cg(V"Cdr", "cdr") * P" "^0 * V"close") / parse.list

  G.Program = Ct(V"List"^1)

  return G
end

return grammar
