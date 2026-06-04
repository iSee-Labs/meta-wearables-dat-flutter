import 'package:meta_wearables_dat_flutter/meta_wearables_dat_flutter.dart';

/// A single car-maintenance tutorial, mirroring Meta's official sample data.
class CarMaintenanceTutorial {
  const CarMaintenanceTutorial({
    required this.title,
    required this.duration,
    required this.steps,
    this.imageUri,
    this.iconImageUri,
  });

  final String title;
  final String duration;
  final String? imageUri;
  final String? iconImageUri;
  final List<String> steps;
}

/// The remote MP4 played by the "Watch video" button. Hosted by Meta in the
/// official sample's `assets` branch.
const tutorialVideoUrl =
    'https://github.com/facebook/meta-wearables-dat-android/raw/refs/heads/assets/video_266x150_faststart.mp4';

/// The five tutorials shown in the list, copied verbatim from Meta's sample.
const carMaintenanceTutorials = <CarMaintenanceTutorial>[
  CarMaintenanceTutorial(
    title: 'Oil change',
    duration: 'Easy • 45 min',
    imageUri: 'https://www.facebook.com/assets/wearables_dat_display/oil.png',
    iconImageUri:
        'https://www.facebook.com/assets/wearables_dat_display/oil_square.png',
    steps: [
      'Park on level ground and let the engine cool before opening the hood.',
      'Drain the old oil, replace the filter, and tighten the drain plug.',
      'Refill with fresh oil, run the engine briefly, and recheck the level.',
    ],
  ),
  CarMaintenanceTutorial(
    title: 'Fix a flat tire',
    duration: 'Easy • 15 min',
    imageUri: 'https://www.facebook.com/assets/wearables_dat_display/tire.png',
    iconImageUri:
        'https://www.facebook.com/assets/wearables_dat_display/tire_square.png',
    steps: [
      'Park away from traffic, engage the brake, and place the wheel wedges.',
      'Loosen the lug nuts slightly, raise the car, and remove the flat tire.',
      'Mount the spare, tighten in a star pattern, and lower the vehicle.',
    ],
  ),
  CarMaintenanceTutorial(
    title: 'Replace headlight bulb',
    duration: 'Very easy • 5 min',
    imageUri: 'https://www.facebook.com/assets/wearables_dat_display/light.png',
    iconImageUri:
        'https://www.facebook.com/assets/wearables_dat_display/light_square.png',
    steps: [
      'Open the rear access cover and disconnect the bulb connector.',
      'Release the retaining clip, remove the old bulb, and insert the new one.',
      'Reconnect power, close the cover, and verify the beam works properly.',
    ],
  ),
  CarMaintenanceTutorial(
    title: 'Check engine light',
    duration: 'Hard • 2 hours',
    imageUri: 'https://www.facebook.com/assets/wearables_dat_display/engine.png',
    iconImageUri:
        'https://www.facebook.com/assets/wearables_dat_display/engine_square.png',
    steps: [
      'Check whether the light is steady or flashing, and stop driving if it is flashing.',
      'Tighten the gas cap fully and look for obvious issues like low fluids or overheating.',
      'Scan for diagnostic codes or schedule service if the light stays on after restarting.',
    ],
  ),
  CarMaintenanceTutorial(
    title: 'Change washer fluid',
    duration: 'Very easy • 3 min',
    imageUri:
        'https://www.facebook.com/assets/wearables_dat_display/washer.png',
    iconImageUri:
        'https://www.facebook.com/assets/wearables_dat_display/washer_square.png',
    steps: [
      'Open the hood and locate the washer fluid reservoir cap with the windshield symbol.',
      'Pour washer fluid into the reservoir carefully until it reaches the fill line.',
      'Close the cap securely and test the sprayers to confirm proper flow.',
    ],
  ),
];

