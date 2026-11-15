import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/game_config.dart';
import '../levels/level.dart';
import '../levels/level_repository.dart';
import '../logic/board_state.dart';
import '../logic/rules.dart';
import '../logic/undo_stack.dart';

/// High-level phase of the game screen.
enum GamePhase {
  /// Level is loading from the repository.
  loading,

  /// Player is making moves.
  playing,

  /// A pour animation is running — input is locked.
  animating,

  /// No legal move exists and the board is not won.
  stuck,

  /// Every jar is empty or a complete single-colour jar.
  won,
}

/// Immutable snapshot the UI and Flame game read.
@immutable
class GameState {
  /// Creates a fully-specified snapshot.
  const GameState({
    required this.phase,
    required this.board,
    required this.level,
    required this.moveCount,
    required this.undosLeft,
    required this.selectedJar,
    required this.extraJarAdded,
    this.hidden = const [],
  });

  /// Initial state before any level loads.
  factory GameState.loading() => const GameState(
    phase: GamePhase.loading,
    board: null,
    level: null,
    moveCount: 0,
    undosLeft: GameConfig.freeUndosPerLevel,
    selectedJar: null,
    extraJarAdded: false,
  );

  final GamePhase phase;

  /// Current board snapshot; null while loading.
  final BoardState? board;

  /// Level definition; null while loading.
  final Level? level;

  /// Moves made since the level loaded or was last restarted.
  final int moveCount;

  /// Free undos remaining.
  final int undosLeft;

  /// Index of the currently selected jar, or null.
  final int? selectedJar;

  /// Whether +1 Jar has been used this level.
  final bool extraJarAdded;

  /// Per jar: bottom layers still hidden ("?"). Only ever decreases.
  final List<int> hidden;

  /// Hidden layers in jar [index].
  int hiddenAt(int index) => index < hidden.length ? hidden[index] : 0;

  /// Par move count from the solver; null while loading.
  int? get par => level?.par;

  /// Star rating when [phase] is [GamePhase.won]; otherwise null.
  int? get stars {
    if (phase != GamePhase.won || par == null || par! <= 0) return null;
    if (moveCount <= par!) return 3;
    if (moveCount < par! * 1.5) return 2;
    return 1;
  }

  /// Returns a copy with selected fields replaced.
  GameState copyWith({
    GamePhase? phase,
    BoardState? board,
    Level? level,
    int? moveCount,
    int? undosLeft,
    Object? selectedJar = _sentinel,
    bool? extraJarAdded,
    List<int>? hidden,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      board: board ?? this.board,
      level: level ?? this.level,
      moveCount: moveCount ?? this.moveCount,
      undosLeft: undosLeft ?? this.undosLeft,
      selectedJar: selectedJar == _sentinel
          ? this.selectedJar
          : selectedJar as int?,
      extraJarAdded: extraJarAdded ?? this.extraJarAdded,
      hidden: hidden ?? this.hidden,
    );
  }
}

/// Reveals hidden layers that have reached the top of their jar.
List<int> revealHidden(List<int> hidden, BoardState board) {
  return [
    for (var i = 0; i < board.jarCount; i++)
      i < hidden.length
          ? (board.jars[i].isEmpty
                ? 0
                : (hidden[i] < board.jars[i].layers.length - 1
                      ? hidden[i]
                      : board.jars[i].layers.length - 1))
          : 0,
  ];
}

// Sentinel so copyWith can distinguish explicit null from "not provided".
const Object _sentinel = Object();

// ─────────────────────────────────────────────────────────────────────────────

/// Result returned by [GameController.handleTap].
@immutable
class TapResult {
  const TapResult._(this._kind, {this.from, this.to, this.count});

  /// No action needed (tapped empty jar while nothing selected, etc.).
  static const TapResult none = TapResult._(_TapKind.none);

  /// A jar was selected.
  static const TapResult select = TapResult._(_TapKind.select);

  /// The selected jar was deselected.
  static const TapResult deselect = TapResult._(_TapKind.deselect);

  /// An illegal target was tapped — trigger a shake.
  static const TapResult illegal = TapResult._(_TapKind.illegal);

  /// A legal pour: [from], [to], and [count] are set.
  factory TapResult.pour({
    required int from,
    required int to,
    required int count,
  }) => TapResult._(_TapKind.pour, from: from, to: to, count: count);

  final _TapKind _kind;

  /// Source jar index. Only valid when [isPour].
  final int? from;

  /// Target jar index. Only valid when [isPour].
  final int? to;

  /// Layer count moved. Only valid when [isPour].
  final int? count;

  bool get isPour => _kind == _TapKind.pour;
  bool get isIllegal => _kind == _TapKind.illegal;
  bool get isSelect => _kind == _TapKind.select;
  bool get isDeselect => _kind == _TapKind.deselect;
}

enum _TapKind { none, select, deselect, illegal, pour }

// ─────────────────────────────────────────────────────────────────────────────

/// Drives all game logic; Riverpod exposes it via [gameControllerProvider].
class GameController extends Notifier<GameState> {
  /// Creates a controller. Optional [repository] is for tests.
  GameController({LevelRepository? repository})
    : _repositoryOverride = repository;

  final LevelRepository? _repositoryOverride;
  late final LevelRepository _repository;
  final _rules = const Rules();
  final _undo = UndoStack();

  @override
  GameState build() {
    _repository = _repositoryOverride ?? LevelRepository();
    return GameState.loading();
  }

  /// Public read of the current snapshot (for Flame / UI helpers).
  GameState get snapshot => state;

  // ── Level lifecycle ───────────────────────────────────────────────────────

