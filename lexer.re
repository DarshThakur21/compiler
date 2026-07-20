#include "parser.tab.hh"
#include <string>
#include <iostream>

namespace yy {
conj_parser::symbol_type yylex(lexcontext& ctx)
{
    // Local anchor remembers where the current token begins
    const char* anchor = ctx.cursor;
    
    // YYMARKER is required by re2c for backtracking in complex regex rules (like comments/identifiers)
    const char* YYMARKER = nullptr;
    
    // Step the location tracker forward
    ctx.loc.step();
    
    // Helper lambda calculates column width using the local anchor
    auto s = [&](auto func, auto&&... params) { 
        ctx.loc.columns(ctx.cursor - anchor); 
        return func(params..., ctx.loc); 
    };

    // Helper lambda specifically for single-character character-literal tokens (like '+', ',', ';')
    auto char_token = [&](char c) {
        ctx.loc.columns(ctx.cursor - anchor);
        return conj_parser::symbol_type(conj_parser::token_type(c), ctx.loc);
    };

/*!re2c
    re2c:yyfill:enable   = 0;
    re2c:define:YYCTYPE  = "char";
    re2c:define:YYCURSOR = "ctx.cursor";
    re2c:define:YYMARKER = "YYMARKER";

    // 1. Whitespace and newlines
    [ \t\r]+  { return yylex(ctx); }
    [\n]      { ctx.loc.lines(1); ctx.loc.step(); return yylex(ctx); }

    // 2. Keywords (Must be before identifiers!)
    "return"  { return s(conj_parser::make_RETURN); }
    "while"   { return s(conj_parser::make_WHILE);  }
    "if"      { return s(conj_parser::make_IF);     }
    "var"     { return s(conj_parser::make_VAR);    }

    // 3. Comments (Fixed to exclude \x00 sentinel!)
    "//" [^\r\n\x00]* { return yylex(ctx); }
    "/*" [^*\x00]* ("*" ([^/*\x00] [^*\x00]*)?)* "*/" { return yylex(ctx); }

    // 4. Identifiers & Numbers
    [a-zA-Z_] [a-zA-Z_0-9]* { 
        return s(conj_parser::make_IDENTIFIER, std::string(anchor, ctx.cursor)); 
    }

    [0-9]+ { 
        std::string str(anchor, ctx.cursor);
        try {
            return s(conj_parser::make_NUMCONST, std::stol(str));
        } catch (const std::exception& e) {
            std::cerr << "\n[LEXER ERROR] Number out of range: '" << str 
                      << "' at line " << ctx.loc.begin.line << "\n";
            throw;
        }
    }

    // 5. Multi-character operators
    "||"      { return s(conj_parser::make_OR);    }
    "&&"      { return s(conj_parser::make_AND);   }
    "=="      { return s(conj_parser::make_EQ);    }
    "!="      { return s(conj_parser::make_NE);    }
    "++"      { return s(conj_parser::make_PP);    }
    "--"      { return s(conj_parser::make_MM);    }
    "+="      { return s(conj_parser::make_PL_EQ); }
    "-="      { return s(conj_parser::make_MI_EQ); }

    // 6. Single-character punctuation and math operators
    ","       { return char_token(','); }
    ":"       { return char_token(':'); }
    ";"       { return char_token(';'); }
    "{"       { return char_token('{'); }
    "}"       { return char_token('}'); }
    "("       { return char_token('('); }
    ")"       { return char_token(')'); }
    "["       { return char_token('['); }
    "]"       { return char_token(']'); }
    "="       { return char_token('='); }
    "+"       { return char_token('+'); }
    "-"       { return char_token('-'); }
    "*"       { return char_token('*'); }
    "&"       { return char_token('&'); }
    "!"       { return char_token('!'); }
    "?"       { return char_token('?'); }

    // 7. End of File
    "\x00"    { return s(conj_parser::make_END); }

    // 8. CATCH-ALL SAFETY NET (MUST BE AT THE ABSOLUTE BOTTOM!)
    . { 
        std::cerr << "\n[LEXER ERROR] Unrecognized character: '" << *anchor 
                  << "' (ASCII: " << (int)*anchor << ") at line " 
                  << ctx.loc.begin.line << ", column " << ctx.loc.begin.column << "\n";
        throw yy::conj_parser::syntax_error(ctx.loc, "Unrecognized character in input");
    }
*/
}
} // Exactly two closing braces: one for yylex(), one for namespace yy