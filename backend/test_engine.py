import concurrent.futures
import tempfile
import unittest
from engine import Engine, Rejected


class EngineTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.e = Engine(self.tmp.name + '/test.db')
        self.e.create('m', [['a', 'b'], ['c', 'd']], 'owner', 'u', ['owner', 'u', 'v'])

    def tearDown(self):
        self.tmp.cleanup()

    def command(self, kind, revision, identifier, **payload):
        return dict(command_id=identifier, type=kind, expected_revision=revision, payload=payload)

    def start(self):
        self.e.apply('m', 'u', self.command('start', 0, 'start'))

    def goal(self, identifier='g', revision=1, **payload):
        return self.command('goal', revision, identifier, **(dict(team=0, scorer='a', assist='b', keeper='c') | payload))

    def assertReject(self, code, actor, command):
        with self.assertRaises(Rejected) as ctx:
            self.e.apply('m', actor, command)
        self.assertEqual(ctx.exception.code, code)

    def test_score_and_void(self):
        self.start()
        self.assertEqual(self.e.apply('m', 'u', self.goal())['score'], [1, 0])
        result = self.e.apply('m', 'u', self.command('void_goal', 2, 'void', goal_id='g'))
        self.assertEqual(result['score'], [0, 0])
        self.assertTrue(self.e.snapshot('m')['goals'][0]['voided'])

    def test_retry_after_finish_is_idempotent(self):
        self.start()
        original = self.e.apply('m', 'u', self.goal())
        self.e.apply('m', 'u', self.command('finish', 2, 'end'))
        self.assertEqual(self.e.apply('m', 'u', self.goal()), original)
        self.assertEqual(len(self.e.snapshot('m')['goals']), 1)

    def test_reused_id_is_rejected(self):
        self.start(); self.e.apply('m', 'u', self.goal())
        self.assertReject('ID_REUSED', 'u', self.goal(scorer='b', assist=None))

    def test_wrong_team_and_self_assist_and_keeper(self):
        self.start()
        for code, payload in [('INVALID_SCORER', dict(scorer='c')), ('INVALID_ASSIST', dict(assist='a')),
                              ('INVALID_KEEPER', dict(keeper='a'))]:
            self.assertReject(code, 'u', self.goal(**payload))
        self.assertEqual(self.e.snapshot('m')['revision'], 1)

    def test_unknown_fields_and_own_goal(self):
        self.start()
        result = self.e.apply('m', 'u', self.goal(own_goal=True, scorer='c', assist=None, keeper=None))
        self.assertEqual(result['score'], [1, 0])
        self.assertReject('INVALID_ASSIST', 'u', self.goal('g2', 2, own_goal=True, scorer='c'))

    def test_not_recorder_and_non_member(self):
        self.start()
        self.assertReject('NOT_RECORDER', 'v', self.goal())
        self.assertReject('FORBIDDEN', 'stranger', self.goal())

    def test_transfer_invalidates_stale_authority(self):
        self.start()
        self.e.apply('m', 'owner', self.command('transfer_recorder', 1, 'transfer', recorder='v'))
        self.assertReject('NOT_RECORDER', 'u', self.goal())
        self.assertEqual(self.e.apply('m', 'v', self.goal(revision=2))['score'], [1, 0])

    def test_concurrent_same_request_one_goal(self):
        self.start()
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: self.e.apply('m', 'u', self.goal()), range(2)))
        self.assertEqual(results[0], results[1])
        self.assertEqual(len(self.e.snapshot('m')['goals']), 1)

    def test_two_distinct_concurrent_goals_require_resolution(self):
        self.start()
        def apply(identifier):
            try:
                self.e.apply('m', 'u', self.goal(identifier))
                return 'ok'
            except Rejected as e:
                return e.code
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results = list(pool.map(apply, ['g1', 'g2']))
        self.assertCountEqual(results, ['ok', 'REVISION_CONFLICT'])

    def test_goal_after_finish_rejected(self):
        self.start(); self.e.apply('m', 'u', self.command('finish', 1, 'end'))
        self.assertReject('INVALID_STATE', 'u', self.goal(revision=2))

    def test_goal_before_start_and_boolean_team_rejected(self):
        self.assertReject('INVALID_STATE', 'u', self.goal(revision=0))
        self.start()
        self.assertReject('INVALID_GOAL', 'u', self.goal(team=True))

    def test_atomic_failure_and_void_twice(self):
        self.start(); self.e.apply('m', 'u', self.goal())
        self.e.apply('m', 'u', self.command('void_goal', 2, 'void', goal_id='g'))
        self.assertReject('INVALID_GOAL', 'u', self.command('void_goal', 3, 'void2', goal_id='g'))
        self.assertEqual(self.e.snapshot('m')['revision'], 3)


if __name__ == '__main__':
    unittest.main()
