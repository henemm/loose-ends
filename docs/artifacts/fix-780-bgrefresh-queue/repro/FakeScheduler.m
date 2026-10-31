#import "FakeScheduler.h"
@implementation FakeTask
@end
@implementation FakeScheduler {
    dispatch_queue_t _queue;
    void (^_handler)(FakeTask *);
}
+ (FakeScheduler *)sharedScheduler { static FakeScheduler *s; static dispatch_once_t o; dispatch_once(&o, ^{ s = [FakeScheduler new]; }); return s; }
- (BOOL)registerForTaskWithIdentifier:(NSString *)identifier usingQueue:(dispatch_queue_t)queue launchHandler:(void (^)(FakeTask *))launchHandler {
    _queue = queue ?: dispatch_queue_create("fake.background", DISPATCH_QUEUE_SERIAL);
    _handler = [launchHandler copy];
    return YES;
}
- (void)fire { FakeTask *t = [FakeTask new]; void (^h)(FakeTask *) = _handler; dispatch_async(_queue, ^{ h(t); }); }
@end
