#include "parser.tab.hh"
#include <string>

namespace yy {
conj_parser::symbol_type yylex(lexcontext& ctx)
{
    // Local anchor remembers where the current token begins
    const char* anchor = ctx.cursor;
    
    // Step the location tracker forward
    ctx.loc.step();
    
    // Helper lambda calculates column width using the local anchor
    auto s = [&](auto func, auto&&... params) { 
        ctx.loc.columns(ctx.cursor - anchor); 
        return func(params..., ctx.loc); 
    };

/*!re2c
    re2c:yyfill:enable   = 0;
    re2c:define:YYCTYPE  = "char";
    re2c:define:YYCURSOR = "ctx.cursor";

    // Extracting substring by slicing from local anchor to current cursor
    [a-zA-Z_] [a-zA-Z_0-9]* { return s(conj_parser::make_IDENTIFIER, std::string(anchor, ctx.cursor)); }
    [0-9]+                  { return s(conj_parser::make_NUMCONST, std::stol(std::string(anchor, ctx.cursor))); }
    // ... rest of rules ...
*/
}
}