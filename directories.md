# achso\_ios file overview

This is an overview over the files in achso\_ios.

Note: This is automatically generated from `directories.md` so changes may get overwritten.

## entities/

These are data structures used in the code.

#### @parse(src/entities/*.swift)

## player/

This is the player activity of the app. It is a single view with many custom view and layer types.

#### @parse(src/player/*.swift)

## broswer/

This is the main activity of the app. It is based on a split view, but mostly only the `VideosViewController` is visible.

#### @parse(src/browser/*.swift)

## backend/

Here is code that communicates with external servers. `VideoRepository` contains most of the logic. Other files are mostly wrappers for service APIs.

#### @parse(src/backend/*.swift)

## lib/

### net/

Defines functionality for connecting to remote servers securely.

HTTP requests are done with [Alamofire](https://github.com/Alamofire/Alamofire) and the types it defines are used in the API for convenience.

#### @parse(src/lib/net/*.swift)

### misc/

Miscellaneous classes and utilities that are mostly contained in a single source file.

#### @parse(src/lib/misc/*.swift)

### helpers/

These are _helper_ files, that mostly wrap verbose or otherwise lousy APIs with simpler ones.
These should not define any big concepts or behaviour.

#### @parse(src/lib/helpers/*.swift)

### extensions/

Miscellaneous helper extension methods for existing objects.

#### @parse(src/lib/extensions/*.swift)

