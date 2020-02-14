//
//  MediaClipboardC++Interop.h
//  MediaClipboard
//
//  Created by Jarred WSumner on 2/13/20.
//  Copyright © 2020 Yeet. All rights reserved.
//

#import <Foundation/Foundation.h>


@class MediaClipboard;

NS_ASSUME_NONNULL_BEGIN

@interface MediaClipboardC__Interop : NSObject

+ (void)install:(MediaClipboard*)clipboard;

@end

NS_ASSUME_NONNULL_END
