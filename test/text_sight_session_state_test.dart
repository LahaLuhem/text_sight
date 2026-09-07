// Tests
// ignore_for_file: prefer-match-file-name

import 'package:bdd_framework/bdd_framework.dart';
import 'package:checks/checks.dart';
import 'package:text_sight/text_sight.dart';

void main() {
  final equality = BddFeature('TextSightSessionState value equality');

  Bdd(equality)
      .scenario('States built separately from the same payload are equal and hash alike')
      .given('a <reason> and <details> payload')
      .when('a paused and a failed state are each built twice from it')
      .then('each pair is equal with the same hash code')
      .example(val('reason', SessionPauseReason.appBackgrounded), val('details', null))
      .example(val('reason', SessionPauseReason.interrupted), val('details', 'phone call'))
      .run((ctx) {
        final reason = ctx.example.val('reason') as SessionPauseReason;
        final details = ctx.example.val('details') as String?;

        final paused = SessionPaused(reason: reason, details: details);
        final pausedAgain = SessionPaused(reason: reason, details: details);
        final failed = SessionFailed(details: details);
        final failedAgain = SessionFailed(details: details);

        check(paused).equals(pausedAgain);
        check(paused.hashCode).equals(pausedAgain.hashCode);
        check(failed).equals(failedAgain);
        check(failed.hashCode).equals(failedAgain.hashCode);
      });

  Bdd(equality)
      .scenario('States differ when the payload or the case differs')
      .given('a paused state with a reason and details')
      .when('it is compared against states differing in one aspect')
      .then('none of them is equal to it')
      .run((_) {
        const paused = SessionPaused(reason: SessionPauseReason.interrupted, details: 'call');

        check(paused).not(
          (it) => it.equals(
            const SessionPaused(reason: SessionPauseReason.appBackgrounded, details: 'call'),
          ),
        );
        check(paused)
            .not((it) => it.equals(const SessionPaused(reason: SessionPauseReason.interrupted)));
        // Same details, different case: equality is per case, not per payload.
        check<TextSightSessionState>(paused)
            .not((it) => it.equals(const SessionFailed(details: 'call')));
      });

  Bdd(equality)
      .scenario('Payload-less states are equal across instances and differ across cases')
      .given('two idle and two active instances built separately')
      .when('they are compared')
      .then('same-case pairs are equal and cross-case pairs are not')
      .run((_) {
        // Two distinct instances on purpose: const would canonicalise them and prove nothing.
        // ignore: prefer_const_constructors
        final (idle, active) = (SessionIdle(), SessionActive());

        check(idle).equals(const SessionIdle());
        check(idle.hashCode).equals(const SessionIdle().hashCode);
        check(active).equals(const SessionActive());
        check<TextSightSessionState>(idle).not((it) => it.equals(active));
      });

  Bdd(equality)
      .scenario('toString names the case and carries the payload')
      .given('one state of each case')
      .when('each is printed')
      .then('the text shows the case and, where present, the fields')
      .run((_) {
        check(const SessionIdle().toString()).equals('SessionIdle()');
        check(const SessionActive().toString()).equals('SessionActive()');
        check(
          const SessionPaused(reason: SessionPauseReason.interrupted, details: 'call').toString(),
        ).equals('SessionPaused(reason: SessionPauseReason.interrupted, details: call)');
        check(const SessionFailed().toString()).equals('SessionFailed(details: null)');
      });
}