  /// Loads [levelId] from the repository and resets all counters.
  Future<void> loadLevel(int levelId) async {
    state = GameState.loading();
    final level = await _repository.getById(levelId);
    _applyLevel(level);
  }

  /// Loads an already-built [level] (campaign or daily).
  void loadLevelData(Level level) {
    state = GameState.loading();
    _applyLevel(level);
  }

  void _applyLevel(Level level) {
    final board = level.toBoardState();
    _undo.reset(board);
    state = GameState(
      phase: GamePhase.playing,
      board: board,
      level: level,
      moveCount: 0,
      undosLeft: GameConfig.freeUndosPerLevel,
      selectedJar: null,
      extraJarAdded: false,
      hidden: revealHidden(_initialHidden(level), board),
    );
  }

  List<int> _initialHidden(Level level) => [
    for (var i = 0; i < level.jars.length; i++) level.hiddenAt(i),
  ];

  /// Resets the current level to its initial board.
  void restart() {
    final level = state.level;
    if (level == null) return;
    final board = level.toBoardState();
    _undo.reset(board);
    state = state.copyWith(
      phase: GamePhase.playing,
      board: board,
      moveCount: 0,
      undosLeft: GameConfig.freeUndosPerLevel,
      selectedJar: null,
      extraJarAdded: false,
      hidden: revealHidden(_initialHidden(level), board),
    );
  }

  // ── Tap handling ──────────────────────────────────────────────────────────

  /// Processes a tap on jar [index] and returns what should happen visually.
  TapResult handleTap(int index) {
    final s = state;
    if (s.phase != GamePhase.playing || s.board == null) return TapResult.none;

    final selected = s.selectedJar;

    if (s.board!.jars[index].isLocked) {
      // Locked jars can't be selected or poured into.
      state = s.copyWith(selectedJar: null);
      return TapResult.illegal;
    }

    if (selected == null) {
      // Nothing selected — select this jar if non-empty.
      if (s.board!.jars[index].isEmpty) return TapResult.none;
      state = s.copyWith(selectedJar: index);
      return TapResult.select;
    }

    if (selected == index) {
      // Tap same jar — deselect.
      state = s.copyWith(selectedJar: null);
      return TapResult.deselect;
    }

    final count = _rules.pourCount(s.board!, selected, index);
    if (count == 0) {
      // Illegal target — shake and deselect.
      state = s.copyWith(selectedJar: null);
      return TapResult.illegal;
    }

    // Legal pour — lock input, clear selection.
    state = s.copyWith(phase: GamePhase.animating, selectedJar: null);
    return TapResult.pour(from: selected, to: index, count: count);
  }

  /// Attempts a direct pour from [from] to [to] (e.g. via drag-and-drop).
  TapResult attemptPour(int from, int to) {
    final s = state;
    if (s.phase != GamePhase.playing || s.board == null) return TapResult.none;
    if (from == to) {
      state = s.copyWith(selectedJar: null);
      return TapResult.deselect;
    }

    final count = _rules.pourCount(s.board!, from, to);
    if (count == 0) {
      state = s.copyWith(selectedJar: null);
      return TapResult.illegal;
    }

    // Legal pour — lock input, clear selection.
    state = s.copyWith(phase: GamePhase.animating, selectedJar: null);
    return TapResult.pour(from: from, to: to, count: count);
  }

  // ── Called by Flame after pour animation finishes ─────────────────────────

  /// Applies the logical pour [from] → [to] once the animation is done.
  void applyAnimationComplete(int from, int to) {
    final s = state;
    if (s.board == null) return;

    final result = _rules.applyPour(s.board!, from, to);
    final newBoard = result.board;
    _undo.push(newBoard);

    final GamePhase nextPhase;
    if (_rules.isWon(newBoard)) {
      nextPhase = GamePhase.won;
    } else if (_rules.isStuck(newBoard)) {
      nextPhase = GamePhase.stuck;
    } else {
      nextPhase = GamePhase.playing;
    }

    state = s.copyWith(
      phase: nextPhase,
      board: newBoard,
      moveCount: s.moveCount + 1,
      hidden: revealHidden(s.hidden, newBoard),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Undoes the last move. Returns the restored board, or null if unavailable.
  BoardState? undo() {
    final s = state;
    if (s.phase != GamePhase.playing && s.phase != GamePhase.stuck) return null;
    if (s.undosLeft <= 0) return null;

    final prev = _undo.undo();
    if (prev == null) return null;

    state = s.copyWith(
      phase: GamePhase.playing,
      board: prev,
      moveCount: (s.moveCount - 1).clamp(0, 9999),
      undosLeft: s.undosLeft - 1,
      selectedJar: null,
      // Revealed layers stay revealed after an undo.
      hidden: revealHidden(s.hidden, prev),
    );
    return prev;
  }

  /// Grants [count] extra undos (called after a rewarded ad in Phase 7).
  void grantUndos(int count) {
    state = state.copyWith(undosLeft: state.undosLeft + count);
  }

  /// Adds one extra empty jar. Can only be used once per level.
  void addExtraJar() {
    final s = state;
    if (s.board == null || s.extraJarAdded) return;
    final newBoard = s.board!.withExtraEmptyJar();
    _undo.push(newBoard);
    state = s.copyWith(
      board: newBoard,
      extraJarAdded: true,
      hidden: [...s.hidden, 0],
      phase: _rules.isStuck(newBoard) ? GamePhase.stuck : GamePhase.playing,
    );
  }
}

// ── Riverpod provider ─────────────────────────────────────────────────────────

/// Provides the [GameController]. Override in tests with a custom notifier.
final gameControllerProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);
