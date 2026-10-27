/** @file bench.cpp @brief 同版本 FFmpeg 的实时编码对照，不使用桌面或输入权限。 */
extern "C" {
#include <libavcodec/avcodec.h>
#include <libavutil/opt.h>
#include <libavutil/imgutils.h>
#include <libavutil/hwcontext.h>
}
#include <CoreVideo/CoreVideo.h>
#include <chrono>
#include <thread>
#include <map>
#include <vector>
#include <algorithm>
#include <cstdio>
#include <cmath>

int main(int argc, char **argv) {
  bool hardware=argc>1;
  auto codec=avcodec_find_encoder_by_name("h264_videotoolbox");
  AVCodecContext *ctx=avcodec_alloc_context3(codec);
  ctx->width=1920;ctx->height=1080;ctx->pix_fmt=hardware?AV_PIX_FMT_VIDEOTOOLBOX:AV_PIX_FMT_NV12;
  AVBufferRef *device=nullptr,*pool=nullptr;
  if(hardware){
    if(av_hwdevice_ctx_create(&device,AV_HWDEVICE_TYPE_VIDEOTOOLBOX,nullptr,nullptr,0)<0)return 6;
    pool=av_hwframe_ctx_alloc(device);auto *p=(AVHWFramesContext*)pool->data;
    p->format=AV_PIX_FMT_VIDEOTOOLBOX;p->sw_format=AV_PIX_FMT_NV12;p->width=1920;p->height=1080;
    if(av_hwframe_ctx_init(pool)<0)return 7;ctx->hw_frames_ctx=av_buffer_ref(pool);
  }
  ctx->time_base={1,60};ctx->framerate={60,1};ctx->bit_rate=7000000;
  ctx->max_b_frames=0;ctx->gop_size=1000000;ctx->flags|=AV_CODEC_FLAG_LOW_DELAY|AV_CODEC_FLAG_CLOSED_GOP;
  ctx->profile=AV_PROFILE_H264_BASELINE;
  AVDictionary *options=nullptr;av_dict_set(&options,"realtime","1",0);
  if(avcodec_open2(ctx,codec,&options)<0)return 2;
  AVFrame *frame=av_frame_alloc();
  if(!hardware){frame->format=ctx->pix_fmt;frame->width=1920;frame->height=1080;if(av_frame_get_buffer(frame,32)<0)return 3;}
  AVPacket *packet=av_packet_alloc();
  std::map<int64_t,std::chrono::steady_clock::time_point> pending;
  std::vector<double> times;int keys=0,packets=0;
  auto first=std::chrono::steady_clock::now();
  auto receive=[&](){while(avcodec_receive_packet(ctx,packet)==0){
    auto found=pending.find(packet->pts);
    if(found!=pending.end()){
      if(packet->pts>=20 && packet->pts<175)times.push_back(std::chrono::duration<double,std::milli>(std::chrono::steady_clock::now()-found->second).count());
      pending.erase(found);
    }
    keys+=(packet->flags&AV_PKT_FLAG_KEY)!=0;packets++;av_packet_unref(packet);
  }};
  for(int i=0;i<180;i++){
    std::this_thread::sleep_until(first+std::chrono::microseconds(i*1000000/60));
    CVPixelBufferRef pixel=nullptr;uint8_t *luma,*chroma;size_t pitchY,pitchUV;
    if(hardware){av_frame_unref(frame);if(av_hwframe_get_buffer(pool,frame,0)<0)return 8;pixel=(CVPixelBufferRef)frame->data[3];CVPixelBufferLockBaseAddress(pixel,0);luma=(uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixel,0);chroma=(uint8_t*)CVPixelBufferGetBaseAddressOfPlane(pixel,1);pitchY=CVPixelBufferGetBytesPerRowOfPlane(pixel,0);pitchUV=CVPixelBufferGetBytesPerRowOfPlane(pixel,1);}
    else{av_frame_make_writable(frame);luma=frame->data[0];chroma=frame->data[1];pitchY=frame->linesize[0];pitchUV=frame->linesize[1];}
    for(int y=0;y<1080;y++)for(int x=0;x<1920;x++)luma[y*pitchY+x]=16+(((x/64+y/64+i/10)%2)*180);
    for(int y=0;y<540;y++)for(int x=0;x<1920;x++)chroma[y*pitchUV+x]=128;
    if(pixel)CVPixelBufferUnlockBaseAddress(pixel,0);
    frame->pts=i;frame->pict_type=AV_PICTURE_TYPE_NONE;
    pending[i]=std::chrono::steady_clock::now();
    if(avcodec_send_frame(ctx,frame)<0)return 4;
    receive();
  }
  avcodec_send_frame(ctx,nullptr);receive();
  std::sort(times.begin(),times.end());
  if(times.empty())return 5;
  printf("{\"samples\":%zu,\"p50_ms\":%.3f,\"p95_ms\":%.3f,\"packets\":%d,\"keyframes\":%d}\n",times.size(),times[times.size()/2],times[(size_t)ceil(times.size()*.95)-1],packets,keys);
  av_packet_free(&packet);av_frame_free(&frame);avcodec_free_context(&ctx);return 0;
}
