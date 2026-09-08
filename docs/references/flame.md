<!-- Retrieved 2026-09-08 | flame 1.38.2 -->

## Sources
- https://pub.dev/packages/flame
- https://pub.dev/api/packages/flame (version + publish metadata)
- https://docs.flame-engine.org/latest/
- https://docs.flame-engine.org/latest/flame/game.html
- https://docs.flame-engine.org/latest/flame/components/components.html
- https://docs.flame-engine.org/latest/flame/camera.html
- https://docs.flame-engine.org/latest/flame/inputs/tap_events.html
- https://docs.flame-engine.org/latest/flame/inputs/drag_events.html
- https://github.com/flame-engine/flame (tree + raw sources at tag `v1.38.2`)
- https://raw.githubusercontent.com/flame-engine/flame/main/packages/flame/CHANGELOG.md

All signatures below are copied from `flame-engine/flame` at tag **v1.38.2** unless marked otherwise.

## Version & constraints
- `flame: 1.38.2`, published **2026-08-27**. Prior: 1.38.1 (2026-08-26), 1.38.0 (2026-07-19), 1.37.0 (2026-04-10), 1.36.0 (2026-03-06), 1.35.1 (2026-02-12).
- pubspec: `sdk: '>=3.11.0 <4.0.0'`, `flutter: '>=3.41.0'`; deps `collection ^1.18.0`, `meta ^1.12.0`, `ordered_set ^8.0.0`, `vector_math ^2.1.4`.
- Companion test package: `flame_test` (same repo, `packages/flame_test`).

### Recent changes (CHANGELOG 1.30–1.38)
- 1.38.0: `HoverCallbacks.onHoverCancel`; `TertiaryTapCallbacks`/`LongPressCallbacks`/`ScrollCallbacks` on the new event system; `OpacityEffect` works on text; drag updates no longer reach removed components.
- 1.37.0: `OverlayManager.setActive()`; `HueEffect`. 1.36.0: `FlameGame.dispose()`; `ComponentPool`; `IconComponent`; `HitTestBehavior` on `GameWidget`; `Anchor.opposite`; hitboxes respect parent scale/rotation.
- 1.34.0: `CombinedEffect`. 1.33.0: `Event.raw`; secondary tap. 1.31.0: `shrinkwrap` removed from `GameWidget`. 1.30.0: `angleTo`/`lookAt` respect parent transforms, normalise to `[-pi, pi]`; `testGolden` prepare fn gets `WidgetTester`.

## FlameGame lifecycle
```dart
class FlameGame<W extends World> extends ComponentTreeRoot with Game implements ReadOnlySizeProvider {
  FlameGame({super.children, W? world, CameraComponent? camera});
}
```
- Constructor adds `camera` then `world` as children of the game. `world` setter swaps worlds and re-points `camera.world`.
- Order per component: `onGameResize(size)` → `onLoad()` → `onMount()` → `update`/`render` loop → `onRemove()`. `onHotReload()` in debug only.
```dart
FutureOr<void> onLoad() => null;   // may be sync; return a Future to await assets
void onMount() {}                  // every time it enters the tree
void onRemove() {}                 void onGameResize(Vector2 size);  // resize also fires on add
void onParentResize(Vector2 maxSize) {}   void onChildrenChanged(Component, ChildrenChangeType) {}
void update(double dt) {}          void render(Canvas canvas) {}
```
- Awaitable state: `Future<void> get loaded / mounted / removed`; flags `isLoading/isLoaded/isMounted/isRemoving/isRemoved`.
- `FlameGame.onGameResize` is `@mustCallSuper`; it resizes `camera.viewport` *first* so `game.size` is correct inside children's `onGameResize`.
- `Vector2 get size => camera.viewport.virtualSize;` — **not** the widget size. Widget size is `canvasSize`.
- `pauseEngine()` / `resumeEngine()`; `dispose()` (1.36+) removes all children, drains pending events, clears caches.
- Override `Color backgroundColor()` to change the clear colour.
- Optional mixins: `SingleGameInstance` (makes `add` complete `onLoad` synchronously), `HasPerformanceTracker` (`updateTime`, `renderTime`).

