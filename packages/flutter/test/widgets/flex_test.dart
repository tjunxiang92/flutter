// Copyright 2015 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

void main() {
  testWidgets('Can hit test flex children of stacks', (WidgetTester tester) async {
    bool didReceiveTap = false;
    await tester.pumpWidget(
      new Directionality(
        textDirection: TextDirection.ltr,
        child: new Container(
          color: const Color(0xFF00FF00),
          child: new Stack(
            children: <Widget>[
              new Positioned(
                top: 10.0,
                left: 10.0,
                child: new Column(
                  children: <Widget>[
                    new GestureDetector(
                      onTap: () {
                        didReceiveTap = true;
                      },
                      child: new Container(
                        color: const Color(0xFF0000FF),
                        width: 100.0,
                        height: 100.0,
                        child: const Center(
                          child: Text('X', textDirection: TextDirection.ltr),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.tap(find.text('X'));
    expect(didReceiveTap, isTrue);
  });

  testWidgets('Flexible defaults to loose', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Row(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          Flexible(child: SizedBox(width: 100.0, height: 200.0)),
        ],
      ),
    );

    final RenderBox box = tester.renderObject(find.byType(SizedBox));
    expect(box.size.width, 100.0);
  });

  testWidgets('Can pass null for flex', (WidgetTester tester) async {
    await tester.pumpWidget(
      new Row(
        textDirection: TextDirection.ltr,
        children: const <Widget>[
          Expanded(flex: null, child: Text('one', textDirection: TextDirection.ltr)),
          Flexible(flex: null, child: Text('two', textDirection: TextDirection.ltr)),
        ],
      ),
    );
  });

  testWidgets('Doesn\'t overflow because of floating point accumulated error', (WidgetTester tester) async {
    // both of these cases have failed in the past due to floating point issues
    await tester.pumpWidget(
      new Center(
        child: new Container(
          height: 400.0,
          child: new Column(
            children: <Widget>[
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(
      new Center(
        child: new Container(
          height: 199.0,
          child: new Column(
            children: <Widget>[
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
              new Expanded(child: new Container()),
            ],
          ),
        ),
      ),
    );
  });

  testWidgets('Error information is printed correctly', (WidgetTester tester) async {
    // We run this twice, the first time without an error, so that the second time
    // we only get a single exception. Otherwise we'd get two, the one we want and
    // an extra one when we discover we never computed a size.
    await tester.pumpWidget(
      new Column(
        children: <Widget>[
          new Column(),
        ],
      ),
      Duration.zero,
      EnginePhase.layout,
    );
    await tester.pumpWidget(
      new Column(
        children: <Widget>[
          new Column(
            children: <Widget>[
              new Expanded(child: new Container()),
            ],
          ),
        ],
      ),
      Duration.zero,
      EnginePhase.layout,
    );
    final String message = tester.takeException().toString();
    expect(message, contains('\nSee also:'));
  });
}
