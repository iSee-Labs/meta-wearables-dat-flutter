// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

void main() {
  group('toJson', () {
    test('FlexBox serialises layout, padding insets and flex properties', () {
      final json = const FlexBox(
        direction: DisplayDirection.rowReverse,
        spacing: 8,
        paddingInsets: DisplayEdgeInsets.symmetric(horizontal: 4, vertical: 2),
        background: FlexBoxBackground.card,
        alignment: DisplayAlignment.stretch,
        crossAlignment: DisplayAlignment.center,
        wrap: true,
        flexGrow: 1,
        flexShrink: 0,
        alignSelf: DisplayAlignment.end,
      ).toJson();
      expect(json, {
        'type': 'flexBox',
        'direction': 'rowReverse',
        'spacing': 8,
        'paddingInsets': {'top': 2, 'bottom': 2, 'start': 4, 'end': 4},
        'background': 'card',
        'alignment': 'stretch',
        'crossAlignment': 'center',
        'wrap': true,
        'flexGrow': 1.0,
        'flexShrink': 0.0,
        'alignSelf': 'end',
        'children': <Object?>[],
      });
    });

    test('leaf components serialise every property', () {
      expect(
        const DisplayText(
          'Hi',
          style: DisplayTextStyle.heading,
          color: DisplayTextColor.secondary,
        ).toJson(),
        {
          'type': 'text',
          'text': 'Hi',
          'style': 'heading',
          'color': 'secondary',
        },
      );
      expect(
        const DisplayImage(
          'https://x/i.png',
          sizePreset: DisplayImageSize.icon,
          cornerRadius: DisplayCornerRadius.small,
        ).toJson(),
        {
          'type': 'image',
          'uri': 'https://x/i.png',
          'sizePreset': 'icon',
          'cornerRadius': 'small',
        },
      );
      final bytes = Uint8List.fromList([1, 2, 3]);
      expect(DisplayImage.bytes(bytes).toJson(), {
        'type': 'image',
        'bytes': bytes,
      });
      expect(
        const DisplayIcon(
          DisplayIconName.circle8RaysLarge,
          style: DisplayIconStyle.outline,
        ).toJson(),
        {'type': 'icon', 'iconName': 'circle8RaysLarge', 'style': 'outline'},
      );
      expect(const VideoPlayer('https://x/v.mp4').toJson(), {
        'type': 'videoPlayer',
        'uri': 'https://x/v.mp4',
        'codec': 'mp4',
      });
    });

    test('ButtonGroup and action roles', () {
      final table = DisplayCallbackTable();
      final json = DisplayButtonGroup(
        alignment: DisplayButtonGroupAlignment.end,
        buttons: [
          DisplayButton(
            label: 'Next',
            style: DisplayButtonStyle.outline,
            iconName: DisplayIconName.triangleRightVerticalLine,
            actionRole: DisplayActionRole.primary,
            onClick: () {},
          ),
          const DisplayButton(label: 'Skip'),
        ],
      ).toJson(table);
      expect(json['type'], 'buttonGroup');
      expect(json['alignment'], 'end');
      final buttons = json['buttons']! as List<Object?>;
      expect(buttons.first, {
        'type': 'button',
        'label': 'Next',
        'style': 'outline',
        'iconName': 'triangleRightVerticalLine',
        'actionRole': 'primary',
        'onClickId': 'cb0',
      });
      expect(buttons.last, {'type': 'button', 'label': 'Skip'});
      expect(table.length, 1);
    });

    test('there are 116 icons and the old names still exist', () {
      expect(DisplayIconName.values, hasLength(116));
      expect(DisplayIconName.checkmark.wireName, 'checkmark');
      expect(DisplayIconName.videoCamera.wireName, 'videoCamera');
    });
  });

  group('callback table', () {
    test('dispatches taps, clicks and playback events by id', () {
      var taps = 0;
      DisplayPlaybackEvent? playback;
      final table = DisplayCallbackTable();
      FlexBox(
        onTap: () => taps++,
        children: [DisplayButton(label: 'b', onClick: () => taps += 10)],
      ).toJson(table);
      VideoPlayer(
        'https://x/v.mp4',
        onPlaybackEvent: (e) => playback = e,
      ).toJson(table);
      table
        ..dispatch({'callbackId': 'cb0', 'type': 'tap'})
        ..dispatch({'callbackId': 'cb1', 'type': 'click'})
        ..dispatch({'callbackId': 'cb2', 'type': 'playback', 'event': 'ended'})
        ..dispatch({'callbackId': 'missing'});
      expect(taps, 11);
      expect(playback?.type, DisplayPlaybackEventType.ended);
    });

    test('toJson without a table omits callback ids', () {
      final json = DisplayButton(label: 'b', onClick: () {}).toJson();
      expect(json.containsKey('onClickId'), isFalse);
    });
  });

  group('validate', () {
    test('a nested VideoPlayer is fatal', () {
      final issues = const FlexBox(
        children: [VideoPlayer('https://x/v.mp4')],
      ).validate();
      expect(issues.where((i) => i.isFatal), hasLength(1));
    });

    test('a non-FlexBox root and an empty button group are warnings', () {
      expect(const DisplayText('x').validate().single.isFatal, isFalse);
      final issues = const FlexBox(
        children: [DisplayButtonGroup(buttons: [])],
      ).validate();
      expect(issues.single.isFatal, isFalse);
    });

    test('a plain https video root is valid', () {
      expect(const VideoPlayer('https://x/v.mp4').validate(), isEmpty);
      expect(
        const VideoPlayer('http://x/v.mp4').validate().single.isFatal,
        isFalse,
      );
    });
  });
}