## GameWidget & overlays
```dart
GameWidget({
  required T this.game, TextDirection? textDirection,
  GameLoadingWidgetBuilder? loadingBuilder,   // Widget Function(BuildContext)
  GameErrorWidgetBuilder? errorBuilder,       // Widget Function(BuildContext, Object)
  WidgetBuilder? backgroundBuilder,
  Map<String, OverlayWidgetBuilder<T>>? overlayBuilderMap,
  List<String>? initialActiveOverlays, FocusNode? focusNode, bool autofocus = true,
  MouseCursor? mouseCursor, bool addRepaintBoundary = true,
  HitTestBehavior behavior = HitTestBehavior.opaque, super.key,
});
const GameWidget.controlled({required GameFactory<T> this.gameFactory, /* same params */});
```
- `OverlayWidgetBuilder<T> = Widget Function(BuildContext, T game)`.
- `game.overlays` is an `OverlayManager`:
```dart
bool add(String overlayName, {int priority = 0});   void addAll(Iterable<String> overlayNames);
void addEntry(String name, OverlayBuilderFunction builder);   bool isActive(String overlayName);
bool remove(String overlayName);   void removeAll(Iterable<String> overlayNames);   void clear();
bool toggle(String overlayName, {int priority = 0});
bool setActive(String overlayName, {required bool active, int priority = 0}); // 1.37+
UnmodifiableListView<String> get activeOverlays;  // sorted by priority
UnmodifiableListView<String> get registeredOverlays;
```
- `add`/`remove` return whether the set changed and trigger `game.refreshWidget(...)` → `setState` on `GameWidgetState`. Adding an unregistered name trips an assert.
- `overlayBuilderMap`/`initialActiveOverlays` are applied in the `GameWidget` constructor via `addEntry`/`addAll`, i.e. only for the non-`.controlled` form at construction time.
- Overlay widgets are wrapped in `KeyedSubtree(key: ValueKey(overlayData))` and stacked over the game, ordered by ascending `priority`.

## Component tree
```dart
Component({Iterable<Component>? children, int? priority, ComponentKey? key});
FutureOr<void> add(Component component);   FutureOr<void> addToParent(Component parent);
Future<void> addAll(Iterable<Component> components);   void removeFromParent();
void remove(Component c); void removeAll(Iterable<Component>); void removeWhere(bool Function(Component));
Component? get parent;  set parent(Component? newParent);   // re-parents
ReadOnlyOrderedSet<Component> get children;
T? firstChild<T extends Component>();  T? lastChild<T extends Component>();
Iterable<Component> ancestors({bool includeSelf = false});
Iterable<Component> descendants({bool includeSelf = false, bool reversed = false});
bool propagateToChildren<T extends Component>(bool Function(T) handler, {bool includeSelf = false});
Iterable<Component> componentsAtPoint(Vector2 point, [List<Vector2>? nestedPoints]);
bool containsLocalPoint(Vector2 point) => false;   // Component default: never hit
```
- `children.query<T>()` filters by type (`ordered_set` API). `ComponentSet` no longer exists in 1.38 — the type is `ReadOnlyOrderedSet<Component>` / `OrderedSet<Component>` (`createComponentSet()`).
- `ComponentKey.named('x')` / `ComponentKey.unique()` + `game.findByKey(key)` for global lookup.
- `HasVisibility` mixin gives `isVisible` without removing from the tree.

```dart
// implements AnchorProvider, AngleProvider, PositionProvider, ScaleProvider,
//            SizeProvider, CoordinateTransform
PositionComponent({Vector2? position, Vector2? size, Vector2? scale, double? angle,
  double nativeAngle = 0, Anchor? anchor, super.children, super.priority, super.key});
```
- Defaults: `anchor = Anchor.topLeft`, `size = Vector2.zero()`. `position`/`size`/`scale` are `NotifyingVector2` — mutate in place (`position.setValues`, `..add()`); assigning `position = v` copies into the existing vector.

