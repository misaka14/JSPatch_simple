//
//  ViewController.m
//  WTPatchDemo
//
//  Created by 无头骑士 GJ on 2018/10/11.
//  Copyright © 2018 无头骑士 GJ. All rights reserved.
//

#import "ViewController.h"
#import "TestOneViewController.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    
    UIButton *btn = [UIButton buttonWithType: UIButtonTypeCustom];
    [btn addTarget: self action: @selector(handleBtn:) forControlEvents: UIControlEventTouchUpInside];
    [btn setTitle: @"ToToTestA" forState: UIControlStateNormal];
    [btn setTitleColor: [UIColor blackColor] forState: UIControlStateNormal];
    [self.view addSubview: btn];
    btn.frame = CGRectMake(100, 100, 100, 100);
}

//- (void)handleBtn:(UIButton *)btn
//{
//    [self.navigationController pushViewController: [TestOneViewController new] animated: YES];
//}
@end
