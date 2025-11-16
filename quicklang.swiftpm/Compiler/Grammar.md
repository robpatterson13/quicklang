program ::= \<func-def\> \<program\> ... \
          | \<def\> \<program\> ... \
          | \<func-call\>`;`

atom ::= \<num\> \
       | \<bool\> \
       | \<identifier\>

expr ::= \<atom\> \
       | `(`\<unary-op\>\<expr\>`)` \
       | \<atom\> \<binary-op\> \<expr\> \
       | \<func-call\>
       
stmt ::= `if` \<expr\> `{` \<stmt-or-def\> ...+ `}` `else` `{` \<stmt-or-def\> ...+ `}` \
       | `return` \<expr\>`;` \
       | `print(`\<expr\>`);`
       
def ::= `let` \<identifier\> `=` \<expr\>`;` \
      | `var` \<identifier\> `=` \<expr\>`;`
      
func-call ::= \<identifier\>`(`\<expr\> ...`)`
      
func-def ::= `func` \<identifier\>`(`\<func-param\> ...`)` `->` \<type\> `{` \<stmt-or-def\> ...+ `}`
      
func-param ::= \<identifier\>`:` \<type\>
      
type ::= Int \
       | Bool \
       | String
       
stmt-or-def ::= \<stmt\> \
              | \<def\>
       
unary-op ::= ! \
           | -
       
binary-op ::= + \
            | - \
            | * \
            | && \
            | ||
