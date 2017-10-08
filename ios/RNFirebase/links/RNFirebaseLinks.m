#import "RNFirebaseLinks.h"

#if __has_include(<FirebaseDynamicLinks/FIRDynamicLink.h>)
#import "RNFirebaseEvents.h"


static void sendDynamicLink(NSURL *url, id sender) {
    [[NSNotificationCenter defaultCenter] postNotificationName:LINKS_DYNAMIC_LINK_RECEIVED
                                                        object:sender
                                                      userInfo:@{@"url": url.absoluteString}];
    NSLog(@"sendDynamicLink Success: %@", url.absoluteString);
}

@implementation RNFirebaseLinks

RCT_EXPORT_MODULE();

- (id)init {
    self = [super init];
    if (self != nil) {
        NSLog(@"Setting up RNFirebaseLinks instance");
        [self initialiseLinks];
    }
    return self;
}

- (void)initialiseLinks {
    // Set up internal listener to send notification over bridge
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(sendDynamicLinkEvent:)
                                                 name:LINKS_DYNAMIC_LINK_RECEIVED
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

+ (BOOL)application:(UIApplication *)app
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    return [self handleLinkFromCustomSchemeURL:url];
}

+ (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
  sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    return [self handleLinkFromCustomSchemeURL:url];
}

+(BOOL)handleLinkFromCustomSchemeURL:(NSURL *)url {
    FIRDynamicLink *dynamicLink =
    [[FIRDynamicLinks dynamicLinks] dynamicLinkFromCustomSchemeURL:url];
    if (dynamicLink) {
        sendDynamicLink(dynamicLink.url, self);
        return YES;
    }
    return NO;
}

+ (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
 restorationHandler:(void (^)(NSArray *))restorationHandler {
    BOOL handled = [[FIRDynamicLinks dynamicLinks]
                    handleUniversalLink:userActivity.webpageURL
                    completion:^(FIRDynamicLink * _Nullable dynamicLink, NSError * _Nullable error) {
                        if (error != nil){
                            NSLog(@"Failed to handle universal link: %@", [error localizedDescription]);
                        }
                        else {
                            if ([userActivity.activityType isEqualToString:NSUserActivityTypeBrowsingWeb]) {
                                NSURL* url = dynamicLink ? dynamicLink.url : userActivity.webpageURL;
                                sendDynamicLink(url, self);
                            }
                        }
                    }];
    return handled;
}

- (NSArray<NSString *> *)supportedEvents {
    return @[LINKS_DYNAMIC_LINK_RECEIVED];
}

- (void)sendDynamicLinkEvent:(NSNotification *)notification {
    [self sendEventWithName:LINKS_DYNAMIC_LINK_RECEIVED body:notification.userInfo[@"url"]];
}

-(void)handleInitialLinkFromCustomSchemeURL:(NSURL*)url resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    FIRDynamicLink *dynamicLink =
    [[FIRDynamicLinks dynamicLinks] dynamicLinkFromCustomSchemeURL:url];
    NSString* urlString = dynamicLink ? dynamicLink.url.absoluteString : (id)kCFNull;
    NSLog(@"initial link is: %@", urlString);
    resolve(urlString);
}

-(void)handleInitialLinkFromUniversalLinkURL:(NSDictionary *)userActivityDictionary resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject {
    NSUserActivity* userActivity = (NSUserActivity*) userActivityDictionary[@"UIApplicationLaunchOptionsUserActivityKey"];
    if ([userActivityDictionary[UIApplicationLaunchOptionsUserActivityTypeKey] isEqual:NSUserActivityTypeBrowsingWeb])
    {
        [[FIRDynamicLinks dynamicLinks]
         handleUniversalLink:userActivity.webpageURL
         completion:^(FIRDynamicLink * _Nullable dynamicLink, NSError * _Nullable error) {
             if (error != nil){
                 NSLog(@"Failed to handle universal link: %@", [error localizedDescription]);
                 reject(@"links/failure", @"Failed to handle universal link", error);
             }
             else {
                 NSString* urlString = dynamicLink ? dynamicLink.url.absoluteString : userActivity.webpageURL.absoluteString;
                 NSLog(@"initial link is: %@", urlString);
                 resolve(urlString);
             }
         }];
    }
    else {
        NSLog(@"no initial link");
        resolve((id)kCFNull);
    }
}

RCT_EXPORT_METHOD(getInitialLink:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    if (self.bridge.launchOptions[UIApplicationLaunchOptionsURLKey]) {
        NSURL* url = (NSURL*)self.bridge.launchOptions[UIApplicationLaunchOptionsURLKey];
        [self handleInitialLinkFromCustomSchemeURL:url resolver:resolve rejecter:reject];
        
    } else {
        NSDictionary *userActivityDictionary =
        self.bridge.launchOptions[UIApplicationLaunchOptionsUserActivityDictionaryKey];
        [self handleInitialLinkFromUniversalLinkURL:userActivityDictionary resolver:resolve rejecter:reject];
    }
}

