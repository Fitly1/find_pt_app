// Copyright 2021 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <FirebaseAuth/FirebaseAuth.h>
#import <FlutterMacOS/FlutterMacOS.h>
#else
#import <Flutter/Flutter.h>
@import FirebaseAuth;
#endif

#import <Foundation/Foundation.h>
#import "../Public/CustomPigeonHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface FLTAuthStateChannelStreamHandler : NSObject <FlutterStreamHandler>

- (instancetype)initWithAuth:(FIRAuth *)auth;

@end

NS_ASSUME_NONNULL_END
