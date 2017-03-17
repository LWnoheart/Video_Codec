//
//  LWPlayer.m
//  Video_Codec
//
//  Created by 李巍 on 2017/3/17.
//  Copyright © 2017年 李巍. All rights reserved.
//

#import "LWPlayer.h"
#import "FilmSeparate.h"
#import "VideoDecode.h"
#import "AudioDecode.h"

@interface LWPlayer ()<FilmSeparateDelegate>

@end
@implementation LWPlayer


- (instancetype)init
{
    self = [super init];
    if (self) {
        NSString *inpath = [[NSBundle mainBundle]pathForResource:@"playmovie" ofType:@"flv"];
        
        FilmSeparate *separate = [[FilmSeparate alloc]init];
        separate.delegate = self;
        [separate separateFilmAsynchronousByPath:inpath identifier:nil];
//        if ([separate creatFilm]) {
//            NSLog(@"sucess!!!!!!!!!!!!");
//        }else{
//            NSLog(@"failus!!!!!!!!!!!!");
//        }
    }
    return self;
}

-(void)startSeparateFilmByPath:(NSString *)path identifier:(NSString *)identifier
{
    NSLog(@"start at path:%@",path);
}

-(void)finishSeparateFilmByPath:(NSString *)path identifier:(NSString *)identifier videoPath:(NSString *)videoPath audioPath:(NSString *)audioPath error:(NSError *)error
{
    NSLog(@"finish at path:%@\n videoPath:%@\n audioPath:%@",path,videoPath,audioPath);
}
@end
