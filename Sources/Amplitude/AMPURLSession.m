//
//  AMPURLSession.m
//  Amplitude
//
//  Created by Daniel Jih on 9/14/17.
//  Copyright (c) 2017 Amplitude. All rights reserved.
//

#if AMPLITUDE_SSL_PINNING

#ifndef AMPLITUDE_DEBUG
#define AMPLITUDE_DEBUG 0
#endif

#ifndef AMPLITUDE_LOG
#if AMPLITUDE_DEBUG
#   define AMPLITUDE_LOG(fmt, ...) NSLog(fmt, ##__VA_ARGS__)
#else
#   define AMPLITUDE_LOG(...)
#endif
#endif

#import "AMPURLSession.h"
#import "AMPConstants.h"
#import "ISPCertificatePinning.h"
#import "ISPPinnedNSURLSessionDelegate.h"

@interface AMPURLSession ()

@end

@implementation AMPURLSession {
    NSURLSession *_sharedSession;
}

+ (AMPURLSession *)sharedSession {
    static AMPURLSession *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[AMPURLSession alloc] init];
    });
    return _instance;
}

- (instancetype)init {
    if ((self = [super init])) {
        [AMPURLSession pinSSLCertificate:@[@"ComodoRsaCA", @"ComodoRsaDomainValidationCA"]];
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _sharedSession = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    }
    return self;
}

+ (void)pinSSLCertificate:(NSArray *)certFilenames {
    // We pin the anchor/CA certificates
    NSMutableArray *certs = [NSMutableArray array];
    for (NSString *certFilename in certFilenames) {
        NSString *certPath =  [[NSBundle bundleForClass:[self class]] pathForResource:certFilename ofType:@"der"];
        NSData *certData = [[NSData alloc] initWithContentsOfFile:certPath];
        if (certData == nil) {
            AMPLITUDE_LOG(@"Failed to load a certificate");
            return;
        }
        [certs addObject:certData];
    }

    NSMutableDictionary *pins = [[NSMutableDictionary alloc] init];
    [pins setObject:certs forKey:kAMPEventLogDomain];

    if (pins == nil) {
        AMPLITUDE_LOG(@"Failed to pin a certificate");
        return;
    }

    // Save the SSL pins so that our connection delegates automatically use them
    if ([ISPCertificatePinning setupSSLPinsUsingDictionnary:pins] != YES) {
        AMPLITUDE_LOG(@"Failed to pin the certificates");
        return;
    }
}

- (void)dealloc {
    [_sharedSession finishTasksAndInvalidate];
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    return [_sharedSession dataTaskWithRequest:request completionHandler:completionHandler];
}

@end

#endif
