#pragma once

#include <fmt/core.h>
#include <iostream>
#include <string>

namespace console {

// template <typename... Args>
// void println(fmt::format_string<Args...> fmtStr, Args&&... args) {
//     std::cout << fmt::format(fmtStr, std::forward<Args>(args)...) << std::endl;
// }

inline void println(const std::string& str) {
    std::cout << str << std::endl;
}

inline void println() {
    std::cout << std::endl;
}

}