/// Builds the tutorial list screen. Tapping a card invokes [onSelect].
DisplayView buildTutorialListView(
  void Function(CarMaintenanceTutorial tutorial) onSelect,
) {
  return FlexBox(
    spacing: 10,
    children: [
      for (final tutorial in carMaintenanceTutorials)
        FlexBox(
          padding: 24,
          background: FlexBoxBackground.card,
          onTap: () => onSelect(tutorial),
          children: [
            FlexBox(
              direction: DisplayDirection.row,
              spacing: 12,
              crossAlignment: DisplayAlignment.center,
              children: [
                if (tutorial.iconImageUri != null)
                  FlexBox(
                    flexGrow: 1,
                    children: [
                      DisplayImage(
                        tutorial.iconImageUri!,
                        sizePreset: DisplayImageSize.fill,
                        cornerRadius: DisplayCornerRadius.medium,
                      ),
                    ],
                  ),
                FlexBox(
                  flexGrow: 7,
                  children: [
                    DisplayText(tutorial.title, style: DisplayTextStyle.body),
                    DisplayText(
                      tutorial.duration,
                      style: DisplayTextStyle.meta,
                      color: DisplayTextColor.secondary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
    ],
  );
}

/// Builds the tutorial detail screen with Back / Start buttons.
DisplayView buildTutorialDetailView(
  CarMaintenanceTutorial tutorial, {
  required void Function() onBack,
  required void Function() onStart,
}) {
  return FlexBox(
    spacing: 12,
    children: [
      FlexBox(
        padding: 24,
        background: FlexBoxBackground.card,
        children: [
          if (tutorial.imageUri != null)
            DisplayImage(
              tutorial.imageUri!,
              sizePreset: DisplayImageSize.fill,
              cornerRadius: DisplayCornerRadius.medium,
            ),
          DisplayText(tutorial.title, style: DisplayTextStyle.heading),
          DisplayText(
            tutorial.duration,
            style: DisplayTextStyle.meta,
            color: DisplayTextColor.secondary,
          ),
        ],
      ),
      FlexBox(
        direction: DisplayDirection.row,
        spacing: 8,
        alignment: DisplayAlignment.center,
        crossAlignment: DisplayAlignment.center,
        wrap: true,
        children: [
          DisplayButton(label: 'Back', onClick: onBack),
          DisplayButton(label: 'Start', onClick: onStart),
        ],
      ),
    ],
  );
}

/// Builds the per-step screen with Previous / Next-or-Done / Watch buttons.
DisplayView buildTutorialStepView(
  CarMaintenanceTutorial tutorial,
  int stepIndex, {
  required void Function() onPrevious,
  required void Function() onNext,
  required void Function() onWatchVideo,
}) {
  final clamped = stepIndex.clamp(0, tutorial.steps.length - 1);
  final isLast = clamped == tutorial.steps.length - 1;
  return FlexBox(
    spacing: 12,
    children: [
      FlexBox(
        padding: 24,
        background: FlexBoxBackground.card,
        children: [
          DisplayText(
            'Step ${clamped + 1}',
            style: DisplayTextStyle.meta,
            color: DisplayTextColor.secondary,
          ),
          DisplayText(tutorial.steps[clamped], style: DisplayTextStyle.body),
        ],
      ),
      FlexBox(
        direction: DisplayDirection.row,
        spacing: 8,
        alignment: DisplayAlignment.center,
        crossAlignment: DisplayAlignment.center,
        children: [
          DisplayButton(
            label: 'Previous',
            iconName: DisplayIconName.triangleLeftVerticalLine,
            onClick: onPrevious,
          ),
          DisplayButton(
            label: isLast ? 'Done' : 'Next',
            iconName: isLast
                ? DisplayIconName.checkmark
                : DisplayIconName.triangleRightVerticalLine,
            onClick: onNext,
          ),
          DisplayButton(
            label: 'Watch video',
            style: DisplayButtonStyle.secondary,
            iconName: DisplayIconName.videoCamera,
            onClick: onWatchVideo,
          ),
        ],
      ),
    ],
  );
}

/// Builds the video player screen. [onEnded] fires when playback completes.
DisplayView buildTutorialVideoView({required void Function() onEnded}) {
  return VideoPlayer(
    tutorialVideoUrl,
    onPlaybackEvent: (event) {
      if (event.type == DisplayPlaybackEventType.ended) onEnded();
    },
  );
}
