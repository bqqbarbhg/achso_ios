import Foundation

enum PlayerUserEvent {
    case SeekPreview(Double)
    case SeekTo(Double)
    case SeekCancel
    case PlayPause
}
