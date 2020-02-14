//
//  MediaClipboardJSI.h
//  Media
//
//  Created by Jarred WSumner on 2/6/20.
//  Copyright © 2020 Media. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MediaClipboard;

#ifdef __cplusplus

#include <ReactCommon/BridgeJSCallInvoker.h>
#import <jsi/jsi.h>


using namespace facebook;

@class RCTCxxBridge;

class JSI_EXPORT MediaClipboardJSIModule : public jsi::HostObject {
public:
    MediaClipboardJSIModule(MediaClipboard* clipboard);

    static void install(MediaClipboard *clipboard);

    /*
     * `jsi::HostObject` specific overloads.
     */
    jsi::Value get(jsi::Runtime &runtime, const jsi::PropNameID &name) override;

    jsi::Value getOther(jsi::Runtime &runtime, const jsi::PropNameID &name);

private:
    MediaClipboard* clipboard_;
    std::shared_ptr<facebook::react::JSCallInvoker> _jsInvoker;
};

#endif



