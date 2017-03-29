//
//  ViewController.m
//  Kcptun
//
//  Created by NickyTsui on 2017/2/24.
//  Copyright © 2017年 NickyTsui. All rights reserved.
//

#import "ViewController.h"
#include <stdio.h>
#include <sys/types.h>
#include <sys/sysctl.h>
/** kcp客户端 文件名 */
//static NSString *clientFile = @"kcptun_client";
static NSString *clientFile = @"kcptun_client_20170329";


@interface ViewController ()

@property (weak) IBOutlet NSTextField       *statusLabel;

@property (weak) IBOutlet NSTextField       *kcpipTextField;

@property (weak) IBOutlet NSTextField       *kcpportTextField;

@property (weak) IBOutlet NSTextField       *kcppasswordTextField;

@property (weak) IBOutlet NSTextField       *kcplistenerTextField;


@property (weak) IBOutlet NSButton          *stopButton;
@property (weak) IBOutlet NSButton          *startButton;
@property (weak) IBOutlet NSButton          *checkStatusButton;

@property (copy,nonatomic) NSArray          *processArray;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view.
    
    [self read];
    [self checkRunning:YES];
    
//    [self openProcess:@"sudo sysctl -w kern.timer.coalescing_enabled=0"];
//    [self clear];
}
- (void)checkRunning:(BOOL)log{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        BOOL running = [self checkProcessRunning:log];
        dispatch_async(dispatch_get_main_queue(), ^{
           self.statusLabel.stringValue = running?@"运行中":@"未运行";
        });
    });
}
- (IBAction)startAction:(id)sender {
    [self save];
    [self startProcess];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkRunning:NO];
    });
}
- (IBAction)stopAction:(id)sender {
    [self killProcess];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self checkRunning:NO];
    });
}
- (IBAction)refreshAction:(id)sender {
    [self checkRunning:YES];
    
}
//- (void)clear{
//    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
//    [ud removeObjectForKey:@"_addr"];
//    [ud removeObjectForKey:@"_port"];
//    [ud removeObjectForKey:@"_psd"];
//    [ud removeObjectForKey:@"_l_port"];
//    [ud synchronize];
//}
- (void)read{
    
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    self.kcpipTextField.stringValue = [ud stringForKey:@"_addr"]?:@"";
    self.kcpportTextField.stringValue = [ud stringForKey:@"_port"]?:@"";
    self.kcppasswordTextField.stringValue = [ud stringForKey:@"_psd"]?:@"";
    self.kcplistenerTextField.stringValue = [ud stringForKey:@"_l_port"]?:@"";
}
- (void)save{
    NSString *serverAddress = self.kcpipTextField.stringValue;
    NSString *serverPort = self.kcpportTextField.stringValue;
    NSString *serverPassword = self.kcppasswordTextField.stringValue;
    NSString *localPort = self.kcplistenerTextField.stringValue;
    NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
    [ud setObject:serverAddress forKey:@"_addr"];
    [ud setObject:serverPort forKey:@"_port"];
    [ud setObject:serverPassword forKey:@"_psd"];
    [ud setObject:localPort forKey:@"_l_port"];
    [ud synchronize];
}
- (void)startProcess{
    NSString *path = [[NSBundle mainBundle]pathForResource:clientFile ofType:@""];
    NSLog(@"path = %@",path);
    NSString *s = [NSString stringWithFormat:@"%@ -l :%@ -r %@:%@ -mode fast2 -conn 1 -key %@ -mtu 1350",path,self.kcplistenerTextField.stringValue,self.kcpipTextField.stringValue,self.kcpportTextField.stringValue,self.kcppasswordTextField.stringValue];
    
//    NSTask *execution = [NSTask new];
//    execution.launchPath = @"/bin/sh";
//    execution.arguments = @[@"-c",s];
//    [execution launch];
    
    [self openProcess:s];


}

