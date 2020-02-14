

//
//  MediaClipboard.swift
//  Media
//
//  Created by Jarred WSumner on 12/13/19.
//  Copyright © 2019 Yeet. All rights reserved.
//

import Foundation
import UIKit

@objc(MediaClipboard)
class MediaClipboard: RCTEventEmitter  {
  static let clipboardOperationQueue: OperationQueue = {
    var queue = OperationQueue()
    queue.name = "MediaClipboard"
    queue.maxConcurrentOperationCount = 1

    return queue
  }()

  enum EventNames : String {
    case change = "MediaClipboardChange"
    case remove = "MediaClipboardRemove"
  }

  static var changeCount = UIPasteboard.general.changeCount
  var listenerCount = 0

  @objc (onApplicationBecomeActive) static func onApplicationBecomeActive() {
    if changeCount != UIPasteboard.general.changeCount {
      NotificationCenter.default.post(name: UIPasteboard.changedNotification, object: nil)
      changeCount = UIPasteboard.general.changeCount
    }
  }

  override func startObserving() {
    super.startObserving()

    let needsSubscription = !hasListeners
    listenerCount += 1

    if needsSubscription {
      self.observePasteboardChange()
    }

  }

  override func stopObserving() {
    super.stopObserving()
    listenerCount -= 1

    let needsUnsubscription = !hasListeners

    if needsUnsubscription {
      self.stopObservingPasteboardChange()
    }
  }

  func observePasteboardChange() {
    NotificationCenter.default.addObserver(self, selector: #selector(handleChangeEvent(_:)), name: UIPasteboard.changedNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(handleRemoveEvent(_:)), name: UIPasteboard.removedNotification, object: nil)
  }

  func stopObservingPasteboardChange() {
    NotificationCenter.default.removeObserver(self, name: UIPasteboard.changedNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIPasteboard.removedNotification, object: nil)
  }

  @objc func handleChangeEvent(_ notification: NSNotification) {
    lastDictionaryValue = nil
    self.sendChangeEvent()
    MediaClipboard.changeCount = UIPasteboard.general.changeCount
  }

  @objc func handleRemoveEvent(_ notification: NSNotification) {
    lastDictionaryValue = nil
    self.sendChangeEvent()
    MediaClipboard.changeCount = UIPasteboard.general.changeCount
  }

  var hasListeners: Bool {
    return listenerCount > 0
  }

  override init() {
    super.init()
  }

  override var bridge: RCTBridge! {
    get {
      return super.bridge
    }

    set (newValue) {
      super.bridge = newValue


    }
  }


  func sendChangeEvent() {
    guard hasListeners else {
      return
    }

    sendEvent(withName: EventNames.change.rawValue, body: MediaClipboard.serializeContents())
  }

  func sendRemoveEvent() {
    guard hasListeners else {
      return
    }

    sendEvent(withName: EventNames.remove.rawValue, body: MediaClipboard.serializeContents())
  }

  override static func moduleName() -> String! {
    return "MediaClipboard";
  }

  @objc(serializeContents)
  static func serializeContents() -> [String: Any] {
    var hasURLs = false
    var hasStrings = false


    if #available(iOS 10.0, *) {
      hasStrings = UIPasteboard.general.hasStrings
      hasURLs = UIPasteboard.general.hasURLs
    }

    var contents = [
      "urls": [],
      "strings": [],
      "hasImages": hasImagesInClipboard,
      "hasURLs": hasURLs,
      "hasStrings": hasStrings
      ] as [String : Any]

    if #available(iOS 10.0, *) {
      if UIPasteboard.general.hasURLs {
        contents["urls"] = UIPasteboard.general.urls?.map { url in
          return url.absoluteString
        }
      }
    } else {
      // Fallback on earlier versions
    }

