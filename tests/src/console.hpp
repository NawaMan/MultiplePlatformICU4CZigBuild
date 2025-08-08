#pragma once

// Windows version without fmt library dependency
#include <iostream>
#include <string>
#include <sstream>
#include <regex>

namespace console {

// Simple format function to replace {} placeholders with values
template <typename T>
std::string format_arg(const std::string& fmt, const T& value) {
    std::ostringstream oss;
    oss << value;
    return std::regex_replace(fmt, std::regex("\\{\\}"), oss.str(), std::regex_constants::format_first_only);
}

template <typename T, typename... Args>
std::string format_arg(const std::string& fmt, const T& value, const Args&... args) {
    std::ostringstream oss;
    oss << value;
    std::string new_fmt = std::regex_replace(fmt, std::regex("\\{\\}"), oss.str(), std::regex_constants::format_first_only);
    return format_arg(new_fmt, args...);
}

// Print functions
template <typename... Args>
void println(const std::string& fmt, const Args&... args) {
    std::cout << format_arg(fmt, args...) << std::endl;
}

inline void println(const std::string& str) {
    std::cout << str << std::endl;
}

inline void println() {
    std::cout << std::endl;
}

// For non-string format patterns (needed for compatibility)
template <typename... Args>
void println(const char* fmt, const Args&... args) {
    println(std::string(fmt), args...);
}

}