```dart
// SpriteComponent extends PositionComponent with HasPaint
SpriteComponent({Sprite? sprite, bool? autoResize, Paint? paint, super.position, Vector2? size,
  super.scale, super.angle, super.nativeAngle, super.anchor, super.children, super.priority,
  double? bleed, super.key});
SpriteComponent.fromImage(Image image, {Vector2? srcPosition, Vector2? srcSize, ...});
// RectangleComponent extends PolygonComponent
RectangleComponent({super.position, super.size, super.scale, super.angle, super.anchor,
  super.children, super.priority, super.paint, super.paintLayers, super.key});
RectangleComponent.square({double size = 0, ...});
RectangleComponent.relative(Vector2 relation, {required Vector2 parentSize, ...});
factory RectangleComponent.fromRect(Rect rect, {Anchor anchor = Anchor.topLeft, ...});
// CircleComponent extends ShapeComponent; size == Vector2.all(radius * 2)
CircleComponent({double? radius, super.position, super.scale, super.angle, super.anchor,
  super.children, super.priority, super.paint, super.paintLayers, super.key});
double get radius; set radius(double);  double get scaledRadius;
// TextComponent<T extends TextRenderer> extends PositionComponent with HasPaint
TextComponent({String? text, T? textRenderer, super.position, super.size, super.scale,
  super.angle, super.anchor, super.children, super.priority, super.key});
String get text; set text(String);   // setter re-measures and overwrites size
T get textRenderer; set textRenderer(T);
```
- `SpriteComponent.onMount` asserts `sprite != null`: set it in the constructor or in `onLoad`.
- `SpriteComponent.autoResize` defaults to `size == null`; manually writing `size` flips `autoResize` to false.
- `game.world.add(...)` for world-space entities; `game.add(...)` puts a component in game space (sibling of camera/world); `camera.viewport.add(...)` for HUD.

## Rendering: update / render
- Whole tree is `update`d, then the whole tree is `render`ed. `render(Canvas)` is already translated/rotated/scaled into the component's local space by its `Transform2DDecorator`, so draw at local `(0,0)`.
- Anything drawn in `render` before `super.render(canvas)`/children ends up under the children (children render after `render`, via `renderTree`).

### Rounded rects and paints inside render
```dart
@override
void render(Canvas canvas) {
  final rrect = RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12));
  canvas.drawRRect(rrect, _fill);   // Paint()..color = const Color(0xFF2B2D42)
  canvas.drawRRect(rrect, _stroke); // Paint()..style = PaintingStyle.stroke..strokeWidth = 2
}
```
- Cache `Paint` objects as fields; allocating per frame is the usual cause of jank in grid games.
- `RRect.fromRectAndCorners(rect, topLeft: ...)` for asymmetric corners; also `canvas.drawRect`, `canvas.drawCircle(Offset, r, paint)`, `canvas.clipRRect`.

## Camera, viewport, viewfinder
```dart
CameraComponent({World? world, Viewport? viewport, Viewfinder? viewfinder, Component? backdrop,
  List<Component>? hudComponents, Iterable<Component>? children, ComponentKey? key}); // priority 0x7fffffff
CameraComponent.withFixedResolution({required double width, required double height, World? world,
  Viewfinder? viewfinder, Component? backdrop, List<Component>? hudComponents,
  Iterable<Component>? children, ComponentKey? key});
```
- `withFixedResolution` is exactly `viewport: FixedResolutionViewport(resolution: Vector2(width, height))` (letterboxed, uniform `min(scaleX, scaleY)`).
- `class World extends Component` with `priority = -0x7fffffff`; `World.renderTree` is a no-op — the world is only drawn *through* a camera.
- Viewport = the on-screen window (`position`, `size`, `anchor = Anchor.topLeft`, `virtualSize`). Types: `MaxViewport` (default, fills), `FixedResolutionViewport`, `FixedSizeViewport`, `FixedAspectRatioViewport`, `CircularViewport`. Children of the viewport are static HUD.
- Viewfinder = where in the world the camera looks. It has no `size`.
```dart
Vector2 get position => -transform.offset;   set position(Vector2);
double get zoom;  set zoom(double);          // assert(value > 0)
double get angle; set angle(double);
Anchor get anchor; set anchor(Anchor);       // default Anchor.center
Vector2? get visibleGameSize; set visibleGameSize(Vector2?);  // computes zoom for you
Rect get visibleWorldRect;                   // cached, invalidated on transform change
Vector2 globalToLocal(Vector2, {Vector2? output});  Vector2 localToGlobal(Vector2, {Vector2? output});
```
```dart
void follow(ReadOnlyPositionProvider target, {double maxSpeed = double.infinity,
    bool horizontalOnly = false, bool verticalOnly = false, bool snap = false});
void stop();  // removes FollowBehavior + MoveEffects from the viewfinder
void moveTo(Vector2 point, {double speed = double.infinity});
void moveBy(Vector2 offset, {double speed = double.infinity});
void setBounds(Shape? bounds, {bool considerViewport = false});
bool canSee(PositionComponent component, {World? componentWorld});
Vector2 globalToLocal(Vector2 point, {Vector2? output});    // widget px -> world
Vector2 localToGlobal(Vector2 position, {Vector2? output}); // world -> widget px
Rect get visibleWorldRect;                                  // asserts camera is mounted
```
- Grid-game default: `CameraComponent.withFixedResolution(width: cols*cell, height: rows*cell)` + `camera.viewfinder.anchor = Anchor.topLeft` if you want world `(0,0)` at the top-left of the viewport.

