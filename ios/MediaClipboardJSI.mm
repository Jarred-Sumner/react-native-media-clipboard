//
//  MediaClipboardJSI.cpp
//  MediaClipboard
//
//  Created by Jarred WSumner on 2/13/20.
//  Copyright © 2020 Yeet. All rights reserved.
//

#include "MediaClipboardJSI.h"
#import <React/RCTBridge+Private.h>
#import "MediaJSIUTils.h"
#import <ReactCommon/TurboModule.h>
#import <Foundation/Foundation.h>
#import <React/RCTUIManager.h>
#import <React/RCTScrollView.h>
#import "RCTConvert+PHotos.h"
#import "MediaClipboardJSI.h"



@interface RCTBridge (ext)
- (std::weak_ptr<facebook::react::Instance>)reactInstance;
@end

MediaClipboardJSIModule::MediaClipboardJSIModule
 (MediaClipboard *clipboard)
: clipboard_(clipboard) {
  std::shared_ptr<facebook::react::JSCallInvoker> _jsInvoker = std::make_shared<react::BridgeJSCallInvoker>(clipboard.bridge.reactInstance);
}


void MediaClipboardJSIModule::install(MediaClipboard *clipboard) {
  RCTCxxBridge* bridge = clipboard.bridge;

   if (bridge.runtime == nullptr) {
     return;
   }

  jsi::Runtime &runtime = *(jsi::Runtime *)bridge.runtime;

  auto reaModuleName = "Clipboard";
  auto reaJsiModule = std::make_shared<MediaClipboardJSIModule>(std::move(clipboard));
  auto object = jsi::Object::createFromHostObject(runtime, reaJsiModule);
  runtime.global().setProperty(runtime, reaModuleName, std::move(object));
}

jsi::Value MediaClipboardJSIModule::get(jsi::Runtime &runtime, const jsi::PropNameID &name) {
  if (_jsInvoker == nullptr) {
      RCTCxxBridge* bridge = clipboard_.bridge;
    _jsInvoker = std::make_shared<react::BridgeJSCallInvoker>(bridge.reactInstance);
  }


  auto methodName = name.utf8(runtime);

  if (methodName == "getMediaSource") {
    MediaClipboard *clipboard = clipboard_;
    std::shared_ptr<facebook::react::JSCallInvoker> jsInvoker = _jsInvoker;

    return jsi::Function::createFromHostFunction(runtime, name, 1, [clipboard, jsInvoker](
          jsi::Runtime &runtime,
          const jsi::Value &thisValue,
          const jsi::Value *arguments,
          size_t count) -> jsi::Value {

     // Promise return type is special cased today, i.e. it needs extra 2 function args for resolve() and reject(), to
     // be passed to the actual ObjC++ class method.
     return createPromise(runtime, jsInvoker, ^(jsi::Runtime &rt, std::shared_ptr<PromiseWrapper> wrapper) {
       NSMutableArray *retained = [[NSMutableArray alloc] initWithCapacity:2];
       if (clipboard.lastMediaSource) {
         wrapper->resolveBlock()(clipboard.lastMediaSource.toDictionary);
       } else if (UIPasteboard.generalPasteboard.hasImages) {
         RCTPromiseResolveBlock resolver = wrapper->resolveBlock();
         RCTPromiseRejectBlock rejecter = wrapper->rejectBlock();
         [retained addObject:resolver];
         [retained addObject:rejecter];

         [clipboard clipboardMediaSource:^(NSArray *response) {
           NSError *error = [response objectAtIndex:0];
           NSDictionary *value = [response objectAtIndex:1];
           if (error && error != [NSNull null]) {
             rejecter([NSString stringWithFormat:@"%ldu", (long)error.code], error.domain, error);
           } else {
            resolver(value);
           }

           [retained removeAllObjects];
         }];
       } else {
         wrapper->resolveBlock()(nil);
       }
     });
  });

    }

  return jsi::Value::undefined();
}
