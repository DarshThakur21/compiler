#include "parser.tab.hh"
#include <fstream>
#include <iostream>

void yy::conj_parser::error(const location_type& l, const std::string& m)
{
    std::cerr << (l.begin.filename ? l.begin.filename->c_str() : "(undefined)");
    std::cerr << ':' << l.begin.line << ':' << l.begin.column << '-' << l.end.column << ": " << m << '\n';
}

bool expression::is_pure() const
{
    for(const auto& e: params) if(!e.is_pure()) return false;
    switch(type)
    {
        case ex_type::fcall: case ex_type::copy: case ex_type::ret: case ex_type::loop: return false;
        default: return true;
    }
}

std::string stringify(const expression& e, bool stmt);
std::string stringify_op(const expression& e, const char* sep, const char* delim, bool stmt = false, unsigned first=0, unsigned limit=~0u)
{
    std::string result(1, delim[0]);
    const char* fsep = "";
    for(const auto& p: e.params) { 
        if(first) { --first; continue; }
        if(!limit--) break;
        result += fsep; fsep = sep; result += stringify(p, stmt); 
    }
    if(stmt) result += sep;
    result += delim[1];
    return result;
}

std::string stringify(const expression& e, bool stmt)
{
    auto expect1 = [&]{ return e.params.empty() ? "?" : e.params.size()==1 ? stringify(e.params.front(), false) : stringify_op(e, "??", "()"); };
    switch(e.type)
    {
        case ex_type::nop    : return "";
        case ex_type::string : return "\"" + e.strvalue + "\"";
        case ex_type::number : return std::to_string(e.numvalue);
        case ex_type::ident  : return "?FPVS"[(int)e.ident.type] + std::to_string(e.ident.index) + "\"" + e.ident.name + "\"";
        case ex_type::add    : return stringify_op(e, " + ",  "()");
        case ex_type::eq     : return stringify_op(e, " == ", "()");
        case ex_type::cand   : return stringify_op(e, " && ", "()");
        case ex_type::cor    : return stringify_op(e, " || ", "()");
        case ex_type::comma  : return stmt ? stringify_op(e, "; ", "{}", true) : stringify_op(e, ", ",  "()");
        case ex_type::neg    : return "-(" + expect1() + ")";
        case ex_type::deref  : return "*(" + expect1() + ")";
        case ex_type::addrof : return "&(" + expect1() + ")";
        case ex_type::copy   : return "(" + stringify(e.params.back(), false) + " = " + stringify(e.params.front(), false) + ")";
        case ex_type::fcall  : return "(" + (e.params.empty() ? "?" : stringify(e.params.front(), false))+")"+stringify_op(e,", ","()",false,1);
        case ex_type::loop   : return "while " + stringify(e.params.front(), false) + " " + stringify_op(e, "; ", "{}", true, 1);
        case ex_type::ret    : return "return " + expect1();
    }
    return "?";
}

#include "textbox.hh"
static std::string stringify_tree(const function& f)
{
    textbox result;
    result.putbox(2,0, create_tree_graph(f.code, 130, [](const expression& e){ return ""; }, [](const expression& e){ return std::make_pair(e.params.cbegin(), e.params.cend()); }, [](const expression&){return true;}, [](const expression&){return true;}, [](const expression&){return true;}));
    return "function " + f.name + ":\n" + stringify(f.code, true) + '\n' + result.to_string();
}

int main(int argc, char** argv)
{
    if(argc < 2) { std::cerr << "Usage: " << argv[0] << " <source_file>\n"; return 1; }
    std::string filename = argv[1];
    std::ifstream f(filename);
    std::string buffer(std::istreambuf_iterator<char>(f), {});

    lexcontext ctx;
    ctx.cursor = buffer.c_str();
    ctx.loc.begin.filename = &filename;
    ctx.loc.end.filename   = &filename;

    yy::conj_parser parser(ctx);
    parser.parse();

    for(const auto& func: ctx.func_list) std::cout << stringify_tree(func);
    return 0;
}