import 'dart:typed_data';

import 'package:meta_wearables_dat_flutter/src/models/display/display_icon_name.dart';
import 'package:meta_wearables_dat_flutter/src/models/display/display_playback_event.dart';

/// Layout direction of a [FlexBox]'s children.
enum DisplayDirection {
  /// Horizontal.
  row('row'),

  /// Vertical (default).
  column('column'),

  /// Horizontal, reversed.
  rowReverse('rowReverse'),

  /// Vertical, reversed.
  columnReverse('columnReverse');

  const DisplayDirection(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Alignment of children (main axis, cross axis or `alignSelf`).
enum DisplayAlignment {
  /// Start.
  start('start'),

  /// Center.
  center('center'),

  /// End.
  end('end'),

  /// Stretch to fill the cross axis.
  stretch('stretch'),

  /// Not supported by the DAT Display SDK; rendered as [center].
  @Deprecated('Not supported by the DAT Display SDK; renders as center')
  spaceBetween('spaceBetween'),

  /// Not supported by the DAT Display SDK; rendered as [center].
  @Deprecated('Not supported by the DAT Display SDK; renders as center')
  spaceAround('spaceAround'),

  /// Not supported by the DAT Display SDK; rendered as [center].
  @Deprecated('Not supported by the DAT Display SDK; renders as center')
  spaceEvenly('spaceEvenly');

  const DisplayAlignment(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Typographic style of a [DisplayText].
enum DisplayTextStyle {
  /// Heading.
  heading('heading'),

  /// Body (default).
  body('body'),

  /// De-emphasised metadata.
  meta('meta');

  const DisplayTextStyle(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Color role of a [DisplayText].
enum DisplayTextColor {
  /// Primary (default).
  primary('primary'),

  /// Secondary.
  secondary('secondary');

  const DisplayTextColor(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Sizing preset of a [DisplayImage].
enum DisplayImageSize {
  /// Fill the available width, keeping the aspect ratio.
  fill('fill'),

  /// Icon-sized.
  icon('icon');

  const DisplayImageSize(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Corner-radius preset of a [DisplayImage].
enum DisplayCornerRadius {
  /// Square corners.
  none('none'),

  /// Small radius.
  small('small'),

  /// Medium radius.
  medium('medium'),

  /// Not supported by the DAT Display SDK; rendered as [medium].
  @Deprecated('Not supported by the DAT Display SDK; renders as medium')
  large('large');

  const DisplayCornerRadius(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Visual style of a [DisplayButton].
enum DisplayButtonStyle {
  /// High emphasis (default).
  primary('primary'),

  /// Lower emphasis.
  secondary('secondary'),

  /// Outlined.
  outline('outline');

  const DisplayButtonStyle(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Role of a [DisplayButton].
enum DisplayActionRole {
  /// The primary action. The first primary button gets focus when the view
  /// first renders.
  primary('primary');

  const DisplayActionRole(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Style of a [DisplayIcon].
enum DisplayIconStyle {
  /// Solid (default).
  filled('filled'),

  /// Hollow.
  outline('outline');

  const DisplayIconStyle(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Alignment of the buttons in a [DisplayButtonGroup].
enum DisplayButtonGroupAlignment {
  /// Start.
  start('start'),

  /// Center (default).
  center('center'),

  /// End.
  end('end');

  const DisplayButtonGroupAlignment(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Background preset of a [FlexBox].
enum FlexBoxBackground {
  /// None (default).
  none('none'),

  /// Card surface.
  card('card');

  const FlexBoxBackground(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Container format of a [VideoPlayer] source.
enum DisplayVideoCodec {
  /// MP4 (the only format the DAT Display SDK plays).
  mp4('mp4');

  const DisplayVideoCodec(this.wireName);

  /// The string used on the platform channel.
  final String wireName;
}

/// Per-edge padding of a [FlexBox], in logical pixels.
class DisplayEdgeInsets {
  /// Creates insets with individual values.
  const DisplayEdgeInsets.only({
    this.top = 0,
    this.bottom = 0,
    this.start = 0,
    this.end = 0,
  });

  /// Creates equal insets on every edge.
  const DisplayEdgeInsets.all(int value)
    : this.only(top: value, bottom: value, start: value, end: value);

  /// Creates horizontal and vertical insets.
  const DisplayEdgeInsets.symmetric({int horizontal = 0, int vertical = 0})
    : this.only(
        top: vertical,
        bottom: vertical,
        start: horizontal,
        end: horizontal,
      );

  /// Top inset.
  final int top;

  /// Bottom inset.
  final int bottom;

  /// Leading inset.
  final int start;

  /// Trailing inset.
  final int end;

  /// Platform-channel encoding.
  Map<String, int> toJson() => {
    'top': top,
    'bottom': bottom,
    'start': start,
    'end': end,
  };
}

/// Collects the callbacks of one view tree and assigns each a stable id, so
/// native tap, click and playback events can be dispatched back.
///
/// One table is built per `sendDisplayView` call; each send replaces the
/// view and every handler on the glasses.
class DisplayCallbackTable {
  final Map<String, void Function()> _voidCallbacks =
      <String, void Function()>{};
  final Map<String, void Function(DisplayPlaybackEvent)> _playbackCallbacks =
      <String, void Function(DisplayPlaybackEvent)>{};
  int _next = 0;

  /// Registers a tap or click [callback] and returns its id, or `null` when
  /// [callback] is `null`.
  String? registerTap(void Function()? callback) {
    if (callback == null) return null;
    final id = 'cb${_next++}';
    _voidCallbacks[id] = callback;
    return id;
  }

  /// Registers a playback [callback] and returns its id, or `null` when
  /// [callback] is `null`.
  String? registerPlayback(void Function(DisplayPlaybackEvent)? callback) {
    if (callback == null) return null;
    final id = 'cb${_next++}';
    _playbackCallbacks[id] = callback;
    return id;
  }

  /// Whether no callbacks were registered.
  bool get isEmpty => _voidCallbacks.isEmpty && _playbackCallbacks.isEmpty;

  /// Number of registered callbacks.
  int get length => _voidCallbacks.length + _playbackCallbacks.length;

  /// Dispatches a `display_events` [event] to the matching callback.
  void dispatch(Map<Object?, Object?> event) {
    final id = event['callbackId'] as String?;
    if (id == null) return;
    final playback = _playbackCallbacks[id];
    if (playback != null) {
      playback(DisplayPlaybackEvent.fromMap(event));
      return;
    }
    _voidCallbacks[id]?.call();
  }
}

/// A problem found by [DisplayNode.validate].
class DisplayValidationIssue {
  /// Creates a [DisplayValidationIssue].
  const DisplayValidationIssue(this.message, {this.isFatal = false});

  /// What is wrong.
  final String message;

  /// Whether the view cannot be sent.
  final bool isFatal;

  @override
  String toString() => '${isFatal ? 'error' : 'warning'}: $message';
}

/// Base class of every node in a view tree sent to Meta Ray-Ban Display
/// glasses with `MetaWearablesDat.sendDisplayView`.
///
/// The display is 600 x 600, scrolls vertically only, and every send
/// replaces the whole view. The root is a [FlexBox] or a [VideoPlayer].
///
/// ```dart
/// FlexBox(
///   spacing: 12,
///   children: [
///     DisplayText('Hello', style: DisplayTextStyle.heading),
///     DisplayButtonGroup(buttons: [
///       DisplayButton(label: 'OK', actionRole: DisplayActionRole.primary, onClick: () {}),
///     ]),
///   ],
/// )
/// ```
sealed class DisplayNode {
  const DisplayNode({this.flexGrow, this.flexShrink, this.alignSelf});

  /// Flex-grow factor relative to siblings.
  final double? flexGrow;

  /// Flex-shrink factor relative to siblings.
  final double? flexShrink;

  /// Cross-axis alignment overriding the parent's.
  final DisplayAlignment? alignSelf;

  /// Serializes this node and its subtree. When [callbacks] is given, the
  /// handlers are registered into it and their ids embedded.
  Map<String, Object?> toJson([DisplayCallbackTable? callbacks]);

  /// Checks this tree against the Display SDK's rules.
  List<DisplayValidationIssue> validate() {
    final issues = <DisplayValidationIssue>[];
    if (this is! FlexBox && this is! VideoPlayer) {
      issues.add(
        const DisplayValidationIssue(
          'The root is not a FlexBox; it will be wrapped in a column.',
        ),
      );
    }
    _validate(issues, isRoot: true);
    return issues;
  }

  void _validate(List<DisplayValidationIssue> issues, {required bool isRoot}) {}

  Map<String, Object?> _flexJson() => {
    if (flexGrow != null) 'flexGrow': flexGrow,
    if (flexShrink != null) 'flexShrink': flexShrink,
    if (alignSelf != null) 'alignSelf': alignSelf!.wireName,
  };
}

/// The root of a view tree.
typedef DisplayView = DisplayNode;

/// A flexbox container that lays its [children] out along [direction].
class FlexBox extends DisplayNode {
  /// Creates a [FlexBox].
  const FlexBox({
    this.children = const <DisplayNode>[],
    this.direction = DisplayDirection.column,
    this.spacing = 0,
    this.padding,
    this.paddingInsets,
    this.background,
    this.alignment,
    this.crossAlignment,
    @Deprecated('Not supported by the DAT Display SDK; ignored')
    this.cornerRadius,
    this.wrap,
    this.onTap,
    super.flexGrow,
    super.flexShrink,
    super.alignSelf,
  });

  /// Child nodes.
  final List<DisplayNode> children;

  /// Layout axis.
  final DisplayDirection direction;

  /// Gap between children, in logical pixels.
  final int spacing;

  /// Equal padding on every edge. Ignored when [paddingInsets] is set.
  final int? padding;

  /// Per-edge padding.
  final DisplayEdgeInsets? paddingInsets;

  /// Background preset.
  final FlexBoxBackground? background;

  /// Main-axis alignment.
  final DisplayAlignment? alignment;

  /// Cross-axis alignment.
  final DisplayAlignment? crossAlignment;

  /// Not supported by the DAT Display SDK; ignored.
  @Deprecated('Not supported by the DAT Display SDK; ignored')
  final DisplayCornerRadius? cornerRadius;

  /// Whether children wrap onto multiple lines.
  final bool? wrap;

  /// Tap handler for the whole container.
  final void Function()? onTap;

  @override
  Map<String, Object?> toJson([DisplayCallbackTable? callbacks]) => {
    'type': 'flexBox',
    'direction': direction.wireName,
    'spacing': spacing,
    if (padding != null) 'padding': padding,
    if (paddingInsets != null) 'paddingInsets': paddingInsets!.toJson(),
    if (background != null) 'background': background!.wireName,
    if (alignment != null) 'alignment': alignment!.wireName,
    if (crossAlignment != null) 'crossAlignment': crossAlignment!.wireName,
    // ignore: deprecated_member_use_from_same_package
    if (cornerRadius != null) 'cornerRadius': cornerRadius!.wireName,
    if (wrap != null) 'wrap': wrap,
    if (callbacks?.registerTap(onTap) case final String id) 'onTapId': id,
    ..._flexJson(),
    'children': children
        .map((child) => child.toJson(callbacks))
        .toList(growable: false),
  };

  @override
  void _validate(List<DisplayValidationIssue> issues, {required bool isRoot}) {
    for (final child in children) {
      if (child is VideoPlayer) {
        issues.add(
          const DisplayValidationIssue(
            'VideoPlayer must be the root view; it cannot be nested.',
            isFatal: true,
          ),
        );
      }
      child._validate(issues, isRoot: false);
    }
  }
}

/// Text.
class DisplayText extends DisplayNode {
  /// Creates a [DisplayText].
  const DisplayText(
    this.text, {
    this.style,
    this.color,
    super.flexGrow,
    super.flexShrink,
    super.alignSelf,
  });

  /// The text.
  final String text;

  /// Typographic style.
  final DisplayTextStyle? style;

  /// Color role.
  final DisplayTextColor? color;

  @override
  Map<String, Object?> toJson([DisplayCallbackTable? callbacks]) => {
    'type': 'text',
    'text': text,
    if (style != null) 'style': style!.wireName,
    if (color != null) 'color': color!.wireName,
    ..._flexJson(),
  };
}

/// An image from a URL (https or `data:`) or from encoded bytes.
class DisplayImage extends DisplayNode {
  /// Creates an image loaded from [uri].
  const DisplayImage(
    String this.uri, {
    this.sizePreset,
    this.cornerRadius,
    super.flexGrow,
    super.flexShrink,
    super.alignSelf,
  }) : bytes = null;

  /// Creates an image from encoded PNG or JPEG [bytes]. The SDK downscales
  /// it to the display bounds.
  const DisplayImage.bytes(
    Uint8List this.bytes, {
    this.sizePreset,
    this.cornerRadius,
    super.flexGrow,
    super.flexShrink,
    super.alignSelf,
  }) : uri = null;

  /// Image URL.
  final String? uri;

  /// Encoded image bytes.
  final Uint8List? bytes;

  /// Sizing preset.
  final DisplayImageSize? sizePreset;

  /// Corner-radius preset.
  final DisplayCornerRadius? cornerRadius;

  @override
  Map<String, Object?> toJson([DisplayCallbackTable? callbacks]) => {
    'type': 'image',
    if (uri != null) 'uri': uri,
    if (bytes != null) 'bytes': bytes,
    if (sizePreset != null) 'sizePreset': sizePreset!.wireName,
    if (cornerRadius != null) 'cornerRadius': cornerRadius!.wireName,
    ..._flexJson(),
  };
}

/// A button. Group buttons with [DisplayButtonGroup] for the platform's
/// focus and collapse behaviour.
class DisplayButton extends DisplayNode {
  /// Creates a [DisplayButton].
  const DisplayButton({
    required this.label,
    this.style,
    this.iconName,
    this.actionRole,
    this.onClick,
    super.flexGrow,
    super.flexShrink,
    super.alignSelf,
  });

  /// Label.
  final String label;

  /// Visual style.
  final DisplayButtonStyle? style;

  /// Leading icon.
  final DisplayIconName? iconName;

  /// Role; the first [DisplayActionRole.primary] button gets initial focus.
  final DisplayActionRole? actionRole;

  /// Click handler.
  final void Function()? onClick;

  @override
  Map<String, Object?> toJson([DisplayCallbackTable? callbacks]) => {
    'type': 'button',
    'label': label,
    if (style != null) 'style': style!.wireName,
    if (iconName != null) 'iconName': iconName!.wireName,
    if (actionRole != null) 'actionRole': actionRole!.wireName,
    if (callbacks?.registerTap(onClick) case final String id) 'onClickId': id,
    ..._flexJson(),
  };
}

/// A row of buttons. Unfocused icon buttons collapse to their icon; the
/// focused one shows its label.
class DisplayButtonGroup extends DisplayNode {
  /// Creates a [DisplayButtonGroup].
  const DisplayButtonGroup({
    required this.buttons,
    this.alignment = DisplayButtonGroupAlignment.center,
    super.flexGrow,
    super.flexShrink,
    super.alignSelf,
  });

  /// The buttons.
  final List<DisplayButton> buttons;

  /// Alignment of the buttons.
  final DisplayButtonGroupAlignment alignment;

  @override
  Map<String, Object?> toJson([DisplayCallbackTable? callbacks]) => {
    'type': 'buttonGroup',
    'alignment': alignment.wireName,
    'buttons': buttons.map((b) => b.toJson(callbacks)).toList(growable: false),
    ..._flexJson(),
  };

  @override
  void _validate(List<DisplayValidationIssue> issues, {required bool isRoot}) {
    if (buttons.isEmpty) {
      issues.add(
        const DisplayValidationIssue('DisplayButtonGroup has no buttons.'),
      );
    }
  }
}

/// A built-in icon.
class DisplayIcon extends DisplayNode {
  /// Creates a [DisplayIcon].
  const DisplayIcon(
    this.name, {
    this.style,
    super.flexGrow,
    super.flexShrink,
    super.alignSelf,
  });

  /// The icon.
  final DisplayIconName name;

  /// Filled (default) or outline.
  final DisplayIconStyle? style;

  @override
  Map<String, Object?> toJson([DisplayCallbackTable? callbacks]) => {
    'type': 'icon',
    'iconName': name.wireName,
    if (style != null) 'style': style!.wireName,
    ..._flexJson(),
  };
}

/// A video player. Must be the root view.
///
/// The Display SDK plays MP4 over https, at most 400 pixels per side and
/// 70,000 pixels in total.
class VideoPlayer extends DisplayNode {
  /// Creates a [VideoPlayer].
  const VideoPlayer(
    this.uri, {
    this.codec = DisplayVideoCodec.mp4,
    this.onPlaybackEvent,
  });

  /// Video URL.
  final String uri;

  /// Container format.
  final DisplayVideoCodec codec;

  /// Playback event handler.
  final void Function(DisplayPlaybackEvent)? onPlaybackEvent;

  @override
  Map<String, Object?> toJson([DisplayCallbackTable? callbacks]) => {
    'type': 'videoPlayer',
    'uri': uri,
    'codec': codec.wireName,
    if (callbacks?.registerPlayback(onPlaybackEvent) case final String id)
      'onPlaybackEventId': id,
  };

  @override
  void _validate(List<DisplayValidationIssue> issues, {required bool isRoot}) {
    if (!uri.startsWith('https://')) {
      issues.add(
        const DisplayValidationIssue('VideoPlayer URLs should use https.'),
      );
    }
  }
}
