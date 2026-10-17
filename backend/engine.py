"""Motore transazionale di riferimento, SQLite, NON servizio di produzione.
actor arriva da un'identità già verificata dal gateway, mai dal payload JSON.
"""
import json
import sqlite3
from contextlib import closing


class Rejected(Exception):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


class Engine:
    def __init__(self, path):
        self.path = path
        with closing(self.connect()) as db, db:
            db.executescript('''
              CREATE TABLE IF NOT EXISTS matches(id TEXT PRIMARY KEY, data TEXT NOT NULL);
              CREATE TABLE IF NOT EXISTS receipts(
                match_id TEXT, command_id TEXT, actor TEXT, request TEXT, response TEXT,
                PRIMARY KEY(match_id, command_id));
            ''')

    def connect(self):
        return sqlite3.connect(self.path, timeout=10)

    def create(self, match_id, teams, organizer, recorder, members):
        if (len(teams) != 2 or len(teams[0]) != len(teams[1]) or
                not 2 <= len(teams[0]) <= 11 or
                len(set(teams[0] + teams[1])) != len(teams[0]) * 2 or
                organizer not in members or recorder not in members):
            raise Rejected('INVALID_ROSTER')
        m = dict(id=match_id, revision=0, status='scheduled', teams=teams,
                 organizer=organizer, recorder=recorder, members=members, goals=[], audit=[])
        with closing(self.connect()) as db, db:
            db.execute('INSERT INTO matches VALUES (?,?)', (match_id, json.dumps(m)))

    def snapshot(self, match_id):
        with closing(self.connect()) as db:
            row = db.execute('SELECT data FROM matches WHERE id=?', (match_id,)).fetchone()
        if row is None:
            raise Rejected('NOT_FOUND')
        return json.loads(row[0])

    @staticmethod
    def score(m):
        return [sum(not g['voided'] and g['team'] == team for g in m['goals']) for team in range(2)]

    def apply(self, match_id, actor, cmd):
        if (not isinstance(cmd, dict) or not isinstance(cmd.get('command_id'), str) or
                not cmd['command_id'] or len(cmd['command_id']) > 128 or
                type(cmd.get('expected_revision')) is not int or
                not isinstance(cmd.get('payload'), dict) or
                cmd.get('type') not in {'start', 'finish', 'goal', 'void_goal', 'transfer_recorder'}):
            raise Rejected('INVALID_COMMAND')
        request = json.dumps(cmd, sort_keys=True, separators=(',', ':'))
        db = self.connect()
        try:
            # Serializza i writer. In PostgreSQL: SELECT ... FOR UPDATE sul match.
            db.execute('BEGIN IMMEDIATE')
            row = db.execute('SELECT data FROM matches WHERE id=?', (match_id,)).fetchone()
            if row is None:
                raise Rejected('NOT_FOUND')
            m = json.loads(row[0])
            if actor not in m['members']:
                raise Rejected('FORBIDDEN')
            prior = db.execute('SELECT actor,request,response FROM receipts WHERE match_id=? AND command_id=?',
                               (match_id, cmd['command_id'])).fetchone()
            if prior:
                if prior[0] != actor or prior[1] != request:
                    raise Rejected('ID_REUSED')
                return json.loads(prior[2])  # client recupera poi snapshot corrente
            kind, p = cmd['type'], cmd['payload']
            permitted = actor == m['organizer'] if kind == 'transfer_recorder' else actor == m['recorder']
            if not permitted:
                raise Rejected('NOT_RECORDER')
            if cmd['expected_revision'] != m['revision']:
                raise Rejected('REVISION_CONFLICT')
            if kind == 'start':
                if m['status'] != 'scheduled':
                    raise Rejected('INVALID_STATE')
                m['status'] = 'live'
            elif kind == 'finish':
                if m['status'] != 'live':
                    raise Rejected('INVALID_STATE')
                m['status'] = 'finished'
            elif kind == 'transfer_recorder':
                if m['status'] == 'finished' or p.get('recorder') not in m['members']:
                    raise Rejected('INVALID_RECORDER')
                m['recorder'] = p['recorder']
            elif kind == 'void_goal':
                if m['status'] != 'live':
                    raise Rejected('INVALID_STATE')
                g = next((g for g in m['goals'] if g['id'] == p.get('goal_id')), None)
                if g is None or g['voided']:
                    raise Rejected('INVALID_GOAL')
                g['voided'] = True
            elif kind == 'goal':
                if m['status'] != 'live':
                    raise Rejected('INVALID_STATE')
                team, own = p.get('team'), p.get('own_goal', False)
                if type(team) is not int or team not in (0, 1) or type(own) is not bool:
                    raise Rejected('INVALID_GOAL')
                scorer, assist, keeper = p.get('scorer'), p.get('assist'), p.get('keeper')
                attack, defence = m['teams'][team], m['teams'][1-team]
                if scorer is not None and scorer not in (defence if own else attack):
                    raise Rejected('INVALID_SCORER')
                if assist is not None and (own or assist not in attack or assist == scorer):
                    raise Rejected('INVALID_ASSIST')
                if keeper is not None and keeper not in defence:
                    raise Rejected('INVALID_KEEPER')
                m['goals'].append(dict(id=cmd['command_id'], team=team, own_goal=own,
                                      scorer=scorer, assist=assist, keeper=keeper, voided=False))
            m['revision'] += 1
            m['audit'].append(dict(actor=actor, command_id=cmd['command_id'], type=kind, revision=m['revision']))
            response = dict(command_id=cmd['command_id'], revision=m['revision'], score=self.score(m), status=m['status'])
            db.execute('UPDATE matches SET data=? WHERE id=?', (json.dumps(m), match_id))
            db.execute('INSERT INTO receipts VALUES (?,?,?,?,?)',
                       (match_id, cmd['command_id'], actor, request, json.dumps(response)))
            db.commit()
            return response
        except Exception:
            db.rollback()
            raise
        finally:
            db.close()
