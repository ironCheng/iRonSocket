//
//  iRonSocketHandler.m
//  iRonSocket
//
//  Created by iRonCheng on 2017/10/21.
//  Copyright © 2017年 iRonCheng. All rights reserved.
//

#import "iRonSocketHandler.h"
#import "GCDAsyncSocket.h"
//#import "GCDAsyncUdpSocket.h"

//自动重连次数
NSInteger autoConnectCount = 3;

@interface iRonSocketHandler () <GCDAsyncSocketDelegate>

/* socket */
@property (nonatomic, strong) GCDAsyncSocket *tcpSocket;

//心跳定时器
@property (nonatomic, strong) dispatch_source_t beatTimer;
//发送心跳次数
@property (nonatomic, assign) NSInteger senBeatCount;

@end

@implementation iRonSocketHandler

+ (instancetype)shareInstance
{
    static iRonSocketHandler *handler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        handler = [[iRonSocketHandler alloc] init];
    });
    return handler;
}

- (instancetype)init
{
    if (self = [super init]) {
        /* 初始化socket 设置delegate */
        _tcpSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
        //设置默认关闭读取
        [_tcpSocket setAutoDisconnectOnClosedReadStream:NO];
        //默认状态未连接
        _connectStatus = SocketConnectStatusUnConnect;
    }
    return self;
}

#pragma mark - Public Method

/* 连接服务器 */
- (void)connectServerHost
{
    NSError *error = nil;
    [_tcpSocket connectToHost:@"服务器IP" onPort:8080 error:&error];
    if (error) {
        NSLog(@"----------------连接服务器失败----------------");
    }else{
        NSLog(@"----------------连接服务器成功----------------");
    }
}

/* 断开连接 */
- (void)disconnectServerHost
{
    //更新sokect连接状态
    _connectStatus = SocketConnectStatusUnConnect;
    [self disconnect];
}

/* 发送消息 */
- (void)sendMessage:(id)message timeOut:(NSUInteger)timeOut tag:(long)tag
{
    if (![message isKindOfClass:[NSString class]]) {
        
    }
    //base64编码成data
    NSData  *messageData  = [[NSData alloc] initWithBase64EncodedString:message options:NSDataBase64DecodingIgnoreUnknownCharacters];
    /* 写入数据 */
    [_tcpSocket writeData:messageData withTimeout:timeOut tag:tag];
}


#pragma mark - Privated Method

- (void)disconnect
{
    //断开连接
    [_tcpSocket disconnect];
    //关闭心跳定时器
    dispatch_source_cancel(_beatTimer);
    //未接收到服务器心跳次数,置为初始化
    _senBeatCount = 0;
    
    //自动重连次数 , 置为初始化
    autoConnectCount = 3;
}

/* 开启接收数据 */
- (void)beginReadDataTimeOut:(long)timeOut tag:(long)tag
{
    [_tcpSocket readDataToData:[GCDAsyncSocket LFData] withTimeout:timeOut maxLength:0 tag:tag];
}

/* 发送心跳 */
- (void)sendBeat
{
    //已经连接
    _connectStatus = SocketConnectStatusConnected;
    //定时发送心跳开启
    dispatch_resume(self.beatTimer);
}


#pragma mark - Getter

- (dispatch_source_t)beatTimer
{
    if (!_beatTimer) {
        _beatTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        
        /* 定时器：一秒心跳一次 */
        dispatch_source_set_timer(_beatTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0 * NSEC_PER_SEC);
        
        /* 响应句柄 */
        dispatch_source_set_event_handler(_beatTimer, ^{
            //发送心跳 +1
            _senBeatCount ++ ;
            
            //超过3次未收到服务器心跳 , 置为未连接状态
            if (_senBeatCount>3) {
                _connectStatus = SocketConnectStatusUnConnect;
            } else {
                //发送心跳
                NSData *beatData = [[NSData alloc]initWithBase64EncodedString:[@"beatId" stringByAppendingString:@"\n"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
                [_tcpSocket writeData:beatData withTimeout:-1 tag:9999];
                NSLog(@"------------------发送了心跳------------------");
            }
        });
    }
    return _beatTimer;
}


#pragma mark - GCDAsynSocketDelegate

/*  TCP连接成功建立 */
/*  配置SSL 相当于https 保证安全性 , 这里是单向验证服务器地址 , 仅仅需要验证服务器的IP即可 */
- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(uint16_t)port
{
    // 配置 SSL/TLS 设置信息
    NSMutableDictionary *settings = [NSMutableDictionary dictionaryWithCapacity:3];
    //允许自签名证书手动验证
    [settings setObject:@YES forKey:GCDAsyncSocketManuallyEvaluateTrust];
    //GCDAsyncSocketSSLPeerName
    [settings setObject:@"此处填服务器IP地址" forKey:GCDAsyncSocketSSLPeerName];
    [_tcpSocket startTLS:settings];
}

/* 收到消息 */
- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag
{
    /*
     *   如果是登录验证返回成功，这时候就开启心跳
     *   [self sendBeat];
     */
    
    NSString *string = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    if (self.delegate) {
        if ([_delegate respondsToSelector:@selector(didReceiveMessage:)]) {
            [_delegate didReceiveMessage:string];
        }
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadPartialDataOfLength:(NSUInteger)partialLength tag:(long)tag
{
    
}

/* 写入数据成功 */
- (void)socket:(GCDAsyncSocket *)sock didWriteDataWithTag:(long)tag
{
    /* 重新开启允许读取数据 */
    [self beginReadDataTimeOut:-1 tag:0];
}

/* 读取超时 */
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutReadWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
    return -1;
}

/* 发送消息超时 */
/* 返回数<0即不再等待 */
- (NSTimeInterval)socket:(GCDAsyncSocket *)sock shouldTimeoutWriteWithTag:(long)tag
                 elapsed:(NSTimeInterval)elapsed
               bytesDone:(NSUInteger)length
{
    //发送超时消息分发
    if (self.delegate) {
        if ([_delegate respondsToSelector:@selector(sendMessageTimeOutWithTag:)]) {
            [_delegate sendMessageTimeOutWithTag:tag];
        }
    }
    return -1;
}

/* TCP已经断开连接 */
- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err
{
    _connectStatus  = SocketConnectStatusUnConnect;
    //自动重连
    if (autoConnectCount) {
        [self connectServerHost];
        NSLog(@"-------------第%ld次重连--------------",(long)autoConnectCount);
        autoConnectCount -- ;
    }else{
        NSLog(@"----------------重连次数已用完------------------");
    }
}

/* TCP成功获取安全验证 */
- (void)socketDidSecure:(GCDAsyncSocket *)sock
{
    //发送登录验证
    [self sendMessage:@"" timeOut:-1 tag:0];
    //开启读入流
    [self beginReadDataTimeOut:-1 tag:0];
}

- (void)socket:(GCDAsyncSocket *)sock didReceiveTrust:(SecTrustRef)trust
completionHandler:(void (^)(BOOL shouldTrustPeer))completionHandler
{
    
}

@end
