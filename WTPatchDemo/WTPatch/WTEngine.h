//
//  WTEngine.h
//  WTPatchDemo
//
//  Created by 无头骑士 GJ on 2018/10/11.
//  Copyright © 2018 无头骑士 GJ. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface WTEngine : NSObject

+ (void)startEngine;

+ (JSValue *)evaluateScript:(NSString *)script;

@end

@interface WTBoxing : NSObject

@property (nonatomic, weak) id weakObj;

@end

NS_ASSUME_NONNULL_END
