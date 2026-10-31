// ============================================================
//  tomato-ocr-daemon —— 独立 OCR 服务
//  编译时不链接 TomatoOCR，运行时 dlopen
// ============================================================
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <pthread.h>
#include <dlfcn.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>

static NSString *const kLogFile = @"/var/mobile/Library/Preferences/tomato-ocr-daemon.log";
static const int kPort = 9999;
static NSString *const kDylibPath = @"/Library/Frameworks/TomatoOCR.framework/TomatoOCR";
static NSString *const kModelPath = @"/Library/Frameworks/TomatoOCR.framework/TomatoOCRModel.bundle";
static NSString *const kLicense = @"CITFS5ZJQ9C5TRYAJ1QAXINIPUEYYLOT|ZnSzMhnB37ILS4YjGiIXHwS8";

static void logLine(NSString *fmt, ...) {
    va_list args; va_start(args, fmt);
    NSString *msg = [[NSString alloc] initWithFormat:fmt arguments:args];
    va_end(args);
    NSString *line = [NSString stringWithFormat:@"[%@] %@\n", [NSDate date], msg];
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:kLogFile];
    if (!fh) {
        [[NSFileManager defaultManager] createFileAtPath:kLogFile contents:nil attributes:nil];
        fh = [NSFileHandle fileHandleForWritingAtPath:kLogFile];
    }
    if (fh) { [fh seekToEndOfFile]; [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]]; [fh closeFile]; }
}

// 调类方法：[TomatoOCR performSelector:...] 简化
static id tomatoCall(Class cls, SEL sel, id arg1, id arg2) {
    if (!cls) return nil;
    NSMethodSignature *sig = [cls methodSignatureForSelector:sel];
    if (!sig) { logLine(@"no sel %@", NSStringFromSelector(sel)); return nil; }
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:cls];
    [inv setSelector:sel];
    NSUInteger idx = 2;
    if (arg1) [inv setArgument:&arg1 atIndex:idx++];
    if (arg2) [inv setArgument:&arg2 atIndex:idx++];
    [inv invoke];
    id ret = nil;
    if (sig.methodReturnLength == sizeof(id)) [inv getReturnValue:&ret];
    return ret;
}

static NSString *g_licenseResult = @"";
static BOOL g_ready = NO;

static void ocrInit(void) {
    @autoreleasepool {
        @try {
            void *h = dlopen([kDylibPath UTF8String], RTLD_NOW);
            if (!h) { logLine(@"dlopen failed: %s", dlerror()); return; }
            logLine(@"dlopen ok");
            Class cls = NSClassFromString(@"TomatoOCR");
            if (!cls) { logLine(@"no TomatoOCR class"); return; }
            logLine(@"class found");

            tomatoCall(cls, @selector(init:), kModelPath, nil);
            logLine(@"init done");

            id lic = tomatoCall(cls, @selector(setLicense:remark:), kLicense, @"tomato-ocr-daemon");
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

static void sendJson(int client, NSDictionary *json) {
    NSData *body = [NSJSONSerialization dataWithJSONObject:json options:0 error:nil];
    NSString *resp = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",
        (unsigned long)body.length];
    send(client, resp.UTF8String, strlen(resp.UTF8String), 0);
    send(client, body.bytes, body.length, 0);
    close(client);
}

static void sendRawJson(int client, NSString *jsonStr) {
    NSData *body = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    NSString *resp = [NSString stringWithFormat:
        @"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: %lu\r\nConnection: close\r\n\r\n",
        (unsigned long)body.length];
    send(client, resp.UTF8String, strlen(resp.UTF8String), 0);
    send(client, body.bytes, body.length, 0);
    close(client);
}

static void handleRequest(int client, NSString *request) {
    NSArray *lines = [request componentsSeparatedByString:@"\r\n"];
    if (lines.count == 0) return;
    NSArray *parts = [lines.firstObject componentsSeparatedByString:@" "];
    if (parts.count < 2) return;
    NSString *path = parts[1];
    NSURLComponents *uc = [NSURLComponents componentsWithString:[NSString stringWithFormat:@"http://localhost%@", path]];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    for (NSURLQueryItem *q in uc.queryItems) params[q.name] = q.value;

    if ([uc.path isEqualToString:@"/status"]) {
        sendJson(client, @{@"ready": @(g_ready), @"license": g_licenseResult});
    } else if ([uc.path isEqualToString:@"/ocr"]) {
        NSString *img = params[@"path"];
        if (!img || img.length == 0) { sendJson(client, @{@"error": @"missing path"}); return; }
        if (!g_ready) { sendJson(client, @{@"error": @"not ready", @"license": g_licenseResult}); return; }
        @try {
            Class cls = NSClassFromString(@"TomatoOCR");
            id r = tomatoCall(cls, @selector(ocrFile:type:), img, @3);
            NSString *s = [r isKindOfClass:[NSString class]] ? r : [NSString stringWithFormat:@"%@", r];
            sendRawJson(client, s ?: @"{}");
        } @catch (NSException *e) {
            sendJson(client, @{@"error": e.reason});
        }
    } else {
        sendJson(client, @{@"endpoints": @[@"/status", @"/ocr?path=xxx"]});
    }
}

static void *httpThread(void *arg) {
    int s = socket(AF_INET, SOCK_STREAM, 0);
    int yes = 1;
    setsockopt(s, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = inet_addr("127.0.0.1");
    addr.sin_port = htons(kPort);
    if (bind(s, (struct sockaddr *)&addr, sizeof(addr)) != 0) {
        logLine(@"bind %d failed: %s", kPort, strerror(errno));
        return NULL;
    }
    listen(s, 10);
    logLine(@"listening 127.0.0.1:%d", kPort);
    while (1) {
        int c = accept(s, NULL, NULL);
        if (c < 0) break;
        char buf[16384];
        ssize_t total = 0;
        while (total < (ssize_t)sizeof(buf) - 1) {
            ssize_t n = recv(c, buf + total, sizeof(buf) - 1 - total, 0);
            if (n <= 0) break;
            total += n;
            buf[total] = '\0';
            NSString *soFar = [NSString stringWithUTF8String:buf];
            NSRange he = [soFar rangeOfString:@"\r\n\r\n"];
            if (he.location == NSNotFound) continue;
            NSInteger cl = 0;
            for (NSString *hl in [[soFar substringToIndex:he.location] componentsSeparatedByString:@"\r\n"]) {
                if ([[hl lowercaseString] hasPrefix:@"content-length:"]) {
                    cl = [[[hl substringFromIndex:15] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] integerValue];
                    break;
                }
            }
            if (total >= (ssize_t)(he.location + 4 + cl)) break;
        }
        if (total > 0) { buf[total] = '\0'; handleRequest(c, [NSString stringWithUTF8String:buf]); }
        close(c);
    }
    return NULL;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        logLine(@"=== tomato-ocr-daemon starting ===");
        ocrInit();
        pthread_t tid;
        pthread_create(&tid, NULL, httpThread, NULL);
        [[NSRunLoop currentRunLoop] run];
    }
    return 0;
}
