{
  "targets": [{
    "target_name": "calendar",
    "sources": [ ],
    "conditions": [
      ['OS=="mac"', {
        "sources": [
          "calendar.mm"
        ],
      }]
    ],
    'include_dirs': [
      "<!@(node -p \"require('node-addon-api').include\")"
    ],
    'libraries': [],
    'dependencies': [
      "<!(node -p \"require('node-addon-api').gyp\")"
    ],
    'defines': [ 'NAPI_DISABLE_CPP_EXCEPTIONS' ],
    "xcode_settings": {
      "OTHER_CPLUSPLUSFLAGS": ["-std=c++20", "-stdlib=libc++", "-mmacosx-version-min=10.13"],
      "OTHER_LDFLAGS": ["-framework CoreFoundation -framework AppKit -framework EventKit"]
    }
  }]
}