## Input: tap & drag
```dart
mixin TapCallbacks on Component implements PointerInputCallbacks {
  void onTapDown(TapDownEvent event) {}
  void onLongTapDown(TapDownEvent event) {}   // after TapConfig.longTapDelay (default 0.3s, min 0.15)
  void onTapUp(TapUpEvent event) {}           void onTapCancel(TapCancelEvent event) {}
}
mixin DragCallbacks on Component implements PointerInputCallbacks {
  bool get isDragged;
  @mustCallSuper void onDragStart(DragStartEvent event);
  void onDragUpdate(DragUpdateEvent event) {}
  @mustCallSuper void onDragEnd(DragEndEvent event);
  @mustCallSuper void onDragCancel(DragCancelEvent event) => onDragEnd(event.toDragEnd());
}
mixin PointerMoveCallbacks on Component implements PointerInputCallbacks {
  void onPointerMove(PointerMoveEvent event) {}   void onPointerMoveStop(PointerMoveEvent event) {}
}
mixin HoverCallbacks on Component implements PointerMoveCallbacks {   // onHoverCancel: 1.38+
  bool get isHovered;  void onHoverEnter() {}  void onHoverExit() {}  void onHoverCancel() {}
}
```
Event shapes:
```dart
abstract class Event<R> { R raw; bool handled = false; bool continuePropagation = false; }
abstract class PositionEvent<R> extends LocationContextEvent<Vector2, R> {
  final Vector2 devicePosition;
  late final Vector2 canvasPosition;   // game.convertGlobalToLocalCoordinate(devicePosition)
  Vector2 get localPosition;           // renderingTrace.last
}
// TapDownEvent, TapUpEvent, DragStartEvent extend PositionEvent and add:
final int pointerId; final PointerDeviceKind deviceKind;

abstract class DisplacementEvent<R> extends LocationContextEvent<DisplacementContext, R> {
  final Vector2 deviceStartPosition, deviceEndPosition;
  late final Vector2 canvasStartPosition, canvasEndPosition;
  Vector2 get localStartPosition;  Vector2 get localEndPosition;
  late final Vector2 deviceDelta, canvasDelta;   Vector2 get localDelta;
}
class DragUpdateEvent extends DisplacementEvent<DragUpdateDetails> { final int pointerId; final Duration timestamp; }
class DragEndEvent extends Event<DragEndDetails> { final int pointerId; final Vector2 velocity; }
```
- Hit testing uses `containsLocalPoint(Vector2)`. `PositionComponent` implements it as `0 <= x < size.x && 0 <= y < size.y` (top/left inclusive, bottom/right exclusive); `CircleComponent` overrides it with a radius test. A bare `Component` returns `false` and will never receive events — override it or use a `PositionComponent` with a real `size`.
- Propagation: `Event.deliverToComponents` walks `descendants(reversed: true, includeSelf: true)` (topmost first) and **stops after the first handler** unless that handler sets `event.continuePropagation = true`. Reset to `false` before each component, so set it inside every handler that wants to pass through.
- `event.raw` (1.33+) exposes the underlying Flutter `*Details`.
- `FlameGame` itself is a `Component`, so `class MyGame extends FlameGame with TapCallbacks` works; `FlameGame.containsLocalPoint` returns true for any point inside `canvasSize`.
- Legacy game-level mixins in `package:flame/gestures.dart` (`TapDetector`, `DragDetector`, `LongPressDetector`, …, operating on `*Info` objects) are all `@Deprecated('Use TapCallbacks instead')`. `MultiTouchTapDetector` / `MultiTouchDragDetector` (`package:flame/events.dart`) are not deprecated but are game-level only.
- `IgnoreEvents` mixin skips a subtree during hit testing.

