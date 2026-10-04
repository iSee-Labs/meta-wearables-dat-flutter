// Rebuilds the Dart display DSL (JSON maps) into Meta's MWDATDisplay views.
//
// Node shapes (produced by Dart `DisplayNode.toJson`):
//   flexBox     direction, spacing, alignment, crossAlignment, wrap, padding |
//               paddingInsets{top,bottom,start,end}, background, onTapId, children
//   text        text, style, color
//   image       uri | bytes, sizePreset, cornerRadius
//   icon        iconName, style
//   button      label, style, iconName, onClickId, actionRole
//   buttonGroup alignment, buttons[button]
//   videoPlayer uri, codec, onPlaybackEventId   (root only)
// Every component accepts flexGrow, flexShrink and alignSelf.
//
// Values the SDK cannot express are mapped to the closest supported value
// and reported as warnings so Dart can surface them.

import Flutter
import Foundation
import MWDATDisplay
import UIKit

@MainActor
struct DisplayNodeBuilder {
  typealias Emit = @Sendable (_ callbackId: String, _ type: String) -> Void

  let emit: Emit
  private(set) var warnings: [String] = []

  init(emit: @escaping Emit) {
    self.emit = emit
  }

  /// Builds a non-video root. Any non-flexBox root is wrapped in a column.
  mutating func buildRoot(_ json: [String: Any]) -> FlexBox {
    if (json["type"] as? String) == "flexBox" {
      return buildFlexBox(json)
    }
    let child = buildComponent(json)
    return FlexBox(direction: .column) {
      if let child { child }
    }
  }

  mutating func buildComponent(_ json: [String: Any]) -> (any ViewComponent)? {
    switch json["type"] as? String {
    case "flexBox": return buildFlexBox(json)
    case "text": return buildText(json)
    case "image": return buildImage(json)
    case "button": return buildButton(json)
    case "buttonGroup": return buildButtonGroup(json)
    case "icon": return buildIcon(json)
    case "videoPlayer":
      warnings.append("videoPlayer is only supported as the root view; nested player ignored.")
      return nil
    case let other:
      warnings.append("Unknown display node type '\(other ?? "nil")' ignored.")
      return nil
    }
  }

  mutating func buildFlexBox(_ json: [String: Any]) -> FlexBox {
    var children: [any ViewComponent] = []
    for child in json["children"] as? [[String: Any]] ?? [] {
      if let built = buildComponent(child) { children.append(built) }
    }
    let built = children
    var box = FlexBox(
      direction: direction(json["direction"] as? String),
      spacing: CGFloat(number(json["spacing"]) ?? 0),
      alignment: alignment(json["alignment"] as? String, field: "alignment") ?? .start,
      crossAlignment: alignment(json["crossAlignment"] as? String, field: "crossAlignment") ?? .start,
      wrap: (json["wrap"] as? Bool) ?? false,
      padding: padding(json)
    ) {
      for child in built { child }
    }
    if let bg = json["background"] as? String {
      box = box.background(bg == "card" ? .card : .none)
    }
    if json["cornerRadius"] != nil {
      warnings.append("FlexBox cornerRadius is not supported by the DAT Display SDK; ignored.")
    }
    if let tapId = json["onTapId"] as? String {
      let emit = self.emit
      box = box.onTap { emit(tapId, "tap") }
    }
    if let v = number(json["flexGrow"]) { box = box.flexGrow(Float(v)) }
    if let v = number(json["flexShrink"]) { box = box.flexShrink(Float(v)) }
    if let a = alignment(json["alignSelf"] as? String, field: "alignSelf") { box = box.alignSelf(a) }
    return box
  }

  mutating func buildText(_ json: [String: Any]) -> Text {
    var text = Text(
      json["text"] as? String ?? "",
      style: textStyle(json["style"] as? String),
      color: (json["color"] as? String) == "secondary" ? .secondary : .primary)
    if let v = number(json["flexGrow"]) { text = text.flexGrow(Float(v)) }
    if let v = number(json["flexShrink"]) { text = text.flexShrink(Float(v)) }
    if let a = alignment(json["alignSelf"] as? String, field: "alignSelf") { text = text.alignSelf(a) }
    return text
  }

  mutating func buildImage(_ json: [String: Any]) -> Image {
    let size: ImageSize = (json["sizePreset"] as? String) == "icon" ? .icon : .fill
    let radius = cornerRadius(json["cornerRadius"] as? String)
    var image: Image
    if let typed = json["bytes"] as? FlutterStandardTypedData, let ui = UIImage(data: typed.data) {
      image = Image(image: ui, sizePreset: size, cornerRadius: radius)
    } else {
      if json["bytes"] != nil {
        warnings.append("Image bytes could not be decoded; falling back to uri.")
      }
      image = Image(uri: json["uri"] as? String ?? "", sizePreset: size, cornerRadius: radius)
    }
    if let v = number(json["flexGrow"]) { image = image.flexGrow(Float(v)) }
    if let v = number(json["flexShrink"]) { image = image.flexShrink(Float(v)) }
    if let a = alignment(json["alignSelf"] as? String, field: "alignSelf") { image = image.alignSelf(a) }
    return image
  }

