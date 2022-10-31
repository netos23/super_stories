import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestApp(),
    );
  }
}

class TestApp extends StatefulWidget {
  const TestApp({Key? key}) : super(key: key);

  @override
  State<TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<TestApp> {
  final controller = StoriesController();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StoriesWidget(
      onStateSave: (group, frame) {
        // debugPrint('save $group $frame');
      },
      onStateRestore: (group) {
        // debugPrint('restore $group');
        return 0;
      },
      contentBuilder: (
        context,
        groupIndex,
        frameIndex,
      ) {
        return Container(
          color: groupIndex.isOdd ? Colors.green : Colors.indigo,
          child: Center(
            child: Text(
              frameIndex.toString(),
              style: Theme.of(context).textTheme.headline1?.copyWith(
                    color: Colors.white,
                  ),
            ),
          ),
        );
      },
      frameLengthBuilder: (_) => 10,
      groupsCount: 12,
      controller: controller,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

enum StoriesStatus {
  play,
  pause,
}

class StoriesController extends ChangeNotifier
    implements ValueListenable<StoriesStatus> {
  static const double _kPageScrollLimit = 0.0001;

  final ValueNotifier<StoriesStatus> storyStatusNotifier = ValueNotifier(
    StoriesStatus.play,
  );

  final pageController = PageController();
  final Duration nextGroupDuration;
  final Duration previousGroupDuration;
  int _groupIndex = 0;

  StoriesController({
    this.nextGroupDuration = const Duration(
      milliseconds: 300,
    ),
    this.previousGroupDuration = const Duration(
      milliseconds: 300,
    ),
  }) {
    pageController.addListener(_listenGroupScroll);
    storyStatusNotifier.addListener(_listenStatus);
  }

  int get groupIndex => _groupIndex;

  void _listenStatus() {
    notifyListeners();
  }

  void _listenGroupScroll() {
    final page = pageController.page ?? 0;
    final activeIndex = page.floor();
    final progress = (page - activeIndex).abs();

    if (progress < _kPageScrollLimit) {
      play();
    } else {
      pause();
    }
    _groupIndex = page.round();
  }

  void pause() {
    storyStatusNotifier.value = StoriesStatus.pause;
  }

  void play() {
    storyStatusNotifier.value = StoriesStatus.play;
  }

  void nextFrame() {
    throw UnimplementedError();
  }

  void previousFrame() {
    throw UnimplementedError();
  }

  void nextGroup() {
    pageController.nextPage(
      duration: nextGroupDuration,
      curve: Curves.easeIn,
    );
  }

  void previousGroup() {
    pageController.previousPage(
      duration: nextGroupDuration,
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    storyStatusNotifier.removeListener(_listenStatus);
    pageController.removeListener(_listenGroupScroll);

    storyStatusNotifier.dispose();
    pageController.dispose();

    super.dispose();
  }

  @override
  StoriesStatus get value => storyStatusNotifier.value;
}

class StoriesWidget extends StatefulWidget {
  const StoriesWidget({
    super.key,
    required this.contentBuilder,
    required this.frameLengthBuilder,
    required this.groupsCount,
    this.onStateSave,
    this.onStateRestore,
    this.foregroundContentBuilder = _defaultContentBuilder,
    required this.controller,
  });

  final int groupsCount;
  final FrameLengthBuilder frameLengthBuilder;
  final StoryContentBuilder contentBuilder;
  final StoryContentBuilder foregroundContentBuilder;
  final StoryStateSaveCallback? onStateSave;
  final StoryStateRestoreCallback? onStateRestore;
  final StoriesController controller;

  @override
  State<StoriesWidget> createState() => _StoriesWidgetState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(DiagnosticsProperty('groupIndex', controller.groupIndex));
    super.debugFillProperties(properties);
  }
}

class _StoriesWidgetState extends State<StoriesWidget> {
  final ValueNotifier<double> _currentPageValueNotifier = ValueNotifier(0);

  PageController get _pageController => widget.controller.pageController;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_listenCurrentValue);
  }

  void _listenCurrentValue() {
    _currentPageValueNotifier.value = _pageController.page ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: PageView.builder(
          controller: _pageController,
          itemCount: widget.groupsCount,
          itemBuilder: (context, index) {
            return ValueListenableBuilder(
              valueListenable: _currentPageValueNotifier,
              builder: (context, currentPageValue, _) {
                debugPrint(currentPageValue.toString());
                final isLeaving = (index - currentPageValue) <= 0;
                final t = (index - currentPageValue);
                final rotationY = lerpDouble(0, 30, t);
                final transform = Matrix4.identity();

                transform.setEntry(3, 2, 0.003);
                transform.rotateY(-rotationY! * (pi / 180.0));

                return Transform(
                  alignment:
                      isLeaving ? Alignment.centerRight : Alignment.centerLeft,
                  transform: transform,
                  child: StoryFrame(
                    controller: widget.controller,
                    builder: widget.contentBuilder,
                    foregroundBuilder: widget.foregroundContentBuilder,
                    groupIndex: index,
                    framesLength: widget.frameLengthBuilder(index),
                    initialIndex: widget.onStateRestore?.call(index) ?? 0,
                    onStateSave: widget.onStateSave,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_listenCurrentValue);
    _currentPageValueNotifier.dispose();
    super.dispose();
  }
}

typedef StoryStateSaveCallback = void Function(
  int groupIndex,
  int frameIndex,
);

typedef StoryStateRestoreCallback = int? Function(int groupIndex);

typedef FrameLengthBuilder = int Function(int groupIndex);

typedef StoryContentBuilder = Widget Function(
  BuildContext context,
  int groupIndex,
  int frameIndex,
);

Widget _defaultContentBuilder(
  BuildContext context,
  int groupIndex,
  int frameIndex,
) =>
    const SizedBox.shrink();

class StoryFrame extends StatefulWidget {
  const StoryFrame({
    super.key,
    required this.controller,
    required this.builder,
    required this.groupIndex,
    required this.framesLength,
    required this.initialIndex,
    required this.foregroundBuilder,
    this.onStateSave,
  });

  final int framesLength;
  final int groupIndex;
  final int initialIndex;
  final StoryContentBuilder builder;
  final StoryContentBuilder foregroundBuilder;
  final StoriesController controller;

  final StoryStateSaveCallback? onStateSave;

  @override
  State<StoryFrame> createState() => _StoryFrameState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties.add(DiagnosticsProperty('framesLength', framesLength));
    properties.add(DiagnosticsProperty('initialIndex', initialIndex));
    properties.add(DiagnosticsProperty('groupIndex', groupIndex));
  }
}

class _StoryFrameState extends State<StoryFrame>
    with SingleTickerProviderStateMixin {
  late final ValueNotifier<int> _activeIndexNotifier;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _activeIndexNotifier = ValueNotifier(widget.initialIndex);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 3,
      ),
    )..addStatusListener(_listenAnimationStatus);

    _activeIndexNotifier.addListener(_listenFrameUpdate);
    widget.controller.addListener(_listenStoryState);

    _resumeIfActive();
  }

  void _listenStoryState() {
    switch (widget.controller.value) {
      case StoriesStatus.play:
        _resumeIfActive();
        break;
      case StoriesStatus.pause:
        _onPause();
        break;
    }
  }

  void _resumeIfActive() {
    if (widget.controller.groupIndex == widget.groupIndex) {
      _onResume(0);
    }
  }

  void _listenFrameUpdate() {
    _animationController.forward(from: 0);
  }

  void _listenAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _nextFrame();
    }
  }

