Ach so! for iOS
===============

## Setup

This project uses [CocoaPods][cocoapods], but does not include the `Pods/` directory, so start with:

```bash
cd xcode/achso
pod install
```

You also need `Secrets.plist` for secret keys.

After that open the _workspace_ to work with CocoaPods.

## Related repositories

- Android version: [learning-layers/AchSo](https://github.com/learning-layers/achso)
- Backend server: [learning-layers/achrails](https://github.com/learning-layers/achrails)

[cocoapods]: https://cocoapods.org

## URI scheme

Ach so! for iOS supports an `achso://` URI-scheme for launching.

The base format is `achso://$BOX_URL` where `$BOX_URL` is the host of the Layers Box,
it can also be `public` to connect to the public servers.

```
# Open the app and show all videos
achso://$BOX_URL
achso://$BOX_URL/videos/

# Show video with ID
achso://$BOX_URL/videos/$ID

# Record a new video
achso://$BOX_URL/record
```

## Development:

- Samuli Raivio (@bqqbarbhg)

based on [learning-layers/AchSo](https://github.com/learning-layers/achso), see readme.md there for original authors and design. 

Licence
-------

```
Copyright 2015-2016 Aalto University

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