## Effects
```dart
// abstract class Effect extends Component
Effect(EffectController controller, {void Function()? onComplete, ComponentKey? key});
final EffectController controller;  bool removeOnFinish;  // true by default
void Function()? onComplete;
bool get isPaused;  void pause();  void resume();  void reset();  void resetToEnd();

factory MoveEffect.by(Vector2 offset, EffectController c, {PositionProvider? target, void Function()? onComplete, ComponentKey? key});
factory MoveEffect.to(Vector2 destination, EffectController c, {PositionProvider? target, ...});
ScaleEffect.by(Vector2 scaleFactor, EffectController c, {onComplete, key});   // multiplicative
factory ScaleEffect.to(Vector2 targetScale, EffectController c, {onComplete, key});
OpacityEffect.by(double offset, EffectController c, {OpacityProvider? target, ...});
factory OpacityEffect.to(double targetOpacity, EffectController c, {...});
factory OpacityEffect.fadeIn(EffectController c, {...});   // == .to(1.0)
factory OpacityEffect.fadeOut(EffectController c, {...});  // == .to(0.0)
RotateEffect.by(double angle, EffectController c, {...});  // radians
factory RotateEffect.to(double angle, EffectController c, {...});
ColorEffect(Color color, EffectController c, {double opacityFrom = 0, double opacityTo = 1, String? paintId, onComplete, key});
SequenceEffect(List<Effect> effects, {bool alternate = false, bool infinite = false, int repeatCount = 1, onComplete, key});
RemoveEffect({double delay = 0.0, onComplete, key});
```
```dart
factory EffectController({
  double? duration, double? speed, Curve curve = Curves.linear,
  double? reverseDuration, double? reverseSpeed, Curve? reverseCurve,
  bool infinite = false, bool alternate = false, int? repeatCount,
  double startDelay = 0.0, double atMaxDuration = 0.0, double atMinDuration = 0.0,
  VoidCallback? onMax, VoidCallback? onMin,
});
```
- Asserts: exactly one of `duration`/`speed`; `infinite` and `repeatCount` are mutually exclusive; all durations non-negative; `speed > 0`.
- Usage: `component.add(MoveEffect.to(target, EffectController(duration: 0.2, curve: Curves.easeOutCubic), onComplete: () => ...));`
- Effects target providers, not components: `ColorEffect`/`OpacityEffect` need `HasPaint` (all of `SpriteComponent`, `TextComponent`, shape components have it). `OpacityEffect` on text works from 1.38.0.
- `CombinedEffect` (1.34+) runs several effects together; `FunctionEffect`, `GlowEffect`, `HueEffect`, `MoveAlongPathEffect`, `SizeEffect`, `AnchorEffect` also exist.

## Particles
```dart
// ParticleSystemComponent extends PositionComponent; removes itself when particle.shouldRemove
ParticleSystemComponent({Particle? particle, super.position, super.size, super.scale,
  super.angle, super.anchor, super.priority, super.key});

abstract class Particle {
  Particle({double? lifespan});          // default 0.5s
  static Particle generate({required ParticleGenerator generator, int count = 10,
      double? lifespan, bool applyLifespanToChildren = true});  // -> ComposedParticle
  double get lifespan;  bool get shouldRemove;  double get progress;
  void render(Canvas canvas) {}   void update(double dt);
  Particle translated(Vector2 offset);
  Particle moving({required Vector2 to, Vector2? from, Curve curve = Curves.linear});
  Particle accelerated({required Vector2 acceleration, Vector2? position, Vector2? speed});
  Particle rotated(double angle);  Particle rotating({double from = 0, double to = pi});
  Particle scaled(double scale);   ScalingParticle scaling({double to = 0, Curve curve = Curves.linear});
}
CircleParticle({required Paint paint, double radius = 10.0, super.lifespan});
ComputedParticle({required ParticleRenderDelegate renderer, super.lifespan});
  // typedef ParticleRenderDelegate = void Function(Canvas c, Particle particle);
MovingParticle({required Particle child, required Vector2 to, Vector2? from, super.lifespan, super.curve});
AcceleratedParticle({required Particle child, Vector2? acceleration, Vector2? speed, Vector2? position, super.lifespan});
ScalingParticle({required Particle child, double to = 0, super.lifespan, super.curve});
SpriteParticle({required Sprite sprite, Vector2? size, Paint? overridePaint, super.lifespan});
```
- Also: `ComposedParticle`, `TranslatedParticle`, `RotatingParticle`, `ScaledParticle`, `PaintParticle`, `ImageParticle`, `SpriteAnimationParticle`, `ComponentParticle`. Typical burst:
```dart
world.add(ParticleSystemComponent(
  position: cellCenter,
  particle: Particle.generate(count: 16, lifespan: 0.6, generator: (i) => AcceleratedParticle(
    speed: Vector2(rnd.nextDouble() * 200 - 100, -rnd.nextDouble() * 200),
    acceleration: Vector2(0, 400),
    child: CircleParticle(paint: Paint()..color = colour, radius: 3))),
));
```

