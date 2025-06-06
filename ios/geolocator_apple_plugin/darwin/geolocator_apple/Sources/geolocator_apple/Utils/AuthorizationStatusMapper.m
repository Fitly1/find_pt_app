//
//  CLAuthorizationStatusMapper.m
//  geolocator
//
//  Created by Maurits van Beusekom on 15/06/2020.
//

#import "../include/geolocator_apple/Utils/AuthorizationStatusMapper.h"

@implementation AuthorizationStatusMapper
+ (NSNumber *) toDartIndex: (CLAuthorizationStatus) authorizationStatus {
    switch (authorizationStatus) {
        case kCLAuthorizationStatusNotDetermined:
        case kCLAuthorizationStatusRestricted:
            return @0;
        case kCLAuthorizationStatusDenied:
            return @1;
#if TARGET_OS_IOS
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            return @2;
#endif
        case kCLAuthorizationStatusAuthorizedAlways:
            return @3;
        default:
            return @0;
    }
}
@end
