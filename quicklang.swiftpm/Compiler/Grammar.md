program ::= <func-def> <program> ...
          | <def> <program> ...
          | <expr>

atom ::= <num>
       | <bool>
       | <identifier>

expr ::= <atom>
       | `!``(`<unary-op><expr>`)`
       | <atom> <binary-op> <expr>
       | <identifier>`(`<expr> ...`)`
       
stmt ::= `if` <expr> `{` <stmt-or-def> ...+ `}` `else` `{` <stmt-or-def> ...+ `}`
       | `return` <expr>
       
def ::= `let` <identifier> `=` <expr>
      | `var` <identifier> `=` <expr>
      
func-def ::= `func` <identifier>`(`<func-param> ...`)` `->` <type> `{` <stmt-or-def> ...+ `}`
      
func-param ::= <identifier>`:` <type>
      
type ::= Int
       | Bool
       
stmt-or-def ::= <stmt>
              | <def>
       
unary-op ::= !
           | -
       
binary-op ::= +
            | -
            | *
            | &&
            | ||