## Timer / TimerComponent
```dart
// class TimerComponent extends Component { late final Timer timer; }
TimerComponent({required double period, bool repeat = false, bool autoStart = true,
  bool removeOnFinish = false, VoidCallback? onTick, bool tickWhenLoaded = false,
  int? tickCount, super.key});
Timer(double limit, {VoidCallback? onTick, bool repeat = false, bool autoStart = true, int? tickCount});
// Timer: update(dt), start(), stop(), pause(), resume(), reset(), current, progress, finished, isRunning()
```
- For one-off delays inside a component you can also just `add(TimerComponent(period: 0.4, removeOnFinish: true, onTick: () {...}))` or use `Future.delayed` sparingly (not tied to `pauseEngine`).

## Priority / z-order
- `priority` is a plain `int` (negative allowed); **smaller = updated/rendered first (behind)**. Ties break on insertion order.
- Set via `Component(priority: n)` / `PositionComponent(priority: n)`; changing it later is allowed but "relatively expensive" — it enqueues a rebalance of all siblings (`game.enqueuePriorityChange(parent, this)`), applied on the next tick, so ordering changes are not visible until then.
- `CameraComponent` has priority `0x7fffffff` and `World` has `-0x7fffffff`; both are children of `FlameGame`, so ordinary game-level children render between them.

## HasGameReference
```dart
mixin HasGameReference<T extends FlameGame> on Component {
  T get game;  set game(T? value);  @override FlameGame? findGame();
}
@Deprecated('Use HasGameReference instead. This mixin will be removed in a future version of Flame.')
mixin HasGameRef<T extends FlameGame> on Component { T get game;  T get gameRef; }
```
- Both assert the found game is non-null and of type `T`; the lookup is lazy and cached. Also available: `HasWorldReference<T extends World>` (`world`), `HasAncestor<T>`, `ParentIsA<T>`.

## Anchors
```dart
// const Anchor(this.x, this.y);  Anchor get opposite => Anchor(1 - x, 1 - y);  // opposite: 1.36+
topLeft(0,0)  topCenter(.5,0)  topRight(1,0)  centerLeft(0,.5)  center(.5,.5)
centerRight(1,.5)  bottomLeft(0,1)  bottomCenter(.5,1)  bottomRight(1,1)
```
- `anchor` decides what `position` means: with `Anchor.center`, `position` is the component's centre; with the default `Anchor.topLeft` it is its top-left. Rotation and scaling also pivot about the anchor.
- Local coordinates for `render`/`containsLocalPoint` always start at `(0,0)` in the top-left of the component regardless of anchor.

## Coordinate spaces
```dart
Vector2 positionOf(Vector2 point);           // local -> parent
Vector2 absolutePositionOf(Vector2 point);   // local -> world/global (walks all ancestors)
Vector2 positionOfAnchor(Anchor a);  Vector2 absolutePositionOfAnchor(Anchor a);
Vector2 toLocal(Vector2 point);              // parent -> local (inverse of positionOf)
Vector2 absoluteToLocal(Vector2 point);      // world -> local
Vector2 parentToLocal(Vector2 point, {Vector2? output});  Vector2 localToParent(Vector2, {Vector2? output});
Vector2 get topLeftPosition;  Vector2 get center;
Vector2 get absolutePosition;  // == absolutePositionOfAnchor(anchor)
Vector2 get absoluteTopLeftPosition;  Vector2 get absoluteCenter;
double get absoluteAngle;  Vector2 get absoluteScale;  Vector2 get absoluteScaledSize;
Rect toRect();  Rect toAbsoluteRect();
bool containsPoint(Vector2 point);           // == containsLocalPoint(absoluteToLocal(point))
```
- There is **no** `toAbsolute()` method: use `absolutePositionOf(localPoint)`.
- Screen/widget px ↔ world: `camera.globalToLocal(widgetPoint)` and `camera.localToGlobal(worldPoint)` (viewport then viewfinder). Raw pointer coords → widget coords: `game.convertGlobalToLocalCoordinate(devicePosition)` (this is what `canvasPosition` already is).
- Chain for a grid: `event.localPosition` inside a cell component is already cell-local; on the world/game use `event.canvasPosition` then `camera.globalToLocal` to get world coords, then divide by cell size.