- (void)killProcess{
    for (id obj in self.processArray) {
        NSDictionary *process = obj;
        if ([clientFile hasPrefix:process[@"ProcessName"]]){
            NSInteger processID = [process[@"ProcessID"] integerValue];
            
            NSString *exec = [NSString stringWithFormat:@"kill -9 %zd",processID];
            [self openProcess:exec];
            break;
        }
    }
    
}
- (void)openProcess:(NSString *)path{
    //kern.timer.coalescing enabled
    NSTask *execution = [NSTask new];
    execution.launchPath = @"/bin/sh";
    execution.arguments = @[@"-c",path];
    [execution launch];
}
- (BOOL)checkProcessRunning:(BOOL)log{
    // 获取当前运行的程序
    NSArray *process =  [self runningProcesses];
    self.processArray = process;
    __block BOOL running = NO;
    [process enumerateObjectsUsingBlock:^(NSDictionary  *obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (log){
            NSLog(@"%@",obj);
        }
        if ([clientFile hasPrefix:obj[@"ProcessName"]]){
            running = YES;
        }
    }];
    return running;
}


//返回所有正在运行的进程的 id，name，占用cpu，运行时间
//使用函数int   sysctl(int *, u_int, void *, size_t *, void *, size_t)
- (NSArray *)runningProcesses
{
    //指定名字参数，按照顺序第一个元素指定本请求定向到内核的哪个子系统，第二个及其后元素依次细化指定该系统的某个部分。
    //CTL_KERN，KERN_PROC,KERN_PROC_ALL 正在运行的所有进程
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL ,0};
    
    
    int miblen = 4;
    //值-结果参数：函数被调用时，size指向的值指定该缓冲区的大小；函数返回时，该值给出内核存放在该缓冲区中的数据量
    //如果这个缓冲不够大，函数就返回ENOMEM错误
    size_t size;
    //返回0，成功；返回-1，失败
    NSInteger  st = sysctl(mib, miblen, NULL, &size, NULL, 0);
    
    struct kinfo_proc * process = NULL;
    struct kinfo_proc * newprocess = NULL;
    do
    {
        size += size / 10;
        newprocess = realloc(process, size);
        if (!newprocess)
        {
            if (process)
            {
                free(process);
                process = NULL;
            }
            return nil;
        }
        
        process = newprocess;
        st = sysctl(mib, miblen, process, &size, NULL, 0);
    } while (st == -1 && errno == ENOMEM);
    
    if (st == 0)
    {
        if (size % sizeof(struct kinfo_proc) == 0)
        {
            NSUInteger nprocess = size / sizeof(struct kinfo_proc);
            if (nprocess)
            {
                NSMutableArray * array = [[NSMutableArray alloc] init];
                for (NSInteger i = nprocess - 1; i >= 0; i--)
                {
                    NSString * processID = [[NSString alloc] initWithFormat:@"%zd", process[i].kp_proc.p_pid];
                    NSString * processName = [[NSString alloc] initWithFormat:@"%s", process[i].kp_proc.p_comm];
                    NSString * proc_CPU = [[NSString alloc] initWithFormat:@"%d", process[i].kp_proc.p_estcpu];
                    double t = [[NSDate date] timeIntervalSince1970] - process[i].kp_proc.p_un.__p_starttime.tv_sec;
                    NSString * proc_useTiem = [[NSString alloc] initWithFormat:@"%f",t];
                    
                    //NSLog(@"process.kp_proc.p_stat = %c",process.kp_proc.p_stat);
                    
                    NSMutableDictionary *dic = [[NSMutableDictionary alloc] init];
                    [dic setValue:processID forKey:@"ProcessID"];
                    [dic setValue:processName forKey:@"ProcessName"];
                    [dic setValue:proc_CPU forKey:@"ProcessCPU"];
                    [dic setValue:proc_useTiem forKey:@"ProcessUseTime"];
                    
                    [array addObject:dic];
                    
                }
                
                free(process);
                process = NULL;
                return array;
            }
        }
    }
    
    return nil;
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
