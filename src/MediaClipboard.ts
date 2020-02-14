import { NativeModules, NativeEventEmitter, Platform } from "react-native";

export type MediaSource = {
  uri: string;
  mimeType: string;
  width: number;
  height: number;
};

export type ClipboardResponse = {
  urls: Array<string>;
  strings: Array<string>;
  hasImages: Boolean;
  hasURLs: Boolean;
  hasStrings: Boolean;
};

export let MediaClipboard = NativeModules["MediaClipboard"];

if (
  // @ts-ignore
  process.env.NODE_ENV !== "production" &&
  !MediaClipboard &&
  Platform.OS === "ios"
) {
  console.log({ MediaClipboard });
  throw new Error(
    "Please ensure react-native-media-clipboard is linked, that you ran pod install, that you imported <react-native-media-clipboard/MediaClipboard.h> in your AppDelegate.m, and that you re-built the iOS app."
  );
} else if (!MediaClipboard && Platform.OS !== "ios") {
  MediaClipboard = {
    clipboard: {
      urls: [],
      strings: [],
      hasImages: false,
      hasURLs: false,
      hasStrings: false
    },
    mediaSource: null
  };
}

const emitter = Platform.select({
  ios: new NativeEventEmitter(MediaClipboard),
  android: null
});

export const listenToClipboardChanges = listener =>
  emitter && emitter.addListener("MediaClipboardChange", listener);

export const stopListeningToClipboardChanges = listener =>
  emitter && emitter.removeListener("MediaClipboardChange", listener);

export const listenToClipboardRemove = listener =>
  emitter && emitter.addListener("MediaClipboardRemove", listener);

export const stopListeningToClipboardRemove = listener =>
  emitter && emitter.removeListener("MediaClipboardRemove", listener);

export const getClipboardContents = (): Promise<ClipboardResponse> => {
  return new Promise((resolve, reject) => {
    if (Platform.OS === "android") {
      resolve({
        urls: [],
        strings: [],
        hasImages: false,
        hasURLs: false,
        hasStrings: false
      });
      return;
    }

    MediaClipboard.getContent((err, contents) => {
      if (err) {
        reject(err);
        return;
      } else {
        resolve(contents);
      }
    });
  });
};

export const getClipboardMediaSource = (): Promise<MediaSource | null> => {
  if (Platform.OS === "android") {
    return Promise.resolve(null);
  }

  // @ts-ignore
  if (typeof global.Clipboard !== "undefined") {
    // @ts-ignore
    return global.Clipboard.getMediaSource();
  } else {
    return new Promise(resolve =>
      MediaClipboard.clipboardMediaSource((_, content) => {
        resolve(content);
        return;
      })
    );
  }
};