## Flutter interop
- `GameWidget` is a normal widget: put it in a `Stack`, `SizedBox`, `Expanded`, etc. It has no intrinsic size — give it bounded constraints (`shrinkwrap` was removed in 1.31).
- Keep the game instance **out of `build()`**: create it once in `State.initState`/as a `late final` field, or use `GameWidget.controlled(gameFactory: MyGame.new)` which builds and owns the instance in the widget's state.
- Overlays vs Stack: overlays are rebuilt by the game (`game.overlays.add(...)` triggers `setState` in `GameWidgetState`) and get the game instance passed to the builder; a plain Flutter `Stack` above the `GameWidget` is fine too but you must plumb your own state. Prefer overlays for pause/HUD/dialogs driven from game code.
- Each `overlays.add/remove/clear` causes a widget rebuild — do not call it every frame.
- `addRepaintBoundary` defaults to `true`; `behavior` (1.36+) controls hit testing of the widget itself.
- `loadingBuilder` shows while `onLoad` futures resolve; `errorBuilder` receives the thrown `Object` — without it, load errors are rethrown into the widget tree.

## Testing with flame_test
```dart
@isTest void testWithGame<T extends FlameGame>(String testName, CreateFunction<T> create,
    AsyncGameFunction<T> testBody, {Timeout? timeout, dynamic tags, dynamic skip, Map<String, dynamic>? onPlatform, int? retry});
@isTest void testWithFlameGame(String testName, AsyncGameFunction<FlameGame> testBody, {...});
Future<T> initializeGame<T extends FlameGame>(CreateFunction<T> create);  // resize 800x600, load, mount, update(0)

class GameTester<T extends Game> {  // FlameTester<T extends FlameGame> extends this
  GameTester(GameCreateFunction<T> createGame, {Vector2? gameSize,
      GameWidgetCreateFunction<T>? createGameWidget, PumpWidgetFunction<T>? pumpWidget});
  void testGameWidget(String description, {WidgetSetupFunction<T>? setUp,
      WidgetVerifyFunction<T>? verify, bool? skip, Timeout? timeout,
      bool? semanticsEnabled, dynamic tags});
}
final flameGame = FlameTester<FlameGame>(FlameGame.new);

@isTest void testGolden(String testName, PrepareFunction testBody,
    {required String goldenFile, Vector2? size, Color? backgroundColor,
     FlameGame? game, bool skip = false});
// typedef PrepareFunction = Future<void> Function(FlameGame game, WidgetTester tester);

Matcher closeToVector(Vector2 vector, [double epsilon = 1e-15]);
// also closeToAabb, closeToMatrix4, closeToQuaternion, closeToVector3/4, expectDouble, failsAssert
extension FlameGameExtension on Component {   // each awaits game.ready()
  Future<void> ensureAdd(Component c);  Future<void> ensureAddAll(Iterable<Component> cs);
  Future<void> ensureRemove(Component c);  Future<void> ensureRemoveAll(Iterable<Component> cs);
}
extension FlameFinds on CommonFinders { Finder byGame<T extends Game>(); }
```
- Mock input helpers exported: `mock_tap_drag_events.dart`, `mock_gesture_events.dart`, `mock_pointer_move_event.dart`, `mock_scroll_event.dart`, `mock_long_press_events.dart`. `testWithGame` runs `game.onRemove()` in a `finally`.

## Text rendering
```dart
// class TextPaint extends TextRenderer
TextPaint({TextStyle? style, TextDirection textDirection = TextDirection.ltr});
final TextStyle style;
static const TextStyle defaultTextStyle =
    TextStyle(color: Color(0xFFFFFFFF), fontFamily: 'Arial', fontSize: 24);
TextPainter toTextPainter(String text);                // cached per string
TextPaint copyWith(TextStyle Function(TextStyle) transform, {TextDirection? textDirection});

abstract class TextRenderer {
  InlineTextElement format(String text);
  LineMetrics getLineMetrics(String text);             // width/height/ascent/descent
  void render(Canvas canvas, String text, Vector2 position, {Anchor anchor = Anchor.topLeft});
}
```
```dart
final renderer = TextPaint(style: const TextStyle(fontSize: 20, color: Color(0xFFFFFFFF)));
renderer.render(canvas, '42', size / 2, anchor: Anchor.center);  // inside render()
final m = renderer.getLineMetrics('42');                         // measure before laying out
world.add(TextComponent(text: 'Score', textRenderer: renderer, anchor: Anchor.center));
```
- `TextComponent` re-measures and overwrites `size` whenever `text` or `textRenderer` changes — do not set `size` on it.
- `TextPaint` caches a `TextPainter` per distinct string forever; a per-frame changing string (e.g. a timer with ms) grows that cache unboundedly.
- `TextBoxComponent` for wrapped/boxed text; `SpriteFontRenderer` for bitmap fonts.

