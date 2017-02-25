#import "NotificationService.h"

@interface NotificationService ()

@property (nonatomic, strong) void (^contentHandler)(UNNotificationContent *contentToDeliver);
@property (nonatomic, strong) UNMutableNotificationContent *bestAttemptContent;

@end

@implementation NotificationService

- (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
    self.contentHandler = contentHandler;
    self.bestAttemptContent = [request.content mutableCopy];

    // Modify the notification content here...
    //self.bestAttemptContent.body = [NSString stringWithFormat:@"%@ [modified]", self.bestAttemptContent.body];

    // check for media attachment, example here uses custom payload keys mediaUrl and mediaType
    NSDictionary *userInfo = request.content.userInfo;
    if (userInfo == nil) {
        [self contentComplete];
        return;
    }

    NSString *mediaUrl = nil;
    NSString *mediaType = nil;
    NSDictionary *data = userInfo[@"data"];
    if (data == nil) {
        mediaUrl = userInfo[@"media-attachment-url"];
        mediaType = userInfo[@"mime-type"];
    } else {
        mediaUrl = data[@"media-attachment-url"];
        mediaType = data[@"mime-type"];
    }

    if (mediaUrl == nil) {
        [self contentComplete];
        return;
    }

    // load the attachment
    [self loadAttachmentForUrlString:mediaUrl
                            withType:mediaType
                   completionHandler:^(UNNotificationAttachment *attachment) {
                       if (attachment) {
                           self.bestAttemptContent.attachments = [NSArray arrayWithObject:attachment];
                       }
                       [self contentComplete];
                   }];

}

- (void)serviceExtensionTimeWillExpire {
    // Called just before the extension will be terminated by the system.
    // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
    [self contentComplete];
}

- (void)contentComplete {
    self.contentHandler(self.bestAttemptContent);
}

- (NSString *)fileExtensionForMediaType:(NSString *)type {
    NSString *ext = nil;

    if ([type isEqualToString:@"image/jpeg"]) {
        ext = @".jpg";
    } else if ([type isEqualToString:@"image/gif"]) {
        ext = @".gif";
    } else if ([type isEqualToString:@"image/png"]) {
        ext = @".png";
    } else if ([type isEqualToString:@"video/mpeg"]) {
        ext = @".mpg";
    } else if ([type isEqualToString:@"video/avi"]) {
        ext = @".avi";
    } else if ([type isEqualToString:@"audio/aiff"]) {
        ext = @".aiff";
    } else if ([type isEqualToString:@"audio/wav"]) {
        ext = @".wav";
    } else if ([type isEqualToString:@"audio/mpeg3"]) {
        ext = @".mp3";
    }

    return ext;
}

- (void)loadAttachmentForUrlString:(NSString *)urlString withType:(NSString *)mediaType completionHandler:(void(^)(UNNotificationAttachment *))completionHandler  {

    __block UNNotificationAttachment *attachment = nil;
    NSURL *attachmentURL = [NSURL URLWithString:urlString];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    [[session downloadTaskWithURL:attachmentURL
                completionHandler:^(NSURL *temporaryFileLocation, NSURLResponse *response, NSError *error) {
                    if (error != nil) {
                        NSLog(@"%@", error.localizedDescription);
                    } else {
                        // determine file extension
                        NSString *fileExt = [self fileExtensionForMediaType:[response MIMEType]];
                        if (fileExt == nil) {
                            fileExt = [self fileExtensionForMediaType:mediaType];
                            if (fileExt == nil) {
                                fileExt = [@"." stringByAppendingString:[[response URL] pathExtension]];
                            }
                        }

                        NSFileManager *fileManager = [NSFileManager defaultManager];
                        NSURL *localURL = [NSURL fileURLWithPath:[temporaryFileLocation.path stringByAppendingString:fileExt]];
                        [fileManager moveItemAtURL:temporaryFileLocation toURL:localURL error:&error];

                        NSError *attachmentError = nil;
                        attachment = [UNNotificationAttachment attachmentWithIdentifier:@"" URL:localURL options:nil error:&attachmentError];
                        if (attachmentError) {
                            NSLog(@"%@", attachmentError.localizedDescription);
                        }
                    }
                    completionHandler(attachment);
                }] resume];
}
@end