RCT_EXPORT_METHOD(createDynamicLink: (NSDictionary *) metadata resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        FIRDynamicLinkComponents *components = [self getDynamicLinkComponentsFromMetadata:metadata];
        
        if (components == nil) {
            reject(@"links/failure", @"Failed to create Dynamic Link", nil);
        } else {
            NSURL *longLink =  components.url;
            NSLog(@"created long dynamic link: %@", longLink.absoluteString);
            resolve(longLink.absoluteString);
        }
    }
    @catch(NSException * e) {
        NSLog(@"create dynamic link failure %@", e);
        reject(@"links/failure",[e reason], nil);
    }
}

RCT_EXPORT_METHOD(createShortDynamicLink: (NSDictionary *) metadata resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject) {
    @try {
        FIRDynamicLinkComponents *components = [self getDynamicLinkComponentsFromMetadata:metadata];
        [self setSuffixParameters:metadata components:components];
        [components shortenWithCompletion:^(NSURL *_Nullable shortURL,
                                            NSArray *_Nullable warnings,
                                            NSError *_Nullable error) {
            if (error) {
                NSLog(@"create short dynamic link failure %@", [error localizedDescription]);
                reject(@"links/failure", @"Failed to create Short Dynamic Link", error);
            }
            NSURL *shortLink = shortURL;
            NSLog(@"created short dynamic link: %@", shortLink.absoluteString);
            resolve(shortLink.absoluteString);
        }];
    }
    @catch(NSException * e) {
        NSLog(@"create short dynamic link failure %@", e);
        reject(@"links/failure",[e reason], nil);
    }
}

- (FIRDynamicLinkComponents *)getDynamicLinkComponentsFromMetadata:(NSDictionary *)metadata {
    NSMutableDictionary* dynamicLinkInfoMetadata = metadata[@"dynamicLinkInfo"];
    @try {
        NSURL *link = [NSURL URLWithString:dynamicLinkInfoMetadata[@"link"]];
        [dynamicLinkInfoMetadata removeObjectForKey:@"link"];
        
        FIRDynamicLinkComponents *components =
        [FIRDynamicLinkComponents componentsWithLink:link domain:dynamicLinkInfoMetadata[@"dynamicLinkDomain"]];
        [dynamicLinkInfoMetadata removeObjectForKey:@"dynamicLinkDomain"];
        
        [self setAndroidParameters:dynamicLinkInfoMetadata components:components];
        [dynamicLinkInfoMetadata removeObjectForKey:@"androidInfo"];
        
        [self setIosParameters:dynamicLinkInfoMetadata components:components];
        [dynamicLinkInfoMetadata removeObjectForKey:@"iosInfo"];
        
        [self setSocialMetaTagParameters:dynamicLinkInfoMetadata components:components];
        [dynamicLinkInfoMetadata removeObjectForKey:@"socialMetaTagInfo"];
        
        if ([dynamicLinkInfoMetadata count] > 0) {
            @throw [NSException
                    exceptionWithName:@"Invalid arguments"
                    reason:@"Invalid arguments"
                    userInfo:nil];
        }
        return components;
    }
    @catch(NSException * e) {
        NSLog(@"error while building componets from meta data %@", e);
        @throw;
    }
}

- (void)setAndroidParameters:(NSMutableDictionary *)metadata
                  components:(FIRDynamicLinkComponents *)components {
    NSMutableDictionary *androidParametersDict = metadata[@"androidInfo"];
    if (androidParametersDict) {
        if (!androidParametersDict[@"androidPackageName"]) {
            @throw [NSException
                    exceptionWithName:@"Invalid arguments"
                    reason:@"no androidPackageName was specified"
                    userInfo:nil];
        }
        FIRDynamicLinkAndroidParameters *androidParams = [FIRDynamicLinkAndroidParameters
                                                          parametersWithPackageName: androidParametersDict[@"androidPackageName"]];
        [androidParametersDict removeObjectForKey:@"androidPackageName"];
        
        if (androidParametersDict[@"androidFallbackLink"]) {
            androidParams.fallbackURL = [NSURL URLWithString:androidParametersDict[@"androidFallbackLink"]];
            [androidParametersDict removeObjectForKey:@"androidFallbackLink"];
        }
        if (androidParametersDict[@"androidMinPackageVersionCode"]) {
            androidParams.minimumVersion = [androidParametersDict[@"androidMinPackageVersionCode"] integerValue];
            [androidParametersDict removeObjectForKey:@"androidMinPackageVersionCode"];
            
        }
        if ([androidParametersDict count] > 0) {
            @throw [NSException
                    exceptionWithName:@"Invalid arguments"
                    reason:@"Invalid arguments"
                    userInfo:nil];
        }
        components.androidParameters = androidParams;
    }
}

