#include <string>

extern "C" int rules_scala_native_cpp_probe() {
  return static_cast<int>(std::string("ok").size());
}
