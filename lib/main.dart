import 'dart:math';
import 'dart:ui';

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
  @override
  Widget build(BuildContext context) {
    return StoriesWidget(
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
    );
  }
}

class StoriesWidget extends StatefulWidget {
  const StoriesWidget({
    super.key,
    required this.contentBuilder,
    required this.frameLengthBuilder,
    required this.groupsCount,
  });

  final int groupsCount;
  final FrameLengthBuilder frameLengthBuilder;
  final StoryContentBuilder contentBuilder;

  @override
  State<StoriesWidget> createState() => _StoriesWidgetState();
}

class _StoriesWidgetState extends State<StoriesWidget> {
  late PageController _controller;
  final ValueNotifier<double> _currentPageValueNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _controller.addListener(_listenCurrentValue);
  }

  void _listenCurrentValue() {
    _currentPageValueNotifier.value = _controller.page ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.groupsCount,
          itemBuilder: (context, index) {
            return ValueListenableBuilder(
              valueListenable: _currentPageValueNotifier,
              builder: (context, currentPageValue, _) {
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
                    controller: _controller,
                    builder: widget.contentBuilder,
                    groupIndex: index,
                    framesLength: widget.frameLengthBuilder(index),
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
    _controller.removeListener(_listenCurrentValue);
    _controller.dispose();
    _currentPageValueNotifier.dispose();
    super.dispose();
  }
}

typedef FrameLengthBuilder = int Function(int groupIndex);

typedef StoryContentBuilder = Widget Function(
  BuildContext context,
  int groupIndex,
  int frameIndex,
);

class StoryFrame extends StatefulWidget {
  const StoryFrame({
    super.key,
    required this.controller,
    required this.builder,
    required this.groupIndex,
    required this.framesLength,
  });

  final int framesLength;
  final int groupIndex;
  final StoryContentBuilder builder;
  final PageController controller;

  @override
  State<StoryFrame> createState() => _StoryFrameState();
}

class _StoryFrameState extends State<StoryFrame>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _activeIndexNotifier = ValueNotifier(0);

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(
        seconds: 10,
      ),
    )
      ..addStatusListener(_listenAnimationStatus)
      ..forward();

    _activeIndexNotifier.addListener(_listenFrameUpdate);
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

  void _onResume() {
    _animationController.forward();
  }

  void _previousFrame() {
    if (_activeIndexNotifier.value > 0) {
      _activeIndexNotifier.value--;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: ValueListenableBuilder(
            valueListenable: _activeIndexNotifier,
            builder: (context, value, _) {
              return widget.builder(
                context,
                widget.groupIndex,
                value,
              );
            },
          ),
        ),
        Positioned.fill(
          top: 30,
          child: Align(
            alignment: Alignment.topCenter,
            child: ValueListenableBuilder(
              valueListenable: _activeIndexNotifier,
              builder: (context, value, _) {
                return StoryIndicators(
                  framesLength: widget.framesLength,
                  activeIndex: value,
                  frameProgress: _animationController.view,
                );
              },
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
      ],
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
