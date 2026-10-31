#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>

static NSString *kLicense = @"CITFS5ZJQ9C5TRYAJ1QAXINIPUEYYLOT|ZnSzMhnB37ILS4YjGiIXHwS8";
static NSString *kModelPath = @"/Library/Frameworks/TomatoOCR.framework/TomatoOCRModel.bundle";
static BOOL g_ready = NO;
static NSString *g_licenseResult = @"";
static NSInteger g_serverSocket = -1;

static void logLine(NSString *fmt, ...) {
    va_list args; va_start(args, fmt);
    NSString *line = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSLog(@"[TomatoOCR] %@", line);
}

static id tomatoCall(Class cls, SEL sel, ...) {
    va_list args; va_start(args, sel);
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[cls methodSignatureForSelector:sel]];
    [inv setTarget:cls];
    [inv setSelector:sel];
    NSUInteger count = [inv methodSignature].numberOfArguments;
    for (NSUInteger i = 2; i < count; i++) {
        void *arg = va_arg(args, void *);
        [inv setArgument:&arg atIndex:i];
    }
    va_end(args);
    [inv invoke];
    void *ret = NULL;
    if ([inv methodSignature].methodReturnLength > 0) {
        [inv getReturnValue:&ret];
    }
    return (__bridge id)ret;
}

static void ocrInit(void) {
    @autoreleasepool {
        @try {
            Class cls = NSClassFromString(@"TomatoOCR");
            if (!cls) { logLine(@"no TomatoOCR class"); return; }
            logLine(@"class found");

            tomatoCall(cls, @selector(init:), kModelPath, nil);
            logLine(@"init done");

            id lic = tomatoCall(cls, @selector(setLicense:remark:), kLicense, @"autotouch-tweak");
            g_licenseResult = [lic isKindOfClass:[NSString class]] ? lic : [NSString stringWithFormat:@"%@", lic];
            logLine(@"setLicense → %@", g_licenseResult);

            tomatoCall(cls, @selector(setRecType:), @"ch-3.0", nil);
            tomatoCall(cls, @selector(setReturnType:), @"json", nil);
            g_ready = YES;
        } @catch (NSException *e) {
            g_licenseResult = [NSString stringWithFormat:@"exception: %@", e.reason];
        }
    }
}

static NSString* handleRoute(NSString *path, NSString *query) {
    if ([path isEqualToString:@"/status"]) {
        return [NSString stringWithFormat:@"{\"ready\":%@,\"license\":\"%@\"}", g_ready ? @"true" : @"false", g_licenseResult];
    }
    if ([path isEqualToString:@"/ocr"]) {
        Class cls = NSClassFromString(@"TomatoOCR");
        if (!cls) return @"{\"error\":\"no class\"}";
        NSString *file = nil;
        NSArray *pairs = [query componentsSeparatedByString:@"&"];
        for (NSString *p in pairs) {
            NSArray *kv = [p componentsSeparatedByString:@"="];
            if (kv.count == 2 && [kv[0] isEqualToString:@"file"]) {
                file = [kv[1] stringByRemovingPercentEncoding];
            }
        }
        if (!file) return @"{\"error\":\"no file\"}";
        id result = tomatoCall(cls, @selector(ocrFile:type:), file, @(3));
        return [result isKindOfClass:[NSString class]] ? result : [NSString stringWithFormat:@"{\"error\":\"%@\"}", result];
    }
    return @"<h1>tomato-ocr</h1>";
}

static void startServer(void) {
    int s = socket(AF_INET, SOCK_STREAM, 0);
    if (s < 0) return;
    int yes = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(9999);
    addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    if (bind(s, (struct sockaddr*)&addr, sizeof(addr)) < 0) { close(s); return; }
    listen(s, 5);
    g_serverSocket = s;
    logLine(@"server listening 127.0.0.1:9999");

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        while (YES) {
            int c = accept(s, NULL, NULL);
            if (c < 0) break;
            char buf[8192] = {0};
            ssize_t n = recv(c, buf, sizeof(buf)-1, 0);
            if (n > 0) {
                NSString *req = [NSString stringWithUTF8String:buf];
                NSArray *lines = [req componentsSeparatedByString:@"\r\n"];
                if (lines.count > 0) {
                    NSArray *parts = [lines[0] componentsSeparatedByString:@" "];
                    if (parts.count >= 2) {
                        NSString *url = parts[1];
                        NSString *path = url;
                        NSString *query = @"";
                        NSRange q = [url rangeOfString:@"?"];
                        if (q.location != NSNotFound) {
                            path = [url substringToIndex:q.location];
                            query = [url substringFromIndex:q.location+1];
                        }
                        NSString *body = handleRoute(path, query);
                        NSString *resp = [NSString stringWithFormat:
                            @"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: %d\r\nAccess-Control-Allow-Origin: *\r\nConnection: close\r\n\r\n%@",
                            (int)[body lengthOfBytesUsingEncoding:NSUTF8StringEncoding], body];
                        send(c, [resp UTF8String], [resp lengthOfBytesUsingEncoding:NSUTF8StringEncoding], 0);
                    }
                }
            }
            close(c);
        }
    });
}

%ctor {
    @autoreleasepool {
        logLine(@"=== tomato-ocr-tweak loaded, waiting for app launch ===");
        // 等 AutoTouch 完全启动后再初始化（TomatoOCR.dylib 需要先加载完）
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                ocrInit();
                startServer();
            });
        }];
    }
}
