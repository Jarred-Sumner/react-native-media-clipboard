//
//  REAJsiUtilities.cpp
//  RNReanimated
//
//  Created by Christian Falch on 25/04/2019.
//  Copyright © 2019 Yeet. All rights reserved.
//

#include "YeetJSIUTils.h"
#import <ReactCommon/TurboModule.h>
#import <Foundation/Foundation.h>
#import <React/RCTBridge+Private.h>
#import <React/RCTBridgeModule.h>

jsi::Value convertObjCObjectToJSIValue(jsi::Runtime &runtime, id value)
{
  if ([value isKindOfClass:[NSString class]]) {
    return convertNSStringToJSIString(runtime, (NSString *)value);
  } else if ([value isKindOfClass:[NSNumber class]]) {
    if ([value isKindOfClass:[@YES class]]) {
      return convertNSNumberToJSIBoolean(runtime, (NSNumber *)value);
    }
    return convertNSNumberToJSINumber(runtime, (NSNumber *)value);
  } else if ([value isKindOfClass:[NSDictionary class]]) {
    return convertNSDictionaryToJSIObject(runtime, (NSDictionary *)value);
  } else if ([value isKindOfClass:[NSArray class]]) {
    return convertNSArrayToJSIArray(runtime, (NSArray *)value);
  } else if (value == (id)kCFNull) {
    return jsi::Value::null();
  }
  return jsi::Value::undefined();
}


jsi::Value convertNSNumberToJSIBoolean(jsi::Runtime &runtime, NSNumber *value)
{
  return jsi::Value((bool)[value boolValue]);
}

jsi::Value convertNSNumberToJSINumber(jsi::Runtime &runtime, NSNumber *value)
{
  return jsi::Value([value doubleValue]);
}

 jsi::String convertNSStringToJSIString(jsi::Runtime &runtime, NSString *value)
{
  return jsi::String::createFromUtf8(runtime, [value UTF8String] ?: "");
}

jsi::Object convertNSDictionaryToJSIObject(jsi::Runtime &runtime, NSDictionary *value)
{
  jsi::Object result = jsi::Object(runtime);
  for (NSString *k in value) {
    result.setProperty(runtime, [k UTF8String], convertObjCObjectToJSIValue(runtime, value[k]));
  }
  return result;
}

jsi::Array convertNSArrayToJSIArray(jsi::Runtime &runtime, NSArray *value)
{
  jsi::Array result = jsi::Array(runtime, value.count);
  for (size_t i = 0; i < value.count; i++) {
    result.setValueAtIndex(runtime, i, convertObjCObjectToJSIValue(runtime, value[i]));
  }
  return result;
}

std::vector<jsi::Value> convertNSArrayToStdVector(jsi::Runtime &runtime, NSArray *value)
{
  std::vector<jsi::Value> result;
  for (size_t i = 0; i < value.count; i++) {
    result.emplace_back(convertObjCObjectToJSIValue(runtime, value[i]));
  }
  return result;
}

NSString *convertJSIStringToNSString(jsi::Runtime &runtime, const jsi::String &value)
{
  return [NSString stringWithUTF8String:value.utf8(runtime).c_str()];
}

NSArray *convertJSIArrayToNSArray(
    jsi::Runtime &runtime,
    const jsi::Array &value,
    std::shared_ptr<react::JSCallInvoker> jsInvoker)
{
  size_t size = value.size(runtime);
  NSMutableArray *result = [NSMutableArray new];
  for (size_t i = 0; i < size; i++) {
    // Insert kCFNull when it's `undefined` value to preserve the indices.
    [result
        addObject:convertJSIValueToObjCObject(runtime, value.getValueAtIndex(runtime, i), jsInvoker) ?: (id)kCFNull];
  }
  return [result copy];
}

NSDictionary *convertJSIObjectToNSDictionary(
    jsi::Runtime &runtime,
    const jsi::Object &value,
    std::shared_ptr<react::JSCallInvoker> jsInvoker)
{
  jsi::Array propertyNames = value.getPropertyNames(runtime);
  size_t size = propertyNames.size(runtime);
  NSMutableDictionary *result = [NSMutableDictionary new];
  for (size_t i = 0; i < size; i++) {
    jsi::String name = propertyNames.getValueAtIndex(runtime, i).getString(runtime);
    NSString *k = convertJSIStringToNSString(runtime, name);
    id v = convertJSIValueToObjCObject(runtime, value.getProperty(runtime, name), jsInvoker);
    if (v) {
      result[k] = v;
    }
  }
  return [result copy];
}