- (void)setIosParameters:(NSMutableDictionary *)metadata
              components:(FIRDynamicLinkComponents *)components {
    NSMutableDictionary *iosParametersDict = metadata[@"iosInfo"];
    if (iosParametersDict) {
        if (!iosParametersDict[@"iosBundleId"]) {
            @throw [NSException
                    exceptionWithName:@"Invalid arguments"
                    reason:@"no iosBundleId was specified"
                    userInfo:nil];
        }
        FIRDynamicLinkIOSParameters *iOSParams = [FIRDynamicLinkIOSParameters
                                                  parametersWithBundleID:iosParametersDict[@"iosBundleId"]];
        [iosParametersDict removeObjectForKey:@"iosBundleId"];
        if (iosParametersDict[@"iosAppStoreId"]) {
            iOSParams.appStoreID = iosParametersDict[@"iosAppStoreId"];
            [iosParametersDict removeObjectForKey:@"iosAppStoreId"];
        }
        if (iosParametersDict[@"iosCustomScheme"]) {
            iOSParams.customScheme = iosParametersDict[@"iosCustomScheme"];
            [iosParametersDict removeObjectForKey:@"iosCustomScheme"];
        }
        if (iosParametersDict[@"iosFallbackLink"]) {
            iOSParams.fallbackURL = [NSURL URLWithString:iosParametersDict[@"iosFallbackLink"]];
            [iosParametersDict removeObjectForKey:@"iosFallbackLink"];
        }
        if (iosParametersDict[@"iosIpadBundleId"]) {
            iOSParams.iPadBundleID = iosParametersDict[@"iosIpadBundleId"];
            [iosParametersDict removeObjectForKey:@"iosIpadBundleId"];
        }
        if (iosParametersDict[@"iosIpadFallbackLink"]) {
            iOSParams.iPadFallbackURL = [NSURL URLWithString:iosParametersDict[@"iosIpadFallbackLink"]];
            [iosParametersDict removeObjectForKey:@"iosIpadFallbackLink"];
        }
        if (iosParametersDict[@"iosMinPackageVersionCode"]) {
            iOSParams.minimumAppVersion = iosParametersDict[@"iosMinPackageVersionCode"];
            [iosParametersDict removeObjectForKey:@"iosMinPackageVersionCode"];
        }
        
        if ([iosParametersDict count] > 0) {
            @throw [NSException
                    exceptionWithName:@"Invalid arguments"
                    reason:@"Invalid arguments"
                    userInfo:nil];
        }
        components.iOSParameters = iOSParams;
    }
}

- (void)setSocialMetaTagParameters:(NSMutableDictionary *)metadata
                        components:(FIRDynamicLinkComponents *)components {
    NSMutableDictionary *socialParamsDict = metadata[@"socialMetaTagInfo"];
    if (socialParamsDict) {
        FIRDynamicLinkSocialMetaTagParameters *socialParams = [FIRDynamicLinkSocialMetaTagParameters parameters];
        if (socialParamsDict[@"socialTitle"]) {
            socialParams.title = socialParamsDict[@"socialTitle"];
            [socialParamsDict removeObjectForKey:@"socialTitle"];
        }
        if (socialParamsDict[@"socialDescription"]) {
            socialParams.descriptionText = socialParamsDict[@"socialDescription"];
            [socialParamsDict removeObjectForKey:@"socialDescription"];
        }
        if (socialParamsDict[@"socialImageLink"]) {
            socialParams.imageURL = [NSURL URLWithString:socialParamsDict[@"socialImageLink"]];
            [socialParamsDict removeObjectForKey:@"socialImageLink"];
        }
        if ([socialParamsDict count] > 0) {
            @throw [NSException
                    exceptionWithName:@"Invalid arguments"
                    reason:@"Invalid arguments"
                    userInfo:nil];
        }
        components.socialMetaTagParameters = socialParams;
    }
}

- (void)setSuffixParameters:(NSDictionary *)metadata
                 components:(FIRDynamicLinkComponents *)components {
    NSDictionary *suffixParametersDict = metadata[@"suffix"];
    if (suffixParametersDict) {
        FIRDynamicLinkComponentsOptions *options = [FIRDynamicLinkComponentsOptions options];
        if ([suffixParametersDict[@"option"]  isEqual: @"SHORT"]) {
            options.pathLength = FIRShortDynamicLinkPathLengthShort;
        }
        else if ([suffixParametersDict[@"option"]  isEqual: @"UNGUESSABLE"]) {
            options.pathLength = FIRShortDynamicLinkPathLengthUnguessable;
        }
        components.options = options;
    }
}

@end

#else
@implementation RNFirebaseLinks
@end
#endif
