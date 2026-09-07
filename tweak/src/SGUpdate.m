// The site's version.json, so a build that is already on someone's phone can tell them a newer one
// exists. Fetched when the Mod Settings page opens, at most once every six hours, and on demand
// from the Updates row; the reply is a static file and nothing but the request itself leaves.
#import "SGCommon.h"

NSString *const SGSiteURL = @"https://spoti.pw";
NSString *const SGRepoURL = @"https://github.com/CHANGEME/CHANGEME";
NSString *const SGChatURL = @"https://t.me/CHANGEME";
NSString *const SGUpdateURL = @"https://spoti.pw/version.json";

static NSString *const kChecked = @"spotifyglass.update.checked";
static NSString *const kLatest = @"spotifyglass.update.latest";
static NSString *const kNotes = @"spotifyglass.update.notes";
static const NSTimeInterval kInterval = 6 * 60 * 60;

static NSString *sg_failure;
static BOOL sg_running;

// "0.14.1" against "0.15": the numbers position by position, a missing one counting zero.
static BOOL isNewer(NSString *candidate, NSString *current) {
    NSArray<NSString *> *left = [candidate componentsSeparatedByString:@"."];
    NSArray<NSString *> *right = [current componentsSeparatedByString:@"."];
    for (NSUInteger i = 0; i < MAX(left.count, right.count); i++) {
        NSInteger a = i < left.count ? left[i].integerValue : 0;
        NSInteger b = i < right.count ? right[i].integerValue : 0;
        if (a != b) return a > b;
    }
    return NO;
}

NSString *SGUpdateVersion(void) {
    NSString *latest = [NSUserDefaults.standardUserDefaults stringForKey:kLatest];
    return latest && isNewer(latest, @(SG_VERSION)) ? latest : nil;
}

NSString *SGUpdateNotes(void) {
    return [NSUserDefaults.standardUserDefaults stringForKey:kNotes] ?: @"";
}

// What the Updates row shows on the right; the page's own ticker reads it while the page is open,
// so the async check lands in the cell without anything having to be told about it.
NSString *SGUpdateStatus(void) {
    if (sg_running) return @"checking…";
    if (sg_failure) return sg_failure;
    NSString *latest = SGUpdateVersion();
    if (latest) return [latest stringByAppendingString:@" is out"];
    if ([NSUserDefaults.standardUserDefaults doubleForKey:kChecked] > 0) return @"up to date";
    return @"not checked";
}

void SGCheckForUpdate(BOOL force) {
    NSUserDefaults *store = NSUserDefaults.standardUserDefaults;
    NSTimeInterval last = [store doubleForKey:kChecked];
    if (sg_running) return;
    if (!force && last > 0 && NSDate.date.timeIntervalSince1970 - last < kInterval) return;

    sg_running = YES;
    sg_failure = nil;
    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.timeoutIntervalForRequest = 10;
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:SGUpdateURL]
                                             cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                         timeoutInterval:10];
    NSURLSessionDataTask *task = [[NSURLSession sessionWithConfiguration:configuration]
        dataTaskWithRequest:request
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        if (![json isKindOfClass:NSDictionary.class]) json = nil;
        NSString *version = [json[@"version"] isKindOfClass:NSString.class] ? json[@"version"] : nil;
        NSString *notes = [json[@"notes"] isKindOfClass:NSString.class] ? json[@"notes"] : @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            sg_running = NO;
            if (!version) {
                sg_failure = @"check failed";
                SGLog(@"update check failed: %@", error.localizedDescription ?: @"no version in the reply");
                return;
            }
            [store setObject:version forKey:kLatest];
            [store setObject:notes forKey:kNotes];
            [store setDouble:NSDate.date.timeIntervalSince1970 forKey:kChecked];
            SGLog(@"update check: the site has %@, this build is %s", version, SG_VERSION);
        });
    }];
    [task resume];
}

void SGOpenURL(NSString *url) {
    NSURL *target = url ? [NSURL URLWithString:url] : nil;
    if (!target) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIApplication.sharedApplication openURL:target options:@{} completionHandler:nil];
    });
}