  @override
  void dispose() {
    _activeIndexNotifier.removeListener(_listenFrameUpdate);
    _animationController.removeStatusListener(_listenAnimationStatus);
    widget.controller.removeListener(_listenStoryState);

    _animationController.dispose();
    _activeIndexNotifier.dispose();
    super.dispose();
  }

  void _nextFrame() {
    if (_activeIndexNotifier.value < widget.framesLength - 1) {
      _activeIndexNotifier.value++;
    }
  }

  void _onPause() {
    _animationController.stop();
  }

  void _onResume([double? start]) {
    _animationController.forward(from: start);
  }

  void _previousFrame() {
    if (_activeIndexNotifier.value > 0) {
      _activeIndexNotifier.value--;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _activeIndexNotifier,
      builder: (context, frameIndex, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: widget.builder(
                context,
                widget.groupIndex,
                frameIndex,
              ),
            ),
            Positioned.fill(
              top: 30,
              child: Align(
                alignment: Alignment.topCenter,
                child: StoryIndicators(
                  framesLength: widget.framesLength,
                  activeIndex: frameIndex,
                  frameProgress: _animationController.view,
                ),
              ),
            ),
            Positioned.fill(
              child: StoryGestures(
                onNextFrame: _nextFrame,
                onPause: _onPause,
                onResume: _onResume,
                onPreviousFrame: _previousFrame,
              ),
            ),
            Positioned.fill(
              child: widget.foregroundBuilder(
                context,
                widget.groupIndex,
                frameIndex,
              ),
            ),
          ],
        );
      },
    );
  }
}

