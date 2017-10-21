//
//  ViewController.m
//  iRonSocket
//
//  Created by iRonCheng on 2017/10/20.
//  Copyright © 2017年 iRonCheng. All rights reserved.
//

#import "ViewController.h"
#import "iRonSocketHandler.h"

@interface ViewController () <iRonSocketHandlerDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /* 设置代理 */
    [[iRonSocketHandler shareInstance] setDelegate:self];
    [[iRonSocketHandler shareInstance] connectServerHost];
    
}

#pragma mark - iRonSocketHandlerDelegate

- (void)didReceiveMessage:(id)message
{
    
}

- (void)sendMessageTimeOutWithTag:(long)tag
{
    
}

@end
