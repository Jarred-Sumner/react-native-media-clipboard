//
//  MediaClipboardC++Interop.m
//  MediaClipboard
//
//  Created by Jarred WSumner on 2/13/20.
//  Copyright © 2020 Yeet. All rights reserved.
//

#import "MediaClipboardC++Interop.h"
#import "MediaClipboardJSI.h"



@implementation MediaClipboardC__Interop

+(void)install:(MediaClipboard *)clipboard {
  MediaClipboardJSI::install(clipboard);
}

@end

