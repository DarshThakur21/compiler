// =========================================================================
// SECTION 1: CONFIGURATION & CONFIG CODE DECLARATIONS
// =========================================================================

// Use the modern C++ LALR(1) parser skeleton provided by Bison

%skeleton "lalr1.cc"

// Define the name of the generated C++ class we will instantiate in main()
%define parser_class_name {conj_parser}

// Enable type-safe token construction (allows us to pass values cleanly from lexer)
%define api.token.constructor
%define api.value.type variant


// Enable runtime assertions and detailed, verbose compiler error tracking
%define parse.assert
%define parse.error verbose

// Tell Bison to generate tracking code for tracking file locations (lines/columns)
%locations

// Anything inside %code requires is copied directly into the generated header file (parser.tab.hh).
// This is where we define our Abstract Syntax Tree (AST) structures.

%code requires
{
#include <map>
#include <list>
#include <vector>
#include <string>
#include <iostream>
#include <algorithm>

// X-Macro for Identifiers: cleanly sets up an enumeration of identifier scopes.

#define ENUM_IDENTIFIERS(o) \
        o(undefined) /* Catch-all uninitialized state */ \
        o(functions) /* Global or local function reference */ \
        o(function)  /* Argument passed into a function */ \   
        o(variable)  /* Locally allocated block variable */
#define o(n) n,
enum class id_type { ENUM_IDENTIFIERS(o) };
#undef o 

// Represents an identifier's metadata tracked in our symbol tablestruct expressions
struct identifier 
{
    id_type type =id_type::undefined;
    std::size_t index=0;         // Tracks function index, parameter slot, or variable ID
    std::string name;

};

// X-Macro for Expression Types: Types of nodes available in our AST.
#define ENUM_EXPRESSIONS(o) \
        o(nop) o(string) o(number) o(ident)       /* Core Leaf/Atom nodes */ \
        o(add) o(neg) o(eq)                       /* Math & transformations */ \
        o(cor) o(cand) o(loop)                    /* Logical structures and Whiles */ \
        o(addrof) o(deref)                        /* Pointer addressing (& and *) */ \
        o(fcall)                                  /* Function execution */ \
        o(copy)                                   /* Value Assignment (=) */ \
        o(comma)                                  /* Evaluated block sequence */ \
        o(ret)                                    /* Return operations */

#define o(n) n,
enum class ex_type {  ENUM_EXPRESSIONS(o) };
#undef o
  
// Define our AST expression node. Nodes can nestedly possess chains of sub-parameters.
typedef std::list<struct expression> expr_vec;

struct expression
{
    ex_type type;
    identifier      ident{};    
    std::string     strvalue{}; 
    long            numvalue=0; 
    expr_vec        params;     // Sub-expressions (e.g., left & right operands)

    // Template constructor to easily allow constructing nested expressions via forwarding
    template<typename... T>
    expression(ex_type t, T&&... args) : type(t), params{ std::forward<T>(args)... } {}

    expression()                    : type(ex_type::nop) {}
    expression(const identifier& i) : type(ex_type::ident),  ident(i)            { }
    expression(identifier&& i)      : type(ex_type::ident),  ident(std::move(i)) { }
    expression(std::string&& s)     : type(ex_type::string), strvalue(std::move(s)) { }
    expression(long v)              : type(ex_type::number), numvalue(v) {}

    bool is_pure() const;

    // Custom move assignment operator mapping to a standard node copying assignment
    expression operator%=(expression&& b) && { return expression(ex_type::copy, std::move(b), std::move(*this)); }
};


// Auto-generates clean inline factory shortcuts like e_add(), e_loop() for every expression type
#define o(n) \
template<typename... T> \
inline expression e_n(T&&... args) { return expression(ex_type::n, std::forward<T>(args)...); }
ENUM_EXPRESSIONS(o)
#undef o

// Holds top-level metadata compiled for parsed functions
struct function
{
    std::string name;
    expression  code; // The fully expanded root AST node of the function body
    unsigned num_vars = 0, num_params = 0;
};

struct lexcontext;
}// End of %code requires



// Pass the context tracking structure explicitly as a parameter through the parser and lexer
%param { lexcontext& ctx }

