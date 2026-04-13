#include "utils.h"

#include <windows.h>

#include <iostream>
#include <io.h>


void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE* unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stderr), 2);
    }
  }
}

std::vector<std::string> GetCommandLineArguments() {
  int argc;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);
  if (argv == nullptr) {
    return std::vector<std::string>();
  }

  std::vector<std::string> command_line_arguments;

  for (int i = 1; i < argc; ++i) {
    int length = WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, nullptr, 0,
                                     nullptr, nullptr);
    if (length > 0) {
      std::string argument(length - 1, 0);
      WideCharToMultiByte(CP_UTF8, 0, argv[i], -1, argument.data(),
                          static_cast<int>(argument.size() + 1), nullptr,
                          nullptr);
      command_line_arguments.push_back(std::move(argument));
    }
  }

  ::LocalFree(argv);

  return command_line_arguments;
}
