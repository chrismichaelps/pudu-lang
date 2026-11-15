import assert from 'node:assert/strict';
import test from 'node:test';
import { inventory, measure, recorded, render, update } from '../scripts/uikit-coverage.mjs';

const headers = [
  `@interface UIView : UIResponder <NSCoding>
@interface UIControl : UIView
@interface UIButton : UIControl <NSCoding>
@interface UISlider : UIControl
@interface UILabel : UIView <NSCoding>
@interface UIScrollView : UIView
@interface UICollectionView : UIScrollView <UIDataSourceTranslating>
@interface UIView (UIViewHierarchy)
@interface UIMenu : UIMenuElement
`,
  `@interface UIGestureRecognizer : NSObject
@interface UIPanGestureRecognizer : UIGestureRecognizer
@interface UIScreenEdgePanGestureRecognizer : UIPanGestureRecognizer
@interface UIFeedbackGenerator : NSObject
@interface UIImpactFeedbackGenerator : UIFeedbackGenerator
@interface UIDiffable<SectionType,ItemType> : NSObject<NSCopying>
UIKIT_EXTERN const UIAccessibilityTraits UIAccessibilityTraitNone;
UIKIT_EXTERN const UIAccessibilityTraits UIAccessibilityTraitButton API_AVAILABLE(watchos(2.0));
UIKIT_EXTERN const UIAccessibilityTraits UIAccessibilityTraitHeader;
`,
];

const host = `
UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
UICollectionViewCell *cell; UILabel *label;
[[UIPanGestureRecognizer alloc] init];
traits |= UIAccessibilityTraitHeader;
`;

test('classifies direct and transitive subclasses', () => {
  assert.deepEqual(inventory(headers), {
    controls: ['UIButton', 'UISlider'],
    views: ['UICollectionView', 'UIControl', 'UILabel', 'UIScrollView'],
    gestures: ['UIPanGestureRecognizer', 'UIScreenEdgePanGestureRecognizer'],
    feedback: ['UIImpactFeedbackGenerator'],
    traits: ['UIAccessibilityTraitButton', 'UIAccessibilityTraitHeader'],
  });
});

test('fails when a category is empty', () => {
  assert.throws(() => inventory([headers[0]]), /No gestures found/);
});

test('survives an inheritance cycle', () => {
  const found = inventory([...headers, '@interface UILoopA : UILoopB\n@interface UILoopB : UILoopA\n']);
  assert.equal(found.views.includes('UILoopA'), false);
});

test('matches whole identifiers in the host', () => {
  const report = measure(inventory(headers), host);
  assert.deepEqual(report.controls, { covered: ['UIButton'], missing: ['UISlider'] });
  assert.deepEqual(report.views, {
    covered: ['UILabel'],
    missing: ['UICollectionView', 'UIControl', 'UIScrollView'],
  });
  assert.deepEqual(report.gestures.covered, ['UIPanGestureRecognizer']);
  assert.deepEqual(report.feedback, { covered: [], missing: ['UIImpactFeedbackGenerator'] });
  assert.deepEqual(report.traits.covered, ['UIAccessibilityTraitHeader']);
});

const block = render('iPhoneSimulator1.0', measure(inventory(headers), host));

test('renders literal rows', () => {
  assert.equal(block, [
    'Measured against `iPhoneSimulator1.0`.',
    '',
    '| Category | Covered | In the host | Not in the host |',
    '| --- | --- | --- | --- |',
    '| Controls | 1 of 2 | `UIButton` | `UISlider` |',
    '| Views | 1 of 4 | `UILabel` | `UICollectionView`, `UIControl`, `UIScrollView` |',
    '| Gestures | 1 of 2 | `UIPanGestureRecognizer` | `UIScreenEdgePanGestureRecognizer` |',
    '| Feedback | 0 of 1 | none | `UIImpactFeedbackGenerator` |',
    '| Accessibility traits | 1 of 2 | `UIAccessibilityTraitHeader` | `UIAccessibilityTraitButton` |',
  ].join('\n'));
});

const page = 'before\n<!-- uikit-coverage:start -->\nold\n<!-- uikit-coverage:end -->\nafter\n';

test('replaces only the block and is idempotent', () => {
  const next = update(page, block);
  assert.equal(next, `before\n<!-- uikit-coverage:start -->\n${block}\n<!-- uikit-coverage:end -->\nafter\n`);
  assert.equal(update(next, block), next);
});

test('rejects missing, duplicate and reversed markers', () => {
  const message = /one ordered uikit-coverage marker pair/;
  assert.throws(() => update('no markers', block), message);
  assert.throws(() => update(page + page, block), message);
  assert.throws(
    () => update('<!-- uikit-coverage:end -->\n<!-- uikit-coverage:start -->', block), message);
});

test('reads back the recorded SDK and names', () => {
  const known = recorded(update(page, block));
  assert.equal(known.sdk, 'iPhoneSimulator1.0');
  assert.equal(known.names.has('UISlider'), true);
  assert.equal(known.names.has('UIStepper'), false);
  assert.equal(recorded(page).sdk, null);
});