// Anything inside %code is written directly into the main implementation file (parser.tab.cc).
%code
{
struct lexcontext
{
    const char* cursor;
    yy::location loc;
    std::vector<std::map<std::string, identifier>> scopes; // Symbol Table stack for scoping
    std::vector<function> func_list;
    unsigned tempcounter = 0;
    function fun;
public:
    // Helper to inject an identifier safely into the current active lexical scope
    const identifier& define(const std::string& name, identifier&& f)
    {
        auto r = scopes.back().emplace(name, std::move(f));
        if(!r.second) throw yy::conj_parser::syntax_error(loc, "Duplicate definition <"+name+">");
        return r.first->second;
    }
    expression def(const std::string& name)     { return define(name, identifier{id_type::variable,  fun.num_vars++,   name}); }
    expression defun(const std::string& name)   { return define(name, identifier{id_type::function,  func_list.size(), name}); }
    expression defparm(const std::string& name) { return define(name, identifier{id_type::parameter, fun.num_params++, name}); }
    expression temp()                           { return def("$I" + std::to_string(tempcounter++)); }
    
    // Look backward through active scopes to evaluate a used symbol
    expression use(const std::string& name)
    {
        for(auto j = scopes.crbegin(); j != scopes.crend(); ++j)
            if(auto i = j->find(name); i != j->end())
                return i->second;
        throw yy::conj_parser::syntax_error(loc, "Undefined identifier <"+name+">");
    }
    void add_function(std::string&& name, expression&& code)
    {
        fun.code = e_comma(std::move(code), e_ret(0l)); // Appends a safeguard default "return 0;"
        fun.name = std::move(name);
        func_list.push_back(std::move(fun));
        fun = {};
    }
    void operator ++() { scopes.emplace_back(); } // Enter fresh scope block
    void operator --() { scopes.pop_back();     } // Destroy active scope block on exit
};

// Declare the external lexer function Bison expects to loop through
namespace yy { conj_parser::symbol_type yylex(lexcontext& ctx); }

#define M(x) std::move(x)
#define C(x) expression(x)
}













// Token Declarations

%token			END 0 		
%token			RETURN "return" WHILE "while" IF "if" VAR "var" IDENTIFIER NUMCONST STRINGCONST
%token			OR "||"  AND "&&"  EQ "=="  NE "!="  PP "++"  MM "--"  PL_EQ "+="  MI_EQ "-="

// Operator Precedence & Associativity Layout (Bottom rules resolve with highest priority)

%left  ','
%right '?' ':' '=' "+=" "-="
%left  "||"
%left  "&&"
%left  "==" "!="
%left  '+' '-'
%left  '*'
%right '&' "++" "--"
%left  '(' '['


// Associate standard raw types or tracking expressions directly to grammar elements
%type<long>        NUMCONST
%type<std::string> IDENTIFIER STRINGCONST identifier1
%type<expression>  expr expr1 exprs exprs1 c_expr1 p_expr1 stmt stmt1 var_defs var_def1 com_stmt



%%
// =========================================================================
// SECTION 2: GRAMMAR RULES & SEMANTIC ACTIONS
// ====

library:			{ ++ctx; } functions { --ctx; };
functions:			functions identifier1 {ctx.defun($2); ++ctx; } paramdecls colon1 stmt1 {ctx.add_function(M($2),M($6)); --ctx; } | %empty;
paramdecls:			paramdecl | %empty;
paramdecl:			paramdecl ',' identifier1 {ctx.defparm($3);} 
				|	IDENTIFIER				  {ctx.defparm($1);};

// Error recovery stubs: lets the engine handle syntax blunders gracefully without crashing


identifier1:		error{} | IDENTIFIER				{$$ = M($1)};
colon1:				error{} | ':';
semicolon1:			error{} | ';';
cl_brace1:			error{} | '}';
cl_bracket1:		error{} | ']';
cl_parens1:			error{} | ')';
stmt1:				error{} | stmt						{$$ = M($1);};
exprs1:				error{}	| exprs 					{$$ = M($1);};			
expr1:				error{} | expr						{$$ = M($1);};

//$1 = '(' $2 = expression(10+20) $3 = ')'
p_expr1:			error{} | '(' exprs1 cl_parens1     {$$ = M($2);}; 

stmt:				com_stmt		cl_brace1			{$$ = M($1); --ctx; } 
				|	"if"  p_expr1 stmt1					{ $$ = e_cand(M($2), M($3)); }
				|	"while" p_expr1 stmt1				{ $$ = e_loop(M($2), M($3)); }
				|	"return" exprs1 semicolon1			{ $$ = e_ret(M($2));         }
				|	 exprs          semicolon1			{ $$ = M($1);        }
				|    ';'								{ };

com_stmt:			'{'									{ $$ = e_comma(); ++ctx; }
				| com_stmt stmt							{ $$ = M($1); $$.params.push_back(M($2)); };

var_defs:			"var"			var_def1			{ $$ = e_comma(M($2)); }
				| var_defs 	','  	var_def1			{ $$ = M($1); $$.params.push_back(M($3)); };

var_def1:			identifier1 '=' expr1				{ $$ = ctx.def($1) %= M($3); }
				|   identifier1							{ $$ = ctx.def($1) %= 0l; };