RCTResponseSenderBlock convertJSIFunctionToCallback(
    jsi::Runtime &runtime,
    const jsi::Function &value,
    std::shared_ptr<react::JSCallInvoker> jsInvoker)
{
  __block auto wrapper = std::make_shared<react::CallbackWrapper>(value.getFunction(runtime), runtime, jsInvoker);
  return ^(NSArray *responses) {
    if (wrapper == nullptr) {
      throw std::runtime_error("callback arg cannot be called more than once");
    }

    std::shared_ptr<react::CallbackWrapper> rw = wrapper;
    wrapper->jsInvoker().invokeAsync([rw, responses]() {
      std::vector<jsi::Value> args = convertNSArrayToStdVector(rw->runtime(), responses);
      rw->callback().call(rw->runtime(), (const jsi::Value *)args.data(), args.size());
    });

    // The callback is single-use, so force release it here.
    // Doing this also releases the jsi::jsi::Function early, since this block may not get released by ARC for a while,
    // because the method invocation isn't guarded with @autoreleasepool.
    wrapper = nullptr;
  };
}


using PromiseInvocationBlock = void (^)(jsi::Runtime &rt, std::shared_ptr<PromiseWrapper> wrapper);


jsi::Value
createPromise(jsi::Runtime &runtime, std::shared_ptr<react::JSCallInvoker> jsInvoker, PromiseInvocationBlock invoke)
{
  if (!invoke) {
    return jsi::Value::undefined();
  }

  jsi::Function Promise = runtime.global().getPropertyAsFunction(runtime, "Promise");

  // Note: the passed invoke() block is not retained by default, so let's retain it here to help keep it longer.
  // Otherwise, there's a risk of it getting released before the promise function below executes.
  PromiseInvocationBlock invokeCopy = [invoke copy];
  jsi::Function fn = jsi::Function::createFromHostFunction(
      runtime,
      jsi::PropNameID::forAscii(runtime, "fn"),
      2,
      [invokeCopy, jsInvoker](jsi::Runtime &rt, const jsi::Value &thisVal, const jsi::Value *args, size_t count) {
        if (count != 2) {
          throw std::invalid_argument("Promise fn arg count must be 2");
        }
        if (!invokeCopy) {
          return jsi::Value::undefined();
        }
        jsi::Function resolve = args[0].getObject(rt).getFunction(rt);
        jsi::Function reject = args[1].getObject(rt).getFunction(rt);
        auto wrapper = PromiseWrapper::create(std::move(resolve), std::move(reject), rt, jsInvoker);
        invokeCopy(rt, wrapper);
        return jsi::Value::undefined();
      });

  return Promise.callAsConstructor(runtime, fn);
}





//
///**
// * All helper functions are ObjC++ specific.
// */

//
//jsi::Value convertObjCObjectToJSIValue(jsi::Runtime &runtime, id value)
//{
//  if ([value isKindOfClass:[NSString class]]) {
//    return convertNSStringToJSIString(runtime, (NSString *)value);
//  } else if ([value isKindOfClass:[NSNumber class]]) {
//    if ([value isKindOfClass:[@YES class]]) {
//      return convertNSNumberToJSIBoolean(runtime, (NSNumber *)value);
//    }
//    return convertNSNumberToJSINumber(runtime, (NSNumber *)value);
//  } else if ([value isKindOfClass:[NSDictionary class]]) {
//    return convertNSDictionaryToJSIObject(runtime, (NSDictionary *)value);
//  } else if ([value isKindOfClass:[NSArray class]]) {
//    return convertNSArrayToJSIArray(runtime, (NSArray *)value);
//  } else if (value == (id)kCFNull) {
//    return jsi::Value::null();
//  }
//  return jsi::Value::undefined();
//}
//


