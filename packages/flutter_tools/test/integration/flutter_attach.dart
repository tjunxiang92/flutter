// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:file/file.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:test/test.dart';

import '../src/context.dart';
import 'test_data/basic_project.dart';
import 'test_driver.dart';

FlutterTestDriver _flutterRun, _flutterAttach;
BasicProject _project = new BasicProject();

void main() {

  setUp(() async {
    final Directory tempDir = await fs.systemTempDirectory.createTemp('test_app');
    await _project.setUpIn(tempDir);
    _flutterRun = new FlutterTestDriver(tempDir);
    _flutterAttach = new FlutterTestDriver(tempDir);
  });

  tearDown(() async {
    try {
      await _flutterRun.stop();
      await _flutterAttach.stop();
      _project.cleanup();
    } catch (e) {
      // Don't fail tests if we failed to clean up temp folder.
    }
  });

  group('attached process', () {
    testUsingContext('can hot reload', () async {
      await _flutterRun.run(withDebugger: true);
      await _flutterAttach.attach(_flutterRun.vmServicePort);

      await _flutterAttach.hotReload();
    });
  }, timeout: const Timeout.factor(3));
}
