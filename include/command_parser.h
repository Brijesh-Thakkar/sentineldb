#ifndef COMMAND_PARSER_H
#define COMMAND_PARSER_H

#include <string>
#include <vector>
#include "command.h"

class CommandParser {
public:
    // Parse a command string into a Command structure
    static Command parse(const std::string& input);
    
private:
    // Tokenize input string
    static std::vector<std::string> tokenize(const std::string& input);
    
    // Convert string to CommandType
    static CommandType getCommandType(const std::string& cmd);
};

#endif // COMMAND_PARSER_H
