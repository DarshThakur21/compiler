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













