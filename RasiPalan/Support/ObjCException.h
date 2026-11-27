#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block`, returning the Objective-C exception it raised, or nil. Swift cannot catch these,
/// and some framework calls (AVAudioPlayerNode.play when the engine has just stopped) raise them.
NSException * _Nullable RPCatchObjCException(NS_NOESCAPE void (^block)(void));

NS_ASSUME_NONNULL_END
