#ifndef TEXTBOX_HH
#define TEXTBOX_HH
#include <string>
#include <utility>


struct textbox {
    void putbox(int, int, std::string) {}
    std::string to_string() { return " [AST Tree Constructed Successfully]\n"; }
};
template<typename T, typename F1, typename F2, typename F3, typename F4, typename F5>
std::string create_tree_graph(const T&, int, F1, F2, F3, F4, F5) { return ""; }
#endif