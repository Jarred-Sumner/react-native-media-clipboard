//
//  YeetJSIUTils.h
//  yeet
//
//  Created by Jarred WSumner on 1/30/20.
//  Copyright © 2020 Yeet. All rights reserved.
//

#pragma once
#ifdef __cplusplus

#import <Foundation/Foundation.h>
#import <jsi/jsi.h>
#import <ReactCommon/JSCallInvoker.h>
#import <ReactCommon/LongLivedObject.h>
#import <React/RCTConvert.h>
#import <React/RCTBridgeModule.h>
#import <ReactCommon/TurboModuleUtils.h>

using namespace facebook;
/**
 * All static helper functions are ObjC++ specific.
// */
jsi::Value convertObjCObjectToJSIValue(jsi::Runtime &runtime, id value);
jsi::Value convertNSNumberToJSIBoolean(jsi::Runtime &runtime, NSNumber *value);
jsi::Value convertNSNumberToJSINumber(jsi::Runtime &runtime, NSNumber *value);
jsi::String convertNSStringToJSIString(jsi::Runtime &runtime, NSString *value);
jsi::Object convertNSDictionaryToJSIObject(jsi::Runtime &runtime, NSDictionary *value);
jsi::Array convertNSArrayToJSIArray(jsi::Runtime &runtime, NSArray *value);
//std::vector<jsi::Value> convertNSArrayToStdVector(jsi::Runtime &runtime, NSArray *value);
//jsi::Value convertObjCObjectToJSIValue(jsi::Runtime &runtime, id value);
//id convertJSIValueToObjCObject(
//    jsi::Runtime &runtime,
//    const jsi::Value &value);
//NSString* convertJSIStringToNSString(jsi::Runtime &runtime, const jsi::String &value);
//NSArray* convertJSIArrayToNSArray(
//    jsi::Runtime &runtime,
//                                         const jsi::Array &value);
//NSDictionary *convertJSIObjectToNSDictionary(
//    jsi::Runtime &runtime,
//    const jsi::Object &value);


 NSString *convertJSIStringToNSString(jsi::Runtime &runtime, const jsi::String &value);
 NSArray *convertJSIArrayToNSArray(
    jsi::Runtime &runtime,
    const jsi::Array &value,
    std::shared_ptr<react::JSCallInvoker> jsInvoker
);
NSDictionary *convertJSIObjectToNSDictionary(
    jsi::Runtime &runtime,
    const jsi::Object &value,
    std::shared_ptr<react::JSCallInvoker> jsInvoker);
 RCTResponseSenderBlock convertJSIFunctionToCallback(
    jsi::Runtime &runtime,
    const jsi::Function &value,
    std::shared_ptr<react::JSCallInvoker> jsInvoker);
id convertJSIValueToObjCObject(
    jsi::Runtime &runtime,
    const jsi::Value &value,
    std::shared_ptr<react::JSCallInvoker> jsInvoker);

// Helper for creating Promise object.
struct PromiseWrapper : public react::LongLivedObject {
  static std::shared_ptr<PromiseWrapper> create(
      jsi::Function resolve,
      jsi::Function reject,
      jsi::Runtime &runtime,
      std::shared_ptr<react::JSCallInvoker> jsInvoker)
  {
    auto instance = std::make_shared<PromiseWrapper>(std::move(resolve), std::move(reject), runtime, jsInvoker);
    // This instance needs to live longer than the caller's scope, since the resolve/reject functions may not
    // be called immediately. Doing so keeps it alive at least until resolve/reject is called, or when the
    // collection is cleared (e.g. when JS reloads).
    react::LongLivedObjectCollection::get().add(instance);
    return instance;
  }

  PromiseWrapper(
      jsi::Function resolve,
      jsi::Function reject,
      jsi::Runtime &runtime,
      std::shared_ptr<react::JSCallInvoker> jsInvoker)
      : resolveWrapper(std::make_shared<react::CallbackWrapper>(std::move(resolve), runtime, jsInvoker)),
        rejectWrapper(std::make_shared<react::CallbackWrapper>(std::move(reject), runtime, jsInvoker)),
        runtime(runtime),
        jsInvoker(jsInvoker)
  {
  }

  RCTPromiseResolveBlock resolveBlock()
  {
    return ^(id result) {
      if (resolveWrapper == nullptr) {
        throw std::runtime_error("Promise resolve arg cannot be called more than once");
      }

      // Retain the resolveWrapper so that it stays alive inside the lambda.
      std::shared_ptr<react::CallbackWrapper> retainedWrapper = resolveWrapper;
      std::shared_ptr<react::JSCallInvoker> invoker = jsInvoker;
      jsInvoker->invokeAsync([retainedWrapper, result, invoker]() {
        jsi::Runtime &rt = retainedWrapper->runtime();
        jsi::Value arg = convertObjCObjectToJSIValue(rt, result);
        retainedWrapper->callback().call(rt, arg);
      });

      // Prevent future invocation of the same resolve() function.
      cleanup();
    };
  }

  RCTPromiseRejectBlock rejectBlock()
  {
    return ^(NSString *code, NSString *message, NSError *error) {
      // TODO: There is a chance `this` is no longer valid when this block executes.
      if (rejectWrapper == nullptr) {
        throw std::runtime_error("Promise reject arg cannot be called more than once");
      }

      // Retain the resolveWrapper so that it stays alive inside the lambda.
      std::shared_ptr<react::CallbackWrapper> retainedWrapper = rejectWrapper;
      NSDictionary *jsError = RCTJSErrorFromCodeMessageAndNSError(code, message, error);
      jsInvoker->invokeAsync([retainedWrapper, jsError]() {
        jsi::Runtime &rt = retainedWrapper->runtime();
        jsi::Value arg = convertNSDictionaryToJSIObject(rt, jsError);
        retainedWrapper->callback().call(rt, arg);
      });

      // Prevent future invocation of the same resolve() function.
      cleanup();
    };
  }

  void cleanup()
  {
    resolveWrapper = nullptr;
    rejectWrapper = nullptr;
    allowRelease();
  }

  // CallbackWrapper is used here instead of just holding on the jsi jsi::Function in order to force release it after
  // either the resolve() or the reject() is called. jsi jsi::Function does not support explicit releasing, so we need
  // an extra mechanism to control that lifecycle.
  std::shared_ptr<react::CallbackWrapper> resolveWrapper;
  std::shared_ptr<react::CallbackWrapper> rejectWrapper;
  jsi::Runtime &runtime;
  std::shared_ptr<react::JSCallInvoker> jsInvoker;
};

using PromiseInvocationBlock = void (^)(jsi::Runtime &rt, std::shared_ptr<PromiseWrapper> wrapper);
jsi::Value
createPromise(jsi::Runtime &runtime, std::shared_ptr<react::JSCallInvoker> jsInvoker, PromiseInvocationBlock invoke);

#endif