//NSArray *convertJSIArrayToNSArray(
//    jsi::Runtime &runtime,
//    const jsi::Array &value)
//{
//  size_t size = value.size(runtime);
//  NSMutableArray *result = [NSMutableArray new];
//  for (size_t i = 0; i < size; i++) {
//    // Insert kCFNull when it's `undefined` value to preserve the indices.
//    [result
//        addObject:convertJSIValueToObjCObject(runtime, value.getValueAtIndex(runtime, i)) ?: (id)kCFNull];
//  }
//  return [result copy];
//}
//
//NSDictionary *convertJSIObjectToNSDictionary(
//    jsi::Runtime &runtime,
//    const jsi::Object &value)
//{
//  jsi::Array propertyNames = value.getPropertyNames(runtime);
//  size_t size = propertyNames.size(runtime);
//  NSMutableDictionary *result = [NSMutableDictionary new];
//  for (size_t i = 0; i < size; i++) {
//    jsi::String name = propertyNames.getValueAtIndex(runtime, i).getString(runtime);
//    NSString *k = convertJSIStringToNSString(runtime, name);
//    id v = convertJSIValueToObjCObject(runtime, value.getProperty(runtime, name));
//    if (v) {
//      result[k] = v;
//    }
//  }
//  return [result copy];
//}
//
//RCTResponseSenderBlock convertJSIFunctionToCallback(
//    jsi::Runtime &runtime,
//    const jsi::Function &value)
//{
//  __block auto cb = value.getFunction(runtime);
//
//  return ^(NSArray *responses) {
//    cb.call(runtime, convertNSArrayToJSIArray(runtime, responses), 2);
//  };
//}
//
//id convertJSIValueToObjCObject(
//    jsi::Runtime &runtime,
//    const jsi::Value &value)
//{
//  if (value.isUndefined() || value.isNull()) {
//    return nil;
//  }
//  if (value.isBool()) {
//    return @(value.getBool());
//  }
//  if (value.isNumber()) {
//    return @(value.getNumber());
//  }
//  if (value.isString()) {
//    return convertJSIStringToNSString(runtime, value.getString(runtime));
//  }
//  if (value.isObject()) {
//    jsi::Object o = value.getObject(runtime);
//    if (o.isArray(runtime)) {
//      return convertJSIArrayToNSArray(runtime, o.getArray(runtime));
//    }
//    if (o.isFunction(runtime)) {
//      return convertJSIFunctionToCallback(runtime, std::move(o.getFunction(runtime)));
//    }
//    return convertJSIObjectToNSDictionary(runtime, o);
//  }
//
//  throw std::runtime_error("Unsupported jsi::jsi::Value kind");
//}
//
//static id convertJSIValueToObjCObject(
//    jsi::Runtime &runtime,
//    const jsi::Value &value,
//    std::shared_ptr<react::JSCallInvoker> jsInvoker);
//static NSString *convertJSIStringToNSString(jsi::Runtime &runtime, const jsi::String &value);
//static NSArray *convertJSIArrayToNSArray(
//    jsi::Runtime &runtime,
//    const jsi::Array &value,
//    std::shared_ptr<react::JSCallInvoker> jsInvoker
//);
//static NSDictionary *convertJSIObjectToNSDictionary(
//    jsi::Runtime &runtime,
//    const jsi::Object &value,
//    std::shared_ptr<react::JSCallInvoker> jsInvoker);
//static RCTResponseSenderBlock convertJSIFunctionToCallback(
//    jsi::Runtime &runtime,
//    const jsi::Function &value,
//    std::shared_ptr<react::JSCallInvoker> jsInvoker);
//static id convertJSIValueToObjCObject(
//    jsi::Runtime &runtime,
//    const jsi::Value &value,
//    std::shared_ptr<react::JSCallInvoker> jsInvoker);
//static RCTResponseSenderBlock convertJSIFunctionToCallback(
//    jsi::Runtime &runtime,
//    const jsi::Function &value,
//    std::shared_ptr<react::JSCallInvoker> jsInvoker);
//
//// Helper for creating Promise object.
//struct PromiseWrapper : public react::LongLivedObject {
//  static std::shared_ptr<PromiseWrapper> create(
//      jsi::Function resolve,
//      jsi::Function reject,
//      jsi::Runtime &runtime,
//      std::shared_ptr<react::JSCallInvoker> jsInvoker)
//  {
//    auto instance = std::make_shared<PromiseWrapper>(std::move(resolve), std::move(reject), runtime, jsInvoker);
//    // This instance needs to live longer than the caller's scope, since the resolve/reject functions may not
//    // be called immediately. Doing so keeps it alive at least until resolve/reject is called, or when the
//    // collection is cleared (e.g. when JS reloads).
//    react::LongLivedObjectCollection::get().add(instance);
//    return instance;
//  }
//
//  PromiseWrapper(
//      jsi::Function resolve,
//      jsi::Function reject,
//      jsi::Runtime &runtime,
//      std::shared_ptr<react::JSCallInvoker> jsInvoker)
//      : resolveWrapper(std::make_shared<react::CallbackWrapper>(std::move(resolve), runtime, jsInvoker)),
//        rejectWrapper(std::make_shared<react::CallbackWrapper>(std::move(reject), runtime, jsInvoker)),
//        runtime(runtime),
//        jsInvoker(jsInvoker)
//  {
//  }
//
//  RCTPromiseResolveBlock resolveBlock()
//  {
//    return ^(id result) {
//      if (resolveWrapper == nullptr) {
//        throw std::runtime_error("Promise resolve arg cannot be called more than once");
//      }
//
//      // Retain the resolveWrapper so that it stays alive inside the lambda.
//      std::shared_ptr<react::CallbackWrapper> retainedWrapper = resolveWrapper;
//      jsInvoker->invokeAsync([retainedWrapper, result]() {
//        jsi::Runtime &rt = retainedWrapper->runtime();
//        jsi::Value arg = convertObjCObjectToJSIValue(rt, result);
//        retainedWrapper->callback().call(rt, arg);
//      });
//
//      // Prevent future invocation of the same resolve() function.
//      cleanup();
//    };
//  }
//
//  RCTPromiseRejectBlock rejectBlock()
//  {
//    return ^(NSString *code, NSString *message, NSError *error) {
//      // TODO: There is a chance `this` is no longer valid when this block executes.
//      if (rejectWrapper == nullptr) {
//        throw std::runtime_error("Promise reject arg cannot be called more than once");
//      }
//
//      // Retain the resolveWrapper so that it stays alive inside the lambda.
//      std::shared_ptr<react::CallbackWrapper> retainedWrapper = rejectWrapper;
//      NSDictionary *jsError = RCTJSErrorFromCodeMessageAndNSError(code, message, error);
//      jsInvoker->invokeAsync([retainedWrapper, jsError]() {
//        jsi::Runtime &rt = retainedWrapper->runtime();
//        jsi::Value arg = convertNSDictionaryToJSIObject(rt, jsError);
//        retainedWrapper->callback().call(rt, arg);
//      });
//
//      // Prevent future invocation of the same resolve() function.
//      cleanup();
//    };
//  }
//
//  void cleanup()
//  {
//    resolveWrapper = nullptr;
//    rejectWrapper = nullptr;
//    allowRelease();
//  }
//
//  // CallbackWrapper is used here instead of just holding on the jsi jsi::Function in order to force release it after
//  // either the resolve() or the reject() is called. jsi jsi::Function does not support explicit releasing, so we need
//  // an extra mechanism to control that lifecycle.
//  std::shared_ptr<react::CallbackWrapper> resolveWrapper;
//  std::shared_ptr<react::CallbackWrapper> rejectWrapper;
//  jsi::Runtime &runtime;
//  std::shared_ptr<react::JSCallInvoker> jsInvoker;
//};
//
//using PromiseInvocationBlock = void (^)(jsi::Runtime &rt, std::shared_ptr<PromiseWrapper> wrapper);
//static jsi::Value
//createPromise(jsi::Runtime &runtime, std::shared_ptr<react::JSCallInvoker> jsInvoker, PromiseInvocationBlock invoke)
//{
//  if (!invoke) {
//    return jsi::Value::undefined();
//  }
//
//  jsi::Function Promise = runtime.global().getPropertyAsFunction(runtime, "Promise");
//
//  // Note: the passed invoke() block is not retained by default, so let's retain it here to help keep it longer.
//  // Otherwise, there's a risk of it getting released before the promise function below executes.
//  PromiseInvocationBlock invokeCopy = [invoke copy];
//  jsi::Function fn = jsi::Function::createFromHostFunction(
//      runtime,
//      jsi::PropNameID::forAscii(runtime, "fn"),
//      2,
//      [invokeCopy, jsInvoker](jsi::Runtime &rt, const jsi::Value &thisVal, const jsi::Value *args, size_t count) {
//        if (count != 2) {
//          throw std::invalid_argument("Promise fn arg count must be 2");
//        }
//        if (!invokeCopy) {
//          return jsi::Value::undefined();
//        }
//        jsi::Function resolve = args[0].getObject(rt).getFunction(rt);
//        jsi::Function reject = args[1].getObject(rt).getFunction(rt);
//        auto wrapper = PromiseWrapper::create(std::move(resolve), std::move(reject), rt, jsInvoker);
//        invokeCopy(rt, wrapper);
//        return jsi::Value::undefined();
//      });
//
//  return Promise.callAsConstructor(runtime, fn);
//}


id convertJSIValueToObjCObject(
    jsi::Runtime &runtime,
    const jsi::Value &value,
    std::shared_ptr<react::JSCallInvoker> jsInvoker)
{
  if (value.isUndefined() || value.isNull()) {
    return nil;
  }
  if (value.isBool()) {
    return @(value.getBool());
  }
  if (value.isNumber()) {
    return @(value.getNumber());
  }
  if (value.isString()) {
    return convertJSIStringToNSString(runtime, value.getString(runtime));
  }
  if (value.isObject()) {
    jsi::Object o = value.getObject(runtime);
    if (o.isArray(runtime)) {
      return convertJSIArrayToNSArray(runtime, o.getArray(runtime), jsInvoker);
    }
    if (o.isFunction(runtime)) {
      return convertJSIFunctionToCallback(runtime, std::move(o.getFunction(runtime)), jsInvoker);
    }
    return convertJSIObjectToNSDictionary(runtime, o, jsInvoker);
  }

  throw std::runtime_error("Unsupported jsi::jsi::Value kind");
}


