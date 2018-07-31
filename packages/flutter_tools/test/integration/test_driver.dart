// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:process/process.dart';
import 'package:source_span/source_span.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:vm_service_client/vm_service_client.dart';
import 'package:web_socket_channel/io.dart';

import '../src/common.dart';

// Set this to true for debugging to get JSON written to stdout.
const bool _printJsonAndStderr = false;
const Duration defaultTimeout = Duration(seconds: 20);
const Duration appStartTimeout = Duration(seconds: 60);
const Duration quitTimeout = Duration(seconds: 5);

class FlutterTestDriver {
  final Directory _projectFolder;
  Process _proc;
  int _procPid;
  final StreamController<String> _stdout = new StreamController<String>.broadcast();
  final StreamController<String> _stderr = new StreamController<String>.broadcast();
  final StreamController<String> _allMessages = new StreamController<String>.broadcast();
  final StringBuffer _errorBuffer = new StringBuffer();
  String _lastResponse;
  String _currentRunningAppId;
  Uri _vmServiceWsUri;
  int _vmServicePort;

  FlutterTestDriver(this._projectFolder);

  VMServiceClient vmService;
  String get lastErrorInfo => _errorBuffer.toString();
  int get vmServicePort => _vmServicePort;

  String _debugPrint(String msg) {
    const int maxLength = 500;
    final String truncatedMsg =
        msg.length > maxLength ? msg.substring(0, maxLength) + '...' : msg;
    _allMessages.add(truncatedMsg);
    if (_printJsonAndStderr) {
      print(truncatedMsg);
    }
    return msg;
  }

  // TODO(dantup): Is there a better way than spawning a proc? This breaks debugging..
  // However, there's a lot of logic inside RunCommand that wouldn't be good
  // to duplicate here.
  Future<void> run({bool withDebugger = false}) async {
    await _setupProcess(<String>[
        'run',
        '--machine',
        '-d',
        'flutter-tester',
    ], withDebugger: withDebugger);
  }

  Future<void> attach(int port, {bool withDebugger = false}) async {
    await _setupProcess(<String>[
        'attach',
        '--machine',
        '-d',
        'flutter-tester',
        '--debug-port',
        '$port',
    ], withDebugger: withDebugger);
  }

  Future<void> _setupProcess(List<String> args, {bool withDebugger = false}) async {
    final String flutterBin = fs.path.join(getFlutterRoot(), 'bin', 'flutter');
    _debugPrint('Spawning flutter $args in ${_projectFolder.path}');

    const ProcessManager _processManager = LocalProcessManager();
    _proc = await _processManager.start(
        <String>[flutterBin]
            .followedBy(args)
            .followedBy(withDebugger ? <String>['--start-paused'] : <String>[])
            .toList(),
        workingDirectory: _projectFolder.path,
        environment: <String, String>{'FLUTTER_TEST': 'true'});

    _transformToLines(_proc.stdout).listen((String line) => _stdout.add(line));
    _transformToLines(_proc.stderr).listen((String line) => _stderr.add(line));

    // Capture stderr to a buffer so we can show it all if any requests fail.
    _stderr.stream.listen(_errorBuffer.writeln);

    // This is just debug printing to aid running/debugging tests locally.
    _stdout.stream.listen(_debugPrint);
    _stderr.stream.listen(_debugPrint);

    // Stash the PID so that we can terminate the VM more reliably than using
    // _proc.kill() (because _proc is a shell, because `flutter` is a shell
    // script).
    final Map<String, dynamic> connected = await _waitFor(event: 'daemon.connected');
    _procPid = connected['params']['pid'];

    // Set this up now, but we don't wait it yet. We want to make sure we don't
    // miss it while waiting for debugPort below.
    final Future<Map<String, dynamic>> started = _waitFor(event: 'app.started',
        timeout: appStartTimeout);

    if (withDebugger) {
      final Map<String, dynamic> debugPort = await _waitFor(event: 'app.debugPort',
          timeout: appStartTimeout);
      final String wsUriString = debugPort['params']['wsUri'];
      _vmServiceWsUri = Uri.parse(wsUriString);
      _vmServicePort = debugPort['params']['port'];
      // Proxy the stream/sink for the VM Client so we can debugPrint it.
      final StreamChannel<String> channel = new IOWebSocketChannel.connect(_vmServiceWsUri)
          .cast<String>()
          .changeStream((Stream<String> stream) => stream.map(_debugPrint))
          .changeSink((StreamSink<String> sink) =>
              new StreamController<String>()
                ..stream.listen((String s) => sink.add(_debugPrint(s))));
      vmService = new VMServiceClient(channel);

      // Because we start paused, resume so the app is in a "running" state as
      // expected by tests. Tests will reload/restart as required if they need
      // to hit breakpoints, etc.
      await waitForPause();
      await resume(wait: false);
    }

    // Now await the started event; if it had already happened the future will
    // have already completed.
    _currentRunningAppId = (await started)['params']['appId'];
  }

