#include <windows.h>
#include <rpc.h>
#include <rpcndr.h>
#include <cstdio>
#include <cstring>

#define PUDU_SDK_TEXT_INNER(value) #value
#define PUDU_SDK_TEXT(value) PUDU_SDK_TEXT_INNER(value)
static const char beforeMidl[] = PUDU_SDK_TEXT(MIDL_INTERFACE("11111111-1111-1111-1111-111111111111"));
static const char beforeUuid[] = PUDU_SDK_TEXT(__uuidof(IUnknown));

#include "pudu_webview_win_sdk.h"

int main() {
  const GUID completion = {0x49511172, 0xcc67, 0x4bca, {0x99, 0x23, 0x13, 0x71, 0x12, 0xf4, 0xc4, 0xcc}};
  const GUID options = {0x2fde08a8, 0x1e9a, 0x4766, {0x8c, 0x05, 0x95, 0xa9, 0xce, 0xb9, 0xd1, 0xc5}};
  const GUID settings = {0xee9a0f68, 0xf46c, 0x4e32, {0xac, 0x23, 0xef, 0x8c, 0xac, 0x22, 0x4d, 0x2a}};
  bool passed = IsEqualGUID(completion, pudu_uuid<ICoreWebView2ExecuteScriptCompletedHandler>()) &&
    IsEqualGUID(options, pudu_uuid<ICoreWebView2EnvironmentOptions>()) &&
    IsEqualGUID(settings, pudu_uuid<ICoreWebView2Settings2>()) &&
    !IsEqualGUID(pudu_uuid<ICoreWebView2EnvironmentOptions>(), pudu_uuid<ICoreWebView2Settings2>()) &&
    std::strcmp(beforeMidl, PUDU_SDK_TEXT(MIDL_INTERFACE("11111111-1111-1111-1111-111111111111"))) == 0 &&
    std::strcmp(beforeUuid, PUDU_SDK_TEXT(__uuidof(IUnknown))) == 0;
  std::printf("sdk-uuid=%d\n", passed ? 1 : 0);
  return passed ? 0 : 1;
}
