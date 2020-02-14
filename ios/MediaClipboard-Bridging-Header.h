//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import <React/RCTEventEmitter.h>
#import <React/RCTBridge.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface RCT_EXTERN_MODULE(MediaClipboard, RCTEventEmitter)

RCT_EXTERN_METHOD(getContent:(RCTResponseSenderBlock)callback);
RCT_EXTERN_METHOD(clipboardMediaSource:(RCTResponseSenderBlock)callback);

@end
