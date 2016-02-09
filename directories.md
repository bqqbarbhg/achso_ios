
## entities/

These are data structures used in the code.

#### @parse(src/entities/VideoInfo.swift)
#### @parse(src/entities/Video.swift)
#### @parse(src/entities/ActiveVideo.swift)
#### @parse(src/entities/ActiveVideoState.swift)
#### @parse(src/entities/Annotation.swift)
#### @parse(src/entities/AnnotationBatch.swift)
#### @parse(src/entities/User.swift)
#### @parse(src/entities/Group.swift)
#### @parse(src/entities/GroupList.swift)
#### @parse(src/entities/Genre.swift)

## player/

This is the player activity of the app. It is a single view with many custom view and layer types.

#### @parse(src/player/PlayerViewController.swift)
#### @parse(src/player/PlayerController.swift)
#### @parse(src/player/VideoView.swift)
#### @parse(src/player/VideoPlayer.swift)
#### @parse(src/player/AVPlayerView.swift)
#### @parse(src/player/AnnotationImages.swift)
#### @parse(src/player/SeekBarView.swift)
#### @parse(src/player/SeekBarLayer.swift)
#### @parse(src/player/SeekAnnotationLayer.swift)
#### @parse(src/player/PlayButtonView.swift)
#### @parse(src/player/PlayButtonLayer.swift)
#### @parse(src/player/AnnotationWaitBarView.swift)

## broswer/

This is the main activity of the app. It is based on a split view, but mostly only the `VideosViewController` is visible.

#### @parse(src/browser/VideosViewController.swift)
#### @parse(src/browser/VideoCellView.swift)
#### @parse(src/browser/GradientLayer.swift)
#### @parse(src/browser/CategoriesViewController.swift)
#### @parse(src/browser/Collection.swift)
#### @parse(src/browser/SharesViewController.swift)
#### @parse(src/browser/VideoDetailsViewController.swift)
#### @parse(src/browser/QRScanViewController.swift)

## backend/

Here is code that communicates with external servers. `VideoRepository` contains most of the logic. Other files are mostly wrappers for service APIs.

#### @parse(src/backend/VideoRepository.swift)
#### @parse(src/backend/AchRails.swift)
#### @parse(src/backend/Uploader.swift)
#### @parse(src/backend/AchMinUpUploader.swift)

## lib/

### net/

Defines functionality for connecting to remote servers securely.

HTTP requests are done with [Alamofire](https://github.com/Alamofire/Alamofire) and the types it defines are used in the API for convenience.

#### @parse(src/lib/net/Alamotypes.swift)
#### @parse(src/lib/net/HTTPRequest.swift)
#### @parse(src/lib/net/OAuth2.swift)
#### @parse(src/lib/net/AuthenticatedHTTP.swift)
#### @parse(src/lib/net/AuthUser.swift)

### misc/

Miscellaneous classes and utilities that are mostly contained in a single source file.

#### @parse(src/lib/misc/Errors.swift)
#### @parse(src/lib/misc/LocationRetriever.swift)
#### @parse(src/lib/misc/Search.swift)
#### @parse(src/lib/misc/Tasks.swift)
#### @parse(src/lib/misc/Secrets.swift)

### helpers/

These are _helper_ files, that mostly wrap verbose or otherwise lousy APIs with simpler ones.
These should not define any big concepts or behaviour.

#### @parse(src/lib/helpers/Vector2.swift)
#### @parse(src/lib/helpers/MathHelper.swift)
#### @parse(src/lib/helpers/GradientHelper.swift)
#### @parse(src/lib/helpers/DateHelper.swift)
#### @parse(src/lib/helpers/AVHelper.swift)
#### @parse(src/lib/helpers/JsonHelper.swift)
#### @parse(src/lib/helpers/HexColor.swift)
#### @parse(src/lib/helpers/ImageLoader.swift)

### extensions/

Miscellaneous helper extension methods for existing objects.

#### @parse(src/lib/extensions/ArrayExtension.swift)
#### @parse(src/lib/extensions/CGColorExtension.swift)
#### @parse(src/lib/extensions/CGRectExtension.swift)
#### @parse(src/lib/extensions/CGSizeExtension.swift)
#### @parse(src/lib/extensions/NSDateExtension.swift)
#### @parse(src/lib/extensions/NSURLExtension.swift)
#### @parse(src/lib/extensions/NSUUIDExtension.swift)
#### @parse(src/lib/extensions/OptionalExtension.swift)
#### @parse(src/lib/extensions/UIViewControllerExtension.swift)

