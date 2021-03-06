# react-native-media-clipboard
<a href="https://github.com/Jarred-Sumner/react-native-media-clipboard/blob/master/README.md#installation-ios-only"><img height=200 src="https://user-images.githubusercontent.com/709451/74530526-1f6afc00-4edf-11ea-8706-f4273b80040e.png" /></a>

React Native has several libraries that let you get the contents of the clipboard, but none of them support images.

`react-native-media-clipboard` suports:

- images
- strings
- URLs

## Getting started

`$ npm install react-native-media-clipboard --save`

### Installation (iOS only)

1. `cd ios && pod install`
2. Add the following line near the top of `AppDelegate.h`:

```h
#import <react-native-media-clipboard/MediaClipboard.h>
```

3. [Optional] Inside the AppDelegate `@implementation` add this:

```objc
- (void)applicationDidBecomeActive:(UIApplication *)application {
  [MediaClipboard onApplicationBecomeActive];
}
```

<sup>This makes sure that the clipboard is in sync if the application went into the background.</sup>

##### Swift bridging header

If your project does not contain any Swift code, then you need to create a bridging header – or you'll get a bunch of strange build errors.

4. Xcode -> File -> New -> Create an empty .swift file. It will prompt you asking if you want to create a bridging header. Say yes.

If your project already has Swift code (or a bridging header), just ignore this step.

5. Re-build your app: `react-native run-ios`

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
  urls: [],
  strings: [],
  hasImages: false,
  hasURLs: false,
  hasStrings: false
};

// You can just pass in the `mediaSource` object to the built-in Image component. As long as the mediaSource object is not null, it should just work.
<Image source={mediaSource} />
```

There are type definitions for these, so you shouldn't need to refer back to this much.

---

This library is iOS only. There is no Android support.

Images are saved in the temporary directory for the app in a background thread. It does not send `data` URIs across the bridge.

There is a JSI implementation of this as well, however I haven't finished porting it to this library. A contributor is welcome to submit a PR for that :)

### Example repo

Example repo: [react-native-media-clipboard-example](https://github.com/Jarred-Sumner/react-native-media-clipboard-example)

<img src="https://user-images.githubusercontent.com/709451/74530537-242fb000-4edf-11ea-913a-f5ae50be3601.png"  height=400 />
