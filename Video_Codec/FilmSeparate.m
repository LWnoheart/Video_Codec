//
//  FilmSeparate.m
//  Video_Codec
//
//  Created by 李巍 on 2017/3/17.
//  Copyright © 2017年 李巍. All rights reserved.
//

#import "FilmSeparate.h"
#import "avformat.h"
#import "mathematics.h"
/*
 FIX: H.264 in some container format (FLV, MP4, MKV etc.) need
 "h264_mp4toannexb" bitstream filter (BSF)
 *Add SPS,PPS in front of IDR frame
 *Add start code ("0,0,0,1") in front of NALU
 H.264 in some container (MPEG2TS) don't need this BSF.
 */
//'1': Use H.264 Bitstream Filter
#define USE_H264BSF 0


@interface FilmSeparate ()
@property (nonatomic,strong)dispatch_queue_t separateQueue;
@property (nonatomic,strong)NSDateFormatter *dateFormatter;
@end

@implementation FilmSeparate

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.separateQueue = dispatch_queue_create("com.filmSeparate.separate", DISPATCH_QUEUE_SERIAL);
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _outPath = [NSString stringWithFormat:@"%@/filmSeparate/%p/",paths[0],self];
        [[NSFileManager defaultManager]createDirectoryAtPath:self.outPath withIntermediateDirectories:YES attributes:nil error:nil];
        
        self.dateFormatter = [[NSDateFormatter alloc]init];
        self.dateFormatter.dateFormat = @"YYYYMMddHHmmss";
    }
    return self;
}

-(void)separateFilmAsynchronousByPath:(NSString *)path identifier:(NSString *)identifier
{
    __weak FilmSeparate *this = self;
    dispatch_async(self.separateQueue, ^{
        if (this.delegate &&[this.delegate respondsToSelector:@selector(startSeparateFilmByPath:identifier:)]) {
            [this.delegate startSeparateFilmByPath:path identifier:identifier];
        }
        
        NSString *outPath_v = [self getVideoOutPath];
        NSString *outPath_a = [self getAudioOutPath];
        
        bool result = SeparateLocalFilm([path UTF8String], [outPath_v UTF8String], [outPath_a UTF8String]);
        
        if (this.delegate &&[this.delegate respondsToSelector:@selector(finishSeparateFilmByPath:identifier:videoPath:audioPath:error:)]) {
            NSError *error = result?nil:[NSError errorWithDomain:@"" code:1 userInfo:nil];
            [this.delegate finishSeparateFilmByPath:path identifier:identifier videoPath:outPath_v audioPath:outPath_a error:error];
        }
    });
}


