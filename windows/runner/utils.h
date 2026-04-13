#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process, and redirects stdout and stderr.
void CreateAndAttachConsole();

// Takes a null-terminated wchar_t* command line string and returns a vector of
// UTF-8 encoded command line arguments.
std::vector<std::string> GetCommandLineArguments();

#endif  // RUNNER_UTILS_H_