class StoryGestures extends StatelessWidget {
  const StoryGestures({
    Key? key,
    this.onNextFrame,
    this.onPreviousFrame,
    this.onPause,
    this.onResume,
  }) : super(key: key);

  final VoidCallback? onNextFrame;
  final VoidCallback? onPreviousFrame;
  final VoidCallback? onPause;
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onPause,
      onLongPressUp: onResume,
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: ChangeStoryGesture(
                onPressed: onPreviousFrame,
              ),
            ),
            Expanded(
              child: ChangeStoryGesture(
                onPressed: onNextFrame,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChangeStoryGesture extends StatelessWidget {
  const ChangeStoryGesture({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashFactory: NoSplash.splashFactory,
      overlayColor: const MaterialStatePropertyAll(
        Colors.transparent,
      ),
      splashColor: Colors.transparent,
      // onLongPress: onPause,
      onTap: onPressed,
    );
  }
}

class StoryIndicators extends StatelessWidget {
  const StoryIndicators({
    Key? key,
    required this.framesLength,
    required this.activeIndex,
    required this.frameProgress,
  })  : assert(
          activeIndex < framesLength,
          'Active index must be lover then frames length,',
        ),
        super(key: key);

  final Animation<double> frameProgress;
  final int activeIndex;
  final int framesLength;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 3,
      child: Row(
        children: List.generate(
          framesLength,
          (index) => Expanded(
              child: _isActive(index)
                  ? AnimatedStoryIndicator(
                      frameProgress: frameProgress,
                    )
                  : StoryIndicator(
                      value: _valueFromIndex(index),
                    )),
        ),
      ),
    );
  }

  bool _isActive(int index) {
    return activeIndex == index;
  }

  double _valueFromIndex(int index) {
    if (index < activeIndex) {
      return 1;
    }

    if (index > activeIndex) {
      return 0;
    }

    return frameProgress.value;
  }
}

class AnimatedStoryIndicator extends StatelessWidget {
  const AnimatedStoryIndicator({
    Key? key,
    required this.frameProgress,
  }) : super(key: key);

  final Animation<double> frameProgress;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: frameProgress,
      builder: (context, value, _) {
        return StoryIndicator(value: value);
      },
    );
  }
}

class StoryIndicator extends StatelessWidget {
  const StoryIndicator({
    Key? key,
    required this.value,
  }) : super(key: key);

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
      ),
      clipBehavior: Clip.hardEdge,
      height: 3,
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: Colors.white.withOpacity(0.7),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight: 2,
      ),
    );
  }
}