  Future<void> hotRestart({bool pause = false}) => _restart(fullRestart: true, pause: pause);
  Future<void> hotReload() => _restart(fullRestart: false);

  Future<void> _restart({bool fullRestart = false, bool pause = false}) async {
    if (_currentRunningAppId == null)
      throw new Exception('App has not started yet');

    final dynamic hotReloadResp = await _sendRequest(
        'app.restart',
        <String, dynamic>{'appId': _currentRunningAppId, 'fullRestart': fullRestart, 'pause': pause}
    );

    if (hotReloadResp == null || hotReloadResp['code'] != 0)
      _throwErrorResponse('Hot ${fullRestart ? 'restart' : 'reload'} request failed');
  }

  Future<int> stop() async {
    if (vmService != null) {
      _debugPrint('Closing VM service');
      await vmService.close()
          .timeout(quitTimeout,
              onTimeout: () { _debugPrint('VM Service did not quit within $quitTimeout'); });
    }
    if (_currentRunningAppId != null) {
      _debugPrint('Stopping app');
      await _sendRequest(
        'app.stop',
        <String, dynamic>{'appId': _currentRunningAppId}
      ).timeout(
        quitTimeout,
        onTimeout: () { _debugPrint('app.stop did not return within $quitTimeout'); }
      );
      _currentRunningAppId = null;
    }
    _debugPrint('Waiting for process to end');
    return _proc.exitCode.timeout(quitTimeout, onTimeout: _killGracefully);
  }

  Future<int> _killGracefully() async {
    if (_procPid == null)
      return -1;
    _debugPrint('Sending SIGTERM to $_procPid..');
    Process.killPid(_procPid);
    return _proc.exitCode.timeout(quitTimeout, onTimeout: _killForcefully);
  }

  Future<int> _killForcefully() {
    _debugPrint('Sending SIGKILL to $_procPid..');
    Process.killPid(_procPid, ProcessSignal.SIGKILL);
    return _proc.exitCode;
  }

  Future<void> addBreakpoint(String path, int line) async {
    final VM vm = await vmService.getVM();
    final VMIsolate isolate = await vm.isolates.first.load();
    _debugPrint('Sending breakpoint for $path:$line');
    await isolate.addBreakpoint(path, line);
  }

  Future<VMIsolate> waitForPause() async {
    final VM vm = await vmService.getVM();
    final VMIsolate isolate = await vm.isolates.first.load();
    _debugPrint('Waiting for isolate to pause');
    await _timeoutWithMessages<dynamic>(isolate.waitUntilPaused,
        message: 'Isolate did not pause');
    return isolate.load();
  }

  Future<VMIsolate> resume({ bool wait = true }) => _resume(wait: wait);
  Future<VMIsolate> stepOver({ bool wait = true }) => _resume(step: VMStep.over, wait: wait);
  Future<VMIsolate> stepInto({ bool wait = true }) => _resume(step: VMStep.into, wait: wait);
  Future<VMIsolate> stepOut({ bool wait = true }) => _resume(step: VMStep.out, wait: wait);

  Future<VMIsolate> _resume({VMStep step, bool wait = true}) async {
    final VM vm = await vmService.getVM();
    final VMIsolate isolate = await vm.isolates.first.load();
    _debugPrint('Sending resume ($step)');
    await _timeoutWithMessages<dynamic>(() => isolate.resume(step: step),
        message: 'Isolate did not respond to resume ($step)');
    return wait ? waitForPause() : null;
  }

