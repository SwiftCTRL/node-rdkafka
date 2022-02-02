{
  'targets': [
    {
      "target_name": "librdkafka",
      "type": "none",
      "conditions": [
        [
          'OS=="win"',
          {
          },
          {
            "actions": [
              {
                "action_name": "configure",
                "inputs": [],
                "outputs": [
                  "librdkafka/config.h",
                ],
                "action": [
                  "node", "../util/configure"
                ]
              },
              {
                "action_name": "build_dependencies",
                "inputs": [
                  "librdkafka/config.h",
                ],
                "action": [
                  "make", "-C", "librdkafka", "libs", "install"
                ],
                "conditions": [
                  [
                    'OS=="mac"',
                    {
                      'outputs': [
                        '../build/Release/librdkafka++.dylib',
                        '../build/Release/librdkafka++.1.dylib',
                        '../build/Release/librdkafka.dylib',
                        '../build/Release/librdkafka.1.dylib'
                      ],
                    },
                    {
                      'outputs': [
                        '../build/Release/librdkafka++.so',
                        '../build/Release/librdkafka++.so.1',
                        '../build/Release/librdkafka.so',
                        '../build/Release/librdkafka.so.1',
                      ],
                    }
                  ]
                ],
              }
            ]
          }

        ]
      ]
    }
  ]
}