bool SeparateLocalFilm(const char *in_filePath,const char *out_filePath_v,const char *out_filePath_a)//file URL
{
    AVOutputFormat *ofmt_a = NULL,*ofmt_v = NULL;
    //（Input AVFormatContext and Output AVFormatContext）
    AVFormatContext *ifmt_ctx = NULL, *ofmt_ctx_a = NULL, *ofmt_ctx_v = NULL;
    AVPacket pkt;
    int ret, i;
    int videoindex=-1,audioindex=-1;
    int frame_index=0;
    
    av_register_all();
    //Input
    if ((ret = avformat_open_input(&ifmt_ctx, in_filePath, 0, 0)) < 0) {
        printf( "Could not open input file.");
        goto end;
    }
    if ((ret = avformat_find_stream_info(ifmt_ctx, 0)) < 0) {
        printf( "Failed to retrieve input stream information");
        goto end;
    }
    
    //Output
    avformat_alloc_output_context2(&ofmt_ctx_v, NULL, NULL, out_filePath_v);
    if (!ofmt_ctx_v) {
        printf( "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    ofmt_v = ofmt_ctx_v->oformat;
    
    avformat_alloc_output_context2(&ofmt_ctx_a, NULL, NULL, out_filePath_a);
    if (!ofmt_ctx_a) {
        printf( "Could not create output context\n");
        ret = AVERROR_UNKNOWN;
        goto end;
    }
    ofmt_a = ofmt_ctx_a->oformat;
    
    for (i = 0; i < ifmt_ctx->nb_streams; i++) {
        //Create output AVStream according to input AVStream
        AVFormatContext *ofmt_ctx;
        AVStream *in_stream = ifmt_ctx->streams[i];
        AVStream *out_stream = NULL;
        
        if(ifmt_ctx->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO){
            videoindex=i;
            out_stream=avformat_new_stream(ofmt_ctx_v, in_stream->codec->codec);
            ofmt_ctx=ofmt_ctx_v;
        }else if(ifmt_ctx->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO){
            audioindex=i;
            out_stream=avformat_new_stream(ofmt_ctx_a, in_stream->codec->codec);
            ofmt_ctx=ofmt_ctx_a;
        }else{
            break;
        }
        
        if (!out_stream) {
            printf( "Failed allocating output stream\n");
            ret = AVERROR_UNKNOWN;
            goto end;
        }
        //Copy the settings of AVCodecContext
        if (avcodec_copy_context(out_stream->codec, in_stream->codec) < 0) {
            printf( "Failed to copy context from input to output stream codec context\n");
            goto end;
        }
        out_stream->codec->codec_tag = 0;
        
        if (ofmt_ctx->oformat->flags & AVFMT_GLOBALHEADER)
            out_stream->codec->flags |= CODEC_FLAG_GLOBAL_HEADER;
    }
    
    //Dump Format------------------
    printf("\n==============Input Video=============\n");
    av_dump_format(ifmt_ctx, 0, in_filePath, 0);
    printf("\n==============Output Video============\n");
    av_dump_format(ofmt_ctx_v, 0, out_filePath_v, 1);
    printf("\n==============Output Audio============\n");
    av_dump_format(ofmt_ctx_a, 0, out_filePath_a, 1);
    printf("\n======================================\n");
    //Open output file
    if (!(ofmt_v->flags & AVFMT_NOFILE)) {
        if (avio_open(&ofmt_ctx_v->pb, out_filePath_v, AVIO_FLAG_WRITE) < 0) {
            printf( "Could not open output file '%s'", out_filePath_v);
            goto end;
        }
    }
    
    if (!(ofmt_a->flags & AVFMT_NOFILE)) {
        if (avio_open(&ofmt_ctx_a->pb, out_filePath_a, AVIO_FLAG_WRITE) < 0) {
            printf( "Could not open output file '%s'", out_filePath_a);
            goto end;
        }
    }
    
    //Write file header
    if (avformat_write_header(ofmt_ctx_v, NULL) < 0) {
        printf( "Error occurred when opening video output file\n");
        goto end;
    }
    if (avformat_write_header(ofmt_ctx_a, NULL) < 0) {
        printf( "Error occurred when opening audio output file\n");
        goto end;
    }
    
#if USE_H264BSF
    AVBitStreamFilterContext* h264bsfc =  av_bitstream_filter_init("h264_mp4toannexb");
#endif
    
    while (1) {
        AVFormatContext *ofmt_ctx;
        AVStream *in_stream, *out_stream;
        //Get an AVPacket
        if (av_read_frame(ifmt_ctx, &pkt) < 0)
            break;
        in_stream  = ifmt_ctx->streams[pkt.stream_index];
        
        
        if(pkt.stream_index==videoindex){
            out_stream = ofmt_ctx_v->streams[0];
            ofmt_ctx=ofmt_ctx_v;
//            printf("Write Video Packet. size:%d\tpts:%lld\n",pkt.size,pkt.pts);
#if USE_H264BSF
            av_bitstream_filter_filter(h264bsfc, in_stream->codec, NULL, &pkt.data, &pkt.size, pkt.data, pkt.size, 0);
#endif
        }else if(pkt.stream_index==audioindex){
            out_stream = ofmt_ctx_a->streams[0];
            ofmt_ctx=ofmt_ctx_a;
//            printf("Write Audio Packet. size:%d\tpts:%lld\n",pkt.size,pkt.pts);
        }else{
            continue;
        }
        
        
        //Convert PTS/DTS
        pkt.pts = av_rescale_q_rnd(pkt.pts, in_stream->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        pkt.dts = av_rescale_q_rnd(pkt.dts, in_stream->time_base, out_stream->time_base, (AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX));
        pkt.duration = (int)av_rescale_q(pkt.duration, in_stream->time_base, out_stream->time_base);
        pkt.pos = -1;
        pkt.stream_index=0;
        //Write
        if (av_interleaved_write_frame(ofmt_ctx, &pkt) < 0) {
            printf( "FilmSeparate Error muxing packet\n");
            break;
        }
        //printf("Write %8d frames to output file\n",frame_index);
        av_free_packet(&pkt);
        frame_index++;
    }
    
#if USE_H264BSF
    av_bitstream_filter_close(h264bsfc);
#endif
    
    //Write file trailer
    av_write_trailer(ofmt_ctx_a);
    av_write_trailer(ofmt_ctx_v);
end:
    avformat_close_input(&ifmt_ctx);
    /* close output */
    if (ofmt_ctx_a && !(ofmt_a->flags & AVFMT_NOFILE))
        avio_close(ofmt_ctx_a->pb);
    
    if (ofmt_ctx_v && !(ofmt_v->flags & AVFMT_NOFILE))
        avio_close(ofmt_ctx_v->pb);
    
    avformat_free_context(ofmt_ctx_a);
    avformat_free_context(ofmt_ctx_v);
    
    
    if (ret < 0 && ret != AVERROR_EOF) {
        printf( "FilmSeparate Error occurred.\n");
        return false;
    }
    return true;
}

-(NSString *)getVideoOutPath
{
    return [self.outPath stringByAppendingFormat:@"%@_v.h264",[self.dateFormatter stringFromDate:[NSDate date]]];
}

-(NSString *)getAudioOutPath
{
    return [self.outPath stringByAppendingFormat:@"%@_a.aac",[self.dateFormatter stringFromDate:[NSDate date]]];
}

@end