  Future<VMIsolate> breakAt(String path, int line, { bool restart = false }) async {
    if (restart) {
      // For a hot restart, we need to send the breakpoints after the restart
      // so we need to pause during the restart to avoid races.
      await hotRestart(pause: true);
      await addBreakpoint(path, line);
      return resume();
    } else {
      await addBreakpoint(path, line);
      await hotReload();
      return waitForPause();
    }
  }

  Future<VMInstanceRef> evaluateExpression(String expression) async {
    final VMFrame topFrame = await getTopStackFrame();
    return _timeoutWithMessages(() => topFrame.evaluate(expression),
        message: 'Timed out evaluating expression ($expression)');
  }

  Future<VMFrame> getTopStackFrame() async {
    final VM vm = await vmService.getVM();
    final VMIsolate isolate = await vm.isolates.first.load();
    final VMStack stack = await isolate.getStack();
    if (stack.frames.isEmpty) {
      throw new Exception('Stack is empty');
    }
    return stack.frames.first;
  }

  Future<FileLocation> getSourceLocation() async {
    final VMFrame frame = await getTopStackFrame();
    final VMScript script = await frame.location.script.load();
    return script.sourceLocation(frame.location.token);
  }

  Future<Map<String, dynamic>> _waitFor({String event, int id, Duration timeout}) async {
    final Completer<Map<String, dynamic>> response = new Completer<Map<String, dynamic>>();
    final StreamSubscription<String> sub = _stdout.stream.listen((String line) {
      final dynamic json = _parseFlutterResponse(line);
      if (json == null) {
        return;
      } else if (
          (event != null && json['event'] == event)
          || (id != null && json['id'] == id)) {
        response.complete(json);
      }
    });

    return _timeoutWithMessages(() => response.future,
            timeout: timeout,
            message: event != null
                ? 'Did not receive expected $event event.'
                : 'Did not receive response to request "$id".')
        .whenComplete(() => sub.cancel());
  }

  Future<T> _timeoutWithMessages<T>(Future<T> Function() f, {Duration timeout, String message}) {
    // Capture output to a buffer so if we don't get the response we want we can show
    // the output that did arrive in the timeout error.
    final StringBuffer messages = new StringBuffer();
    final DateTime start = new DateTime.now();
    void logMessage(String m) {
      final int ms = new DateTime.now().difference(start).inMilliseconds;
      messages.writeln('[+ ${ms.toString().padLeft(5)}] $m');
    }
    final StreamSubscription<String> sub = _allMessages.stream.listen(logMessage);

    return f().timeout(timeout ?? defaultTimeout, onTimeout: () {
      logMessage('<timed out>');
      throw '$message\nReceived:\n${messages.toString()}';
    }).whenComplete(() => sub.cancel());
  }

  Map<String, dynamic> _parseFlutterResponse(String line) {
    if (line.startsWith('[') && line.endsWith(']')) {
      try {
        final Map<String, dynamic> resp = json.decode(line)[0];
        _lastResponse = line;
        return resp;
      } catch (e) {
        // Not valid JSON, so likely some other output that was surrounded by [brackets]
        return null;
      }
    }
    return null;
  }

  int id = 1;
  Future<dynamic> _sendRequest(String method, dynamic params) async {
    final int requestId = id++;
    final Map<String, dynamic> req = <String, dynamic>{
      'id': requestId,
      'method': method,
      'params': params
    };
    final String jsonEncoded = json.encode(<Map<String, dynamic>>[req]);
    _debugPrint(jsonEncoded);

    // Set up the response future before we send the request to avoid any
    // races.
    final Future<Map<String, dynamic>> responseFuture = _waitFor(id: requestId);
    _proc.stdin.writeln(jsonEncoded);
    final Map<String, dynamic> resp = await responseFuture;

    if (resp['error'] != null || resp['result'] == null)
      _throwErrorResponse('Unexpected error response');

    return resp['result'];
  }

  void _throwErrorResponse(String msg) {
    throw '$msg\n\n$_lastResponse\n\n${_errorBuffer.toString()}'.trim();
  }
}

Stream<String> _transformToLines(Stream<List<int>> byteStream) {
  return byteStream.transform(utf8.decoder).transform(const LineSplitter());
}
