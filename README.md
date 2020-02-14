# react-native-media-clipboard

React Native has several libraries that let you get the contents of the clipboard, but none of them support images.

`react-native-media-clipboard` suports:

- images (including exposing the mime type)
- multiple strings,
- multiple URLs

## Getting started

`$ npm install react-native-media-clipboard --save`

### Installation (iOS only)

1. `cd ios && pod install`
2. Open your `AppDelegate.m`:
3. Add the following line somehwere near the top:

```h
#import <react-native-media-clipboard/MediaClipboard.h>
```

4. If your project does not contain any Swift code, then you need to create a bridging header. Basically, just create an empty .swift file from Xcode -> New. It will prompt you asking if you want to create a bridging header. Say yes. If your project already has Swift code (or a bridging header), just ignore this step.

5. [Optional] Run `[MediaClipboard onApplicationBecomeActive]` in `applicationDidBecomeActive` within your `AppDelegate`, like this:

```objc
- (void)applicationDidBecomeActive:(UIApplication *)application {
  [MediaClipboard onApplicationBecomeActive];
}
```

This makes sure that the clipboard is in sync if the application went into the background.

6. Re-run your app (`react-native run-ios`)

## Usage

```javascript
import {
  ClipboardContext,
  ClipboardProvider
} from "react-native-media-clipboard";
```

7. At the root of your application, add `<ClipboardProvider>` in the render method, like this:

```javascript
<ClipboardProvider>
  <MyVeryRealApp>{children}</MyVeryRealApp>
</ClipboardProvider>
```

8. `ClipboardContext` contains a `clipboard` and a `mediaSource` object. It automatically updates whenever the user copies something to their clipboard or removes something from their clipboard.

```javascript
const { clipboard, mediaSource } = React.useContext(ClipboardContext);

// Example mediaSource:
{
  "mimeType": "image/png",
  "scale": 1,
  "width": 828,
  "uri": "file:///tmp/C4A65610-E644-44C2-AC54-25A8AD56A4C6.png",
  "height": 1792
}

// Example clipboard:
{
  clipboard: {
    urls: [],
    strings: [],
    hasImages: false,
    hasURLs: false,
    hasStrings: false
  },
  mediaSource: null
};

// You can just pass in the `mediaSource` object to the built-in Image component. As long as the mediaSource object is not null, it should just work.
<Image source={mediaSource} />
```

There are type definitions for these, so you shouldn't need to refer back to this much.

-

Images are saved in the temporary directory for the app. It does not send `data` URIs across the bridge.

There is a JSI implementation of this as well, however I haven't finished porting it to this library. A contributor is welcome to submit a PR for that :)