## Gotchas
- `game.size` is `camera.viewport.virtualSize`, **not** the widget size — with `CameraComponent.withFixedResolution` it stays at your virtual resolution forever. Use `game.canvasSize` for real pixels.
- `DragUpdateEvent` is a `DisplacementEvent`, not a `PositionEvent`: there is **no** `localPosition`/`canvasPosition`. Use `localStartPosition`/`localEndPosition`/`localDelta` (or `canvasStartPosition`). `DragEndEvent` extends plain `Event` and only has `pointerId` and `velocity` — no position at all.
- Event delivery stops at the first component that handles it. If two overlapping components (e.g. a cell and its highlight overlay) both need the tap, the topmost must set `event.continuePropagation = true`.
- A component with `size == Vector2.zero()` (the `PositionComponent` default) can never be tapped: `containsLocalPoint` is `x < size.x`, i.e. false everywhere. A raw `Component` returns `false` unconditionally.
- `onLoad` is `FutureOr<void>`: `add()` returns a `Future` you should `await` in tests, and the child is not mounted until the next tick. Reading `parent`/`game` in a constructor or immediately after `add()` fails — do it in `onLoad`/`onMount`.
- `position`/`size`/`scale` are `NotifyingVector2`. `component.position = someVector` copies values in; you cannot keep an alias, and `Vector2` arithmetic like `position + delta` allocates. Prefer `position.add(delta)`/`setValues`.
- `anchor` changes the meaning of `position` retroactively: flipping to `Anchor.center` shifts the component by half its size on screen without changing `position`.
- Changing `priority` at runtime is deferred to the next tick and re-sorts all siblings; for frequent reordering, use separate parent layers instead.
- `SpriteComponent` asserts in `onMount` that `sprite != null`, and passing both `size` and `autoResize: true` trips a constructor assert; writing `size` later silently disables `autoResize`.
- `ScaleEffect.by(Vector2.all(1.2), ...)` is multiplicative relative to the scale at effect start; stacking two of them compounds. `RotateEffect` is in radians.
- `EffectController(duration: ..., speed: ...)` asserts — pick one. `infinite: true` with `repeatCount` also asserts.
- Effects self-remove when finished (`removeOnFinish = true`), so keeping a reference and calling `reset()` later requires setting `removeOnFinish = false` first.
- `ColorEffect`/`OpacityEffect` require a `HasPaint` target; a bare `PositionComponent` has no paint and will fail.
- `camera.visibleWorldRect` asserts if the camera is not yet mounted — never touch it in `onLoad` of a world child; the camera must be added before the component that reads it.
- `camera.follow()`/`moveTo()` call `stop()` first, which removes any `MoveEffect` on the viewfinder — a camera shake implemented as a viewfinder `MoveEffect` will be silently cancelled.
- `ComponentSet` is gone; `children` is a `ReadOnlyOrderedSet<Component>` from `ordered_set ^8`. Use `children.query<T>()`, and don't mutate `children` while iterating (`removeWhere`/`removeAll` are safe).
- Game-level `TapDetector`/`DragDetector` in `package:flame/gestures.dart` are `@Deprecated`; new code uses `TapCallbacks`/`DragCallbacks`. `HasGameRef`/`gameRef` are deprecated in favour of `HasGameReference`/`game`.
- `overlays.add` on an unregistered name trips an assert; with `GameWidget.controlled` the `overlayBuilderMap` is registered when the widget's game is constructed, so calling `overlays.add` before the first build fails.
- Constructing the game inside `build()` recreates and reloads the whole game on every rebuild (including every overlay toggle). Hold it in state or use `GameWidget.controlled`.
- `TapCallbacks` registers its dispatcher in `onMount` but has no `onRemove` counterpart (unlike `DragCallbacks`); rely on removal from the tree rather than expecting explicit deregistration.
