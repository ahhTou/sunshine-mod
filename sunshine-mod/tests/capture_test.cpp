/** @file capture_test.cpp @brief 验证默认采集与格式回退。 */
#include "src/platform/macos/sunshine_mod_capture.h"
static_assert(sunshine_mod::use_sck("",8));
static_assert(sunshine_mod::use_sck("sck",8));
static_assert(!sunshine_mod::use_sck("avfoundation",8));
static_assert(!sunshine_mod::use_sck("sck",10));
static_assert(!sunshine_mod::use_sck("",10));
int main() { return 0; }
