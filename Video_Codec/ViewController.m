//
//  ViewController.m
//  Video_Codec
//
//  Created by 李巍 on 2017/3/16.
//  Copyright © 2017年 李巍. All rights reserved.
//

#import "ViewController.h"
#import "LWPlayer.h"

@interface ViewController ()
@property (nonatomic,strong)LWPlayer *player;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.player = [[LWPlayer alloc]init];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}




@end
