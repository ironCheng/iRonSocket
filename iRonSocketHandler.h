//
//  iRonSocketHandler.h
//  iRonSocket
//
//  Created by iRonCheng on 2017/10/21.
//  Copyright © 2017年 iRonCheng. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SocketConnectStatus) {
    SocketConnectStatusUnConnect = 0,
    SocketConnectStatusConnected,
    SocketConnectStatusUnknow
};


@protocol iRonSocketHandlerDelegate <NSObject>

@required

/* 接收消息 */
- (void)didReceiveMessage:(id)message;

@optional

/* 消息发送超时 */
- (void)sendMessageTimeOutWithTag:(long)tag;

@end


@interface iRonSocketHandler : NSObject


/* socket连接状态 */
@property (nonatomic, assign, readonly) SocketConnectStatus connectStatus;

@property (nonatomic, weak) id <iRonSocketHandlerDelegate> delegate;

+ (instancetype)shareInstance;

/* 连接服务器 */
- (void)connectServerHost;

/* 断开连接 */
- (void)disconnectServerHost;

/* 发送消息 */
- (void)sendMessage:(id)message timeOut:(NSUInteger)timeOut tag:(long)tag;



@end
