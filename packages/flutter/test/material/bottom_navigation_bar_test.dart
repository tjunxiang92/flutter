// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rendering/mock_canvas.dart';
import '../widgets/semantics_tester.dart';

void main() {
  testWidgets('BottomNavigationBar callback test', (WidgetTester tester) async {
    int mutatedIndex;

    await tester.pumpWidget(
      new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.ac_unit),
                title: Text('AC')
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.access_alarm),
                title: Text('Alarm')
              )
            ],
            onTap: (int index) {
              mutatedIndex = index;
            }
          )
        )
      )
    );

    await tester.tap(find.text('Alarm'));

    expect(mutatedIndex, 1);
  });

  testWidgets('BottomNavigationBar content test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.ac_unit),
                title: Text('AC')
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.access_alarm),
                title: Text('Alarm')
              )
            ]
          )
        )
      )
    );

    final RenderBox box = tester.renderObject(find.byType(BottomNavigationBar));
    expect(box.size.height, kBottomNavigationBarHeight);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('Alarm'), findsOneWidget);
  });

  testWidgets('BottomNavigationBar adds bottom padding to height', (WidgetTester tester) async {
    await tester.pumpWidget(
      new MaterialApp(
        home: new MediaQuery(
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 40.0)),
          child: new Scaffold(
            bottomNavigationBar: new BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.ac_unit),
                  title: Text('AC')
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.access_alarm),
                  title: Text('Alarm')
                )
              ]
            )
          )
        )
      )
    );

    const double labelBottomMargin = 8.0; // _kBottomMargin in implementation.
    const double additionalPadding = 40.0 - labelBottomMargin;
    const double expectedHeight = kBottomNavigationBarHeight + additionalPadding;
    expect(tester.getSize(find.byType(BottomNavigationBar)).height, expectedHeight);
  });

  testWidgets('BottomNavigationBar action size test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            type: BottomNavigationBarType.shifting,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.ac_unit),
                title: Text('AC')
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.access_alarm),
                title: Text('Alarm')
              )
            ]
          )
        )
      )
    );

    Iterable<RenderBox> actions = tester.renderObjectList(find.byType(InkResponse));
    expect(actions.length, 2);
    expect(actions.elementAt(0).size.width, 480.0);
    expect(actions.elementAt(1).size.width, 320.0);

    await tester.pumpWidget(
      new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            currentIndex: 1,
            type: BottomNavigationBarType.shifting,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.ac_unit),
                title: Text('AC')
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.access_alarm),
                title: Text('Alarm')
              )
            ]
          )
        )
      )
    );

    await tester.pump(const Duration(milliseconds: 200));

    actions = tester.renderObjectList(find.byType(InkResponse));
    expect(actions.length, 2);
    expect(actions.elementAt(0).size.width, 320.0);
    expect(actions.elementAt(1).size.width, 480.0);
  });

  testWidgets('BottomNavigationBar multiple taps test', (WidgetTester tester) async {
    await tester.pumpWidget(
      new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            type: BottomNavigationBarType.shifting,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.ac_unit),
                title: Text('AC')
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.access_alarm),
                title: Text('Alarm')
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.access_time),
                title: Text('Time')
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.add),
                title: Text('Add')
              )
            ]
          )
        )
      )
    );

    // We want to make sure that the last label does not get displaced,
    // irrespective of how many taps happen on the first N - 1 labels and how
    // they grow.

    Iterable<RenderBox> actions = tester.renderObjectList(find.byType(InkResponse));
    final Offset originalOrigin = actions.elementAt(3).localToGlobal(Offset.zero);

    await tester.tap(find.text('AC'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    actions = tester.renderObjectList(find.byType(InkResponse));
    expect(actions.elementAt(3).localToGlobal(Offset.zero), equals(originalOrigin));

    await tester.tap(find.text('Alarm'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    actions = tester.renderObjectList(find.byType(InkResponse));
    expect(actions.elementAt(3).localToGlobal(Offset.zero), equals(originalOrigin));

    await tester.tap(find.text('Time'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    actions = tester.renderObjectList(find.byType(InkResponse));
    expect(actions.elementAt(3).localToGlobal(Offset.zero), equals(originalOrigin));
  });

  testWidgets('BottomNavigationBar inherits shadowed app theme for shifting navbar', (WidgetTester tester) async {
    await tester.pumpWidget(
      new MaterialApp(
        theme: new ThemeData(brightness: Brightness.light),
        home: new Theme(
          data: new ThemeData(brightness: Brightness.dark),
          child: new Scaffold(
            bottomNavigationBar: new BottomNavigationBar(
              type: BottomNavigationBarType.shifting,
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.ac_unit),
                  title: Text('AC')
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.access_alarm),
                  title: Text('Alarm')
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.access_time),
                  title: Text('Time')
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add),
                  title: Text('Add')
                )
              ]
            )
          )
        )
      )
    );

    await tester.tap(find.text('Alarm'));
    await tester.pump(const Duration(seconds: 1));
    expect(Theme.of(tester.element(find.text('Alarm'))).brightness, equals(Brightness.dark));
  });

  testWidgets('BottomNavigationBar inherits shadowed app theme for fixed navbar', (WidgetTester tester) async {
    await tester.pumpWidget(
      new MaterialApp(
        theme: new ThemeData(brightness: Brightness.light),
        home: new Theme(
          data: new ThemeData(brightness: Brightness.dark),
          child: new Scaffold(
            bottomNavigationBar: new BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  icon: Icon(Icons.ac_unit),
                  title: Text('AC')
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.access_alarm),
                  title: Text('Alarm')
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.access_time),
                  title: Text('Time')
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add),
                  title: Text('Add')
                )
              ]
            )
          )
        )
      )
    );

    await tester.tap(find.text('Alarm'));
    await tester.pump(const Duration(seconds: 1));
    expect(Theme.of(tester.element(find.text('Alarm'))).brightness, equals(Brightness.dark));
  });

  testWidgets('BottomNavigationBar iconSize test', (WidgetTester tester) async {
    double builderIconSize;
    await tester.pumpWidget(
      new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            iconSize: 12.0,
            items: <BottomNavigationBarItem>[
              const BottomNavigationBarItem(
                title: Text('A'),
                icon: Icon(Icons.ac_unit),
              ),
              new BottomNavigationBarItem(
                title: const Text('B'),
                icon: new Builder(
                  builder: (BuildContext context) {
                    builderIconSize = IconTheme.of(context).size;
                    return new SizedBox(
                      width: builderIconSize,
                      height: builderIconSize,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final RenderBox box = tester.renderObject(find.byType(Icon));
    expect(box.size.width, equals(12.0));
    expect(box.size.height, equals(12.0));
    expect(builderIconSize, 12.0);
  });


  testWidgets('BottomNavigationBar responds to textScaleFactor', (WidgetTester tester) async {
    await tester.pumpWidget(
      new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                title: Text('A'),
                icon: Icon(Icons.ac_unit),
              ),
              BottomNavigationBarItem(
                title: Text('B'),
                icon: Icon(Icons.battery_alert),
              ),
            ],
          ),
        ),
      ),
    );

    final RenderBox defaultBox = tester.renderObject(find.byType(BottomNavigationBar));
    expect(defaultBox.size.height, equals(kBottomNavigationBarHeight));

    await tester.pumpWidget(
      new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            type: BottomNavigationBarType.shifting,
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                title: Text('A'),
                icon: Icon(Icons.ac_unit),
              ),
              BottomNavigationBarItem(
                title: Text('B'),
                icon: Icon(Icons.battery_alert),
              ),
            ],
          ),
        ),
      ),
    );

    final RenderBox shiftingBox = tester.renderObject(find.byType(BottomNavigationBar));
    expect(shiftingBox.size.height, equals(kBottomNavigationBarHeight));

    await tester.pumpWidget(
      new MaterialApp(
        home: new MediaQuery(
          data: const MediaQueryData(textScaleFactor: 2.0),
          child: new Scaffold(
            bottomNavigationBar: new BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(
                  title: Text('A'),
                  icon: Icon(Icons.ac_unit),
                ),
                BottomNavigationBarItem(
                  title: Text('B'),
                  icon: Icon(Icons.battery_alert),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final RenderBox box = tester.renderObject(find.byType(BottomNavigationBar));
    expect(box.size.height, equals(68.0));
  });

  testWidgets('BottomNavigationBar limits width of tiles with long titles', (WidgetTester tester) async {
    final Text longTextA = new Text(''.padLeft(100, 'A'));
    final Text longTextB = new Text(''.padLeft(100, 'B'));

    await tester.pumpWidget(
      new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            items: <BottomNavigationBarItem>[
              new BottomNavigationBarItem(
                title: longTextA,
                icon: const Icon(Icons.ac_unit),
              ),
              new BottomNavigationBarItem(
                title: longTextB,
                icon: const Icon(Icons.battery_alert),
              ),
            ],
          ),
        ),
      ),
    );

    final RenderBox box = tester.renderObject(find.byType(BottomNavigationBar));
    expect(box.size.height, equals(kBottomNavigationBarHeight));

    final RenderBox itemBoxA = tester.renderObject(find.text(longTextA.data));
    expect(itemBoxA.size, equals(const Size(400.0, 14.0)));
    final RenderBox itemBoxB = tester.renderObject(find.text(longTextB.data));
    expect(itemBoxB.size, equals(const Size(400.0, 14.0)));
  });

  testWidgets('BottomNavigationBar paints circles', (WidgetTester tester) async {
    await tester.pumpWidget(
      boilerplate(
        textDirection: TextDirection.ltr,
        bottomNavigationBar: new BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              title: Text('A'),
              icon: Icon(Icons.ac_unit),
            ),
            BottomNavigationBarItem(
              title: Text('B'),
              icon: Icon(Icons.battery_alert),
            ),
          ],
        ),
      ),
    );

    final RenderBox box = tester.renderObject(find.byType(BottomNavigationBar));
    expect(box, isNot(paints..circle()));

    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(box, paints..circle(x: 200.0));

    await tester.tap(find.text('B'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(box, paints..circle(x: 200.0)..circle(x: 600.0));

    // Now we flip the directionality and verify that the circles switch positions.
    await tester.pumpWidget(
      boilerplate(
        textDirection: TextDirection.rtl,
        bottomNavigationBar: new BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              title: Text('A'),
              icon: Icon(Icons.ac_unit),
            ),
            BottomNavigationBarItem(
              title: Text('B'),
              icon: Icon(Icons.battery_alert),
            ),
          ],
        ),
      ),
    );

    expect(box, paints..circle(x: 600.0)..circle(x: 200.0));

    await tester.tap(find.text('A'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(box, paints..circle(x: 600.0)..circle(x: 200.0)..circle(x: 600.0));
  });

  testWidgets('BottomNavigationBar inactiveIcon shown', (WidgetTester tester) async {
    const Key filled = Key('filled');
    const Key stroked = Key('stroked');
    int selectedItem = 0;

    await tester.pumpWidget(
      boilerplate(
        textDirection: TextDirection.ltr,
        bottomNavigationBar: new BottomNavigationBar(
          currentIndex: selectedItem,
          items:  const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              activeIcon: Icon(Icons.favorite, key: filled),
              icon: Icon(Icons.favorite_border, key: stroked),
              title: Text('Favorite'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_alarm),
              title: Text('Alarm'),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(filled), findsOneWidget);
    expect(find.byKey(stroked), findsNothing);
    selectedItem = 1;

    await tester.pumpWidget(
      boilerplate(
        textDirection: TextDirection.ltr,
        bottomNavigationBar: new BottomNavigationBar(
          currentIndex: selectedItem,
          items:  const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              activeIcon: Icon(Icons.favorite, key: filled),
              icon: Icon(Icons.favorite_border, key: stroked),
              title: Text('Favorite'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_alarm),
              title: Text('Alarm'),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(filled), findsNothing);
    expect(find.byKey(stroked), findsOneWidget);
  });

  testWidgets('BottomNavigationBar semantics', (WidgetTester tester) async {
    final SemanticsTester semantics = new SemanticsTester(tester);

    await tester.pumpWidget(
      boilerplate(
        textDirection: TextDirection.ltr,
        bottomNavigationBar: new BottomNavigationBar(
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.ac_unit),
              title: Text('AC'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.access_alarm),
              title: Text('Alarm'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.hot_tub),
              title: Text('Hot Tub'),
            ),
          ],
        ),
      ),
    );

    final TestSemantics expected = new TestSemantics.root(
      children: <TestSemantics>[
        new TestSemantics(
          id: 1,
          children: <TestSemantics>[
            new TestSemantics(
              id: 2,
              children: <TestSemantics>[
                new TestSemantics(
                  id: 3,
                  flags: <SemanticsFlag>[SemanticsFlag.isSelected],
                  actions: <SemanticsAction>[SemanticsAction.tap],
                  label: 'AC\nTab 1 of 3',
                  textDirection: TextDirection.ltr,
                ),
                new TestSemantics(
                  id: 4,
                  actions: <SemanticsAction>[SemanticsAction.tap],
                  label: 'Alarm\nTab 2 of 3',
                  textDirection: TextDirection.ltr,
                ),
                new TestSemantics(
                  id: 5,
                  actions: <SemanticsAction>[SemanticsAction.tap],
                  label: 'Hot Tub\nTab 3 of 3',
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ],
        ),
      ],
    );
    expect(semantics, hasSemantics(expected, ignoreTransform: true, ignoreRect: true));

    semantics.dispose();
  });

  testWidgets('BottomNavigationBar handles items.length changes', (WidgetTester tester) async {
    // Regression test for https://github.com/flutter/flutter/issues/10322

    Widget buildFrame(int itemCount) {
      return new MaterialApp(
        home: new Scaffold(
          bottomNavigationBar: new BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: 0,
            items: new List<BottomNavigationBarItem>.generate(itemCount, (int itemIndex) {
              return new BottomNavigationBarItem(
                icon: const Icon(Icons.android),
                title: new Text('item $itemIndex'),
              );
            }),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildFrame(3));
    expect(find.text('item 0'), findsOneWidget);
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 2'), findsOneWidget);
    expect(find.text('item 3'), findsNothing);

    await tester.pumpWidget(buildFrame(4));
    expect(find.text('item 0'), findsOneWidget);
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 2'), findsOneWidget);
    expect(find.text('item 3'), findsOneWidget);

    await tester.pumpWidget(buildFrame(2));
    expect(find.text('item 0'), findsOneWidget);
    expect(find.text('item 1'), findsOneWidget);
    expect(find.text('item 2'), findsNothing);
    expect(find.text('item 3'), findsNothing);
  });
}

Widget boilerplate({ Widget bottomNavigationBar, @required TextDirection textDirection }) {
  assert(textDirection != null);
  return new Localizations(
    locale: const Locale('en', 'US'),
    delegates: const <LocalizationsDelegate<dynamic>>[
      DefaultMaterialLocalizations.delegate,
      DefaultWidgetsLocalizations.delegate,
    ],
    child: new Directionality(
      textDirection: textDirection,
      child: new MediaQuery(
        data: const MediaQueryData(),
        child: new Material(
          child: new Scaffold(
            bottomNavigationBar: bottomNavigationBar,
          ),
        ),
      ),
    ),
  );
}
