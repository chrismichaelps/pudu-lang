#ifndef PUDU_WEBVIEW_WIN_SDK_H
#define PUDU_WEBVIEW_WIN_SDK_H

#include <windows.h>
#include <rpc.h>
#include <rpcndr.h>

#if defined(__clang__) && defined(__MINGW32__)
#pragma push_macro("MIDL_INTERFACE")
#pragma push_macro("__uuidof")
#undef MIDL_INTERFACE
#undef __uuidof
// MinGW declarations must retain SDK UUIDs for the compiler's native lookup.
#define MIDL_INTERFACE(id) struct __declspec(uuid(id))
#endif

#include "WebView2.h"

template <typename Interface>
inline const GUID &pudu_uuid() { return __uuidof(Interface); }

#if defined(__clang__) && defined(__MINGW32__)
#pragma pop_macro("__uuidof")
#pragma pop_macro("MIDL_INTERFACE")
#endif

#endif