  mutating func buildIcon(_ json: [String: Any]) -> Icon? {
    guard let name = iconName(json["iconName"] as? String) else { return nil }
    var icon = Icon(name: name, style: (json["style"] as? String) == "outline" ? .outline : .filled)
    if let v = number(json["flexGrow"]) { icon = icon.flexGrow(Float(v)) }
    if let v = number(json["flexShrink"]) { icon = icon.flexShrink(Float(v)) }
    if let a = alignment(json["alignSelf"] as? String, field: "alignSelf") { icon = icon.alignSelf(a) }
    return icon
  }

  mutating func buildButton(_ json: [String: Any]) -> Button {
    let onClick: (@Sendable () -> Void)? = (json["onClickId"] as? String).map { id in
      let emit = self.emit
      return { emit(id, "click") }
    }
    let icon = (json["iconName"] as? String).flatMap { iconName($0) }
    var button = Button(
      label: json["label"] as? String ?? "",
      style: buttonStyle(json["style"] as? String),
      iconName: icon,
      onClick: onClick)
    if (json["actionRole"] as? String) == "primary" { button = button.actionRole(.primary) }
    if let v = number(json["flexGrow"]) { button = button.flexGrow(Float(v)) }
    if let v = number(json["flexShrink"]) { button = button.flexShrink(Float(v)) }
    if let a = alignment(json["alignSelf"] as? String, field: "alignSelf") { button = button.alignSelf(a) }
    return button
  }

  mutating func buildButtonGroup(_ json: [String: Any]) -> ButtonGroup {
    var buttons: [Button] = []
    for child in json["buttons"] as? [[String: Any]] ?? [] {
      buttons.append(buildButton(child))
    }
    let built = buttons
    let groupAlignment: ButtonGroupAlignment
    switch json["alignment"] as? String {
    case "start": groupAlignment = .start
    case "end": groupAlignment = .end
    default: groupAlignment = .center
    }
    var group = ButtonGroup(alignment: groupAlignment) {
      for button in built { button }
    }
    if let v = number(json["flexGrow"]) { group = group.flexGrow(Float(v)) }
    if let v = number(json["flexShrink"]) { group = group.flexShrink(Float(v)) }
    if let a = alignment(json["alignSelf"] as? String, field: "alignSelf") { group = group.alignSelf(a) }
    return group
  }

  // MARK: - Value mapping

  private func number(_ value: Any?) -> Double? {
    switch value {
    case let v as Double: return v
    case let v as Int: return Double(v)
    case let v as NSNumber: return v.doubleValue
    default: return nil
    }
  }

  private func padding(_ json: [String: Any]) -> EdgeInsets? {
    if let insets = json["paddingInsets"] as? [String: Any] {
      return EdgeInsets(
        top: CGFloat(number(insets["top"]) ?? 0),
        bottom: CGFloat(number(insets["bottom"]) ?? 0),
        leading: CGFloat(number(insets["start"]) ?? 0),
        trailing: CGFloat(number(insets["end"]) ?? 0))
    }
    return number(json["padding"]).map { EdgeInsets(all: CGFloat($0)) }
  }

  private func direction(_ value: String?) -> Direction {
    switch value {
    case "row": return .row
    case "rowReverse": return .rowReverse
    case "columnReverse": return .columnReverse
    default: return .column
    }
  }

  private mutating func alignment(_ value: String?, field: String) -> Alignment? {
    switch value {
    case nil: return nil
    case "start": return .start
    case "center": return .center
    case "end": return .end
    case "stretch": return .stretch
    case let other:
      warnings.append("\(field) '\(other ?? "")' is not supported by the DAT Display SDK; using center.")
      return .center
    }
  }

  private func textStyle(_ value: String?) -> TextStyle {
    switch value {
    case "heading": return .heading
    case "meta": return .meta
    default: return .body
    }
  }

  private mutating func cornerRadius(_ value: String?) -> CornerRadius {
    switch value {
    case "small": return .small
    case "medium": return .medium
    case "large":
      warnings.append("cornerRadius 'large' is not supported by the DAT Display SDK; using medium.")
      return .medium
    default: return CornerRadius.none
    }
  }

  private func buttonStyle(_ value: String?) -> ButtonStyle {
    switch value {
    case "secondary": return .secondary
    case "outline": return .outline
    default: return .primary
    }
  }

  private mutating func iconName(_ value: String?) -> IconName? {
    guard let value else { return nil }
    if let name = IconName(rawValue: Self.iconRawValue(value)) ?? IconName(rawValue: value) { return name }
    warnings.append("Unknown icon '\(value)' ignored.")
    return nil
  }

  /// The SDK's `IconName` raw values are snake_case (`checkmark_circle`,
  /// `circle_8_rays_large`, `arrow_u_left`); the wire uses lowerCamelCase.
  static func iconRawValue(_ camel: String) -> String {
    let chars = Array(camel)
    var out = ""
    for (i, c) in chars.enumerated() {
      if i > 0 {
        let prev = chars[i - 1]
        let next: Character? = i + 1 < chars.count ? chars[i + 1] : nil
        if c.isUppercase && (prev.isLowercase || prev.isNumber || (prev.isUppercase && next?.isLowercase == true)) {
          out.append("_")
        } else if c.isNumber && prev.isLetter {
          out.append("_")
        }
      }
      out.append(contentsOf: c.lowercased())
    }
    return out
  }
}
