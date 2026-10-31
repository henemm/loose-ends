#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface FakeTask : NSObject
@end
// Same shape as BGTaskScheduler.registerForTaskWithIdentifier:usingQueue:launchHandler:
@interface FakeScheduler : NSObject
+ (FakeScheduler *)sharedScheduler;
- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier usingQueue:(nullable dispatch_queue_t)queue launchHandler:(void (^)(FakeTask *task))launchHandler NS_SWIFT_NAME(register(forTaskWithIdentifier:using:launchHandler:));
- (void)fire;
@end
NS_ASSUME_NONNULL_END