    if #available(iOS 10.0, *) {
      if UIPasteboard.general.hasStrings {
        let strings = UIPasteboard.general.strings?.filter { string in
          guard let urls = contents["urls"] as? Array<String> else {
            return true
          }

          return !urls.contains(string)
        }

        if (strings?.count ?? 0) > 0  {
          contents["strings"] = strings
        } else {
          contents["hasStrings"] = false
        }
      }
    } else {
      // Fallback on earlier versions
    }

    return contents
  }


  override func supportedEvents() -> [String]! {
    return [
      EventNames.change.rawValue,
      EventNames.remove.rawValue
    ]
  }

  override static func requiresMainQueueSetup() -> Bool {
    return false
  }

  override func constantsToExport() -> [AnyHashable : Any]! {
    return ["clipboard": MediaClipboard.serializeContents(), "mediaSource": self.lastDictionaryValue ?? nil]
  }

  @objc(getContent:)
  func getContent(_ callback: @escaping RCTResponseSenderBlock) {
    callback([nil, MediaClipboard.serializeContents()])
  }

  @objc(lastDictionaryValue)
  var lastDictionaryValue: [String: Any]? = nil
  var lastSavedImage: UIImage? = nil

  @objc(hasImagesInClipboard)
  static var hasImagesInClipboard: Bool {
    let imageUTIs = MimeType.images().map {image in
      return image.utiType()
    }

    return UIPasteboard.general.contains(pasteboardTypes: imageUTIs)
  }

  @objc(clipboardMediaSource:)
  func clipboardMediaSource(_ callback: @escaping RCTResponseSenderBlock) {
    guard MediaClipboard.hasImagesInClipboard else {
      callback([nil, [:]])
      return
    }

    let image = UIPasteboard.general.image

    if lastSavedImage != nil && lastSavedImage == image && lastDictionaryValue != nil {
      callback([nil, lastDictionaryValue!])
    }

    var exportType: MimeType? = nil
    if UIPasteboard.general.contains(pasteboardTypes: [MimeType.jpg.utiType()]) {
      exportType = MimeType.jpg
    } else if UIPasteboard.general.contains(pasteboardTypes: [MimeType.png.utiType()]) {
      exportType = MimeType.png
    }


    guard exportType != nil else {
      callback([NSError(domain: "com.yeet.react-native-media-clipboard.genericError", code: 111, userInfo: nil)])
      return
    }

    DispatchQueue.global(qos: .background).async {
      guard let image = image else {
        callback([NSError(domain: "com.yeet.react-native-media-clipboard.genericError", code: 111, userInfo: nil)])
        return
      }

      guard let exportType = exportType else {
        callback([NSError(domain: "com.yeet.react-native-media-clipboard.genericError", code: 111, userInfo: nil)])
        return
      }

      let url = self.getExportURL(mimeType: exportType)
      var data: Data? = nil

      if exportType == .jpg {
        data = image.jpegData(compressionQuality: CGFloat(1.0))
      } else if exportType == .png {
         data = image.pngData()
      }

      guard data != nil else {
        callback([NSError(domain: "com.yeet.react-native-media-clipboard.writingDataError", code: 112, userInfo: nil), nil])
        return
      }

       do {
          try data?.write(to: url)
       } catch {
          callback([NSError(domain: "com.yeet.react-native-media-clipboard.writingDataError", code: 112, userInfo: nil), nil])
         return
       }

      let size = image.size


      let value = self.getDictionaryValue(url: url, mimeType: exportType, size: size, scale: image.scale)
      self.lastDictionaryValue = value
      self.lastSavedImage = image

      callback([nil, value])
    }
  }

  open func getExportURL(mimeType: MimeType) -> URL {
    return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString.appending(".\(mimeType.fileExtension())"))
  }


  open func getDictionaryValue(url: URL, mimeType: MimeType, size: CGSize, scale: CGFloat) -> [String: Any] {
    return [
      "uri": url.absoluteString,
      "mimeType": mimeType.rawValue,
      "width": size.width,
      "height": size.height,
      "scale": scale,
    ]
  }

  deinit {
    stopObservingPasteboardChange()
  }

}


