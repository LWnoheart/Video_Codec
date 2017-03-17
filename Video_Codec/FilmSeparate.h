//
//  FilmSeparate.h
//  Video_Codec
//
//  Created by 李巍 on 2017/3/17.
//  Copyright © 2017年 李巍. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol FilmSeparateDelegate;

@interface FilmSeparate : NSObject

@property (nonatomic,strong,readonly)NSString *outPath;

@property (nonatomic,weak)id<FilmSeparateDelegate>delegate;

-(void)separateFilmAsynchronousByPath:(NSString *)path identifier:(NSString *)identifier;

@end


@protocol FilmSeparateDelegate <NSObject>

-(void)startSeparateFilmByPath:(NSString *)path identifier:(NSString *)identifier;

-(void)finishSeparateFilmByPath:(NSString *)path identifier:(NSString *)identifier videoPath:(NSString *)videoPath audioPath:(NSString *)audioPath error:(NSError *)error;

@end
