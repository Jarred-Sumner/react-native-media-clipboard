import * as React from "react";
import {
  MediaClipboard,
  ClipboardResponse,
  listenToClipboardChanges,
  stopListeningToClipboardChanges,
  listenToClipboardRemove,
  stopListeningToClipboardRemove,
  getClipboardMediaSource,
  MediaSource
} from "./MediaClipboard";

export type Clipboard = {
  clipboard: ClipboardResponse;
  mediaSource: MediaSource | null;
};

export const ClipboardContext = React.createContext<Clipboard>({
  clipboard: MediaClipboard.clipboard,
  mediaSource: MediaClipboard.mediaSource || null
});

export type ClipboardProviderState = {
  contextValue: Clipboard;
};

export type ClipboardProviderProps = { children: any };

export class ClipboardProvider extends React.Component<
  ClipboardProviderProps,
  ClipboardProviderState
> {
  constructor(props: ClipboardProviderProps) {
    super(props);

    // @ts-ignore
    this.state = {
      contextValue: ClipboardProvider.buildContextValue(
        MediaClipboard.clipboard,
        MediaClipboard.mediaSource || null
      )
    };
  }

  static buildContextValue(
    clipboard: ClipboardResponse,
    mediaSource: MediaSource | null
  ): Clipboard {
    return {
      clipboard,
      mediaSource:
        !mediaSource || Object.keys(mediaSource).length === 0
          ? null
          : mediaSource
    };
  }

  handleClipboardChange = (clipboard: ClipboardResponse) => {
    getClipboardMediaSource().then(mediaSource => {
      // @ts-ignore
      this.setState({
        contextValue: ClipboardProvider.buildContextValue(
          clipboard,
          mediaSource || null
        )
      });
    });
  };

  componentDidMount() {
    listenToClipboardChanges(this.handleClipboardChange);
    listenToClipboardRemove(this.handleClipboardChange);

    if (
      // @ts-ignore
      this.state.contextValue.clipboard.hasImages &&
      // @ts-ignore
      !this.state.contextValue.mediaSource
    ) {
      this.updateMediaSource();
    }
  }

  updateMediaSource = () => {
    getClipboardMediaSource().then(mediaSource => {
      // @ts-ignore
      this.setState({
        contextValue: ClipboardProvider.buildContextValue(
          // @ts-ignore
          this.state.contextValue.clipboard,
          mediaSource
        )
      });
    });
  };

  componentWillUnmount() {
    stopListeningToClipboardChanges(this.handleClipboardChange);
    stopListeningToClipboardRemove(this.handleClipboardChange);
  }

  render() {
    // @ts-ignore
    const { children } = this.props;
    return (
      // @ts-ignore
      <ClipboardContext.Provider value={this.state.contextValue}>
        {children}
      </ClipboardContext.Provider>
    );
  }
}
