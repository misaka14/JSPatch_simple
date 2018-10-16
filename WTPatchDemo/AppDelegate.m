//
//  AppDelegate.m
//  WTPatchDemo
//
//  Created by 无头骑士 GJ on 2018/10/11.
//  Copyright © 2018 无头骑士 GJ. All rights reserved.
//

#import "AppDelegate.h"
#import "WTEngine.h"
#import "ViewController.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    
    [WTEngine startEngine];
    NSString *sourcePath = [[NSBundle mainBundle] pathForResource: @"demo" ofType: @"js"];
    NSString *script = [NSString stringWithContentsOfFile: sourcePath encoding: NSUTF8StringEncoding error: nil];
    [WTEngine evaluateScript:script];
    
    self.window = [[UIWindow alloc] initWithFrame: [UIScreen mainScreen].bounds];
    
    self.window.rootViewController = [[UINavigationController alloc] initWithRootViewController: [ViewController new]];
    
    [self.window makeKeyAndVisible];
    
    return YES;
}

@end
