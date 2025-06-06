//
//  PositionStreamHandler.h
//  Pods
//
//  Created by Maurits van Beusekom on 04/06/2021.
//

#ifndef PositionStreamHandler_h
#define PositionStreamHandler_h

#if TARGET_OS_OSX
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
#endif
#import "GeolocationHandler.h"

@interface PositionStreamHandler : NSObject<FlutterStreamHandler>

- (id) initWithGeolocationHandler: (GeolocationHandler *)geolocationHandler;

@end

#endif /* PositionStreamHandler_h */