exprs:				var_defs							{ $$ = M($1); }
				|	expr								{ $$ = M($1); }
				|   expr		','		c_expr1			{ $$ = e_comma(M($1)); $$.params.splice($$.params.end(), M($3.params)); };

c_expr1:			expr1                       { $$ = e_comma(M($1)); }
				| c_expr1 ',' expr1           { $$ = M($1); $$.params.push_back(M($3)); }; 



expr:             NUMCONST                                                          { $$ = $1;    }
                | STRINGCONST                                                       { $$ = M($1); }
                | IDENTIFIER                                                        { $$ = ctx.use($1);   }
                | '(' exprs1 cl_parens1                                             { $$ = M($2); }
                | expr '[' exprs1 cl_bracket1                                       { $$ = e_deref(e_add(M($1), M($3))); }
                | expr '(' ')'                                                      { $$ = e_fcall(M($1)); }
                | expr '(' c_expr1 cl_parens1                                       { $$ = e_fcall(M($1)); $$.params.splice($$.params.end(), M($3.params)); }
                | expr '='  error {$$=M($1);} | expr '='  expr                      { $$ = M($1) %= M($3); }
                | expr '+'  error {$$=M($1);} | expr '+'  expr                      { $$ = e_add( M($1), M($3)); }
                | expr '-'  error {$$=M($1);} | expr '-'  expr   %prec '+'          { $$ = e_add( M($1), e_neg(M($3))); }
                | expr "+=" error {$$=M($1);} | expr "+=" expr                      { if(!$3.is_pure()) { $$ = ctx.temp() %= e_addrof(M($1)); $1 = e_deref($$.params.back()); }
                                                                                        $$ = e_comma(M($$), M($1) %= e_add(C($1), M($3))); }
                | expr "-=" error {$$=M($1);} | expr "-=" expr              { if(!$3.is_pure()) { $$ = ctx.temp() %= e_addrof(M($1)); $1 = e_deref($$.params.back()); }
                                                                              $$ = e_comma(M($$), M($1) %= e_add(C($1), e_neg(M($3)))); }
                | "++" error {}               | "++" expr                    { if(!$2.is_pure()) { $$ = ctx.temp() %= e_addrof(M($2)); $2 = e_deref($$.params.back()); }
                                                                              $$ = e_comma(M($$), M($2) %= e_add(C($2),  1l)); }
                | "--" error {}               | "--" expr        %prec "++" { if(!$2.is_pure()) { $$ = ctx.temp() %= e_addrof(M($2)); $2 = e_deref($$.params.back()); }
                                                                              $$ = e_comma(M($$), M($2) %= e_add(C($2), -1l)); }
                |                             expr "++"                    { if(!$1.is_pure()) { $$ = ctx.temp() %= e_addrof(M($1)); $1 = e_deref($$.params.back()); }
                                                                              auto i = ctx.temp(); $$ = e_comma(M($$), C(i) %= C($1), C($1) %= e_add(C($1),  1l), C(i)); }
                |                             expr "--"        %prec "++" { if(!$1.is_pure()) { $$ = ctx.temp() %= e_addrof(M($1)); $1 = e_deref($$.params.back()); }
                                                                              auto i = ctx.temp(); $$ = e_comma(M($$), C(i) %= C($1), C($1) %= e_add(C($1), -1l), C(i)); }
                | expr "||" error {$$=M($1);} | expr "||" expr              { $$ = e_cor( M($1), M($3)); }
                | expr "&&" error {$$=M($1);} | expr "&&" expr              { $$ = e_cand(M($1), M($3)); }
                | expr "==" error {$$=M($1);} | expr "==" expr              { $$ = e_eq(  M($1), M($3)); }
                | expr "!=" error {$$=M($1);} | expr "!=" expr   %prec "==" { $$ = e_eq(e_eq(M($1), M($3)), 0l); }
                | '&' error{}                 | '&' expr                    { $$ = e_addrof(M($2)); }
                | '*' error{}                 | '*' expr         %prec '&'  { $$ = e_deref(M($2));  }
                | '-' error{}                 | '-' expr         %prec '&'  { $$ = e_neg(M($2));    }
                | '!' error{}                 | '!' expr         %prec '&'  { $$ = e_eq(M($2), 0l); }
                | expr '?'  error {$$=M($1);} | expr '?' expr ':' expr      { auto i = ctx.temp();
                                                                        $$ = e_comma(e_cor(e_cand(M($1), e_comma(C(i) %= M($3), 1l)), C(i) %= M($5)), C(i)); }
%%


// =========================================================================
// SECTION 3: EPILOGUE (Left empty here as we put logic in separate source files)
//










