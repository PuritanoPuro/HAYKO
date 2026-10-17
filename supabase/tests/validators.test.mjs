// Runs entirely in an isolated PostgreSQL WASM database, never against Supabase.
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

const read = name => readFile(new URL(`../migrations/${name}`, import.meta.url), 'utf8');
const bootstrap = await read('20261016_account_v1.sql');
const invites = await read('20261017_short_invites.sql');
const patch = await read('20261018_json_containment_precedence.sql');
const db = new PGlite();
const user = '11111111-1111-4111-8111-111111111111';
const other = '22222222-2222-4222-8222-222222222222';
const color = 4290508136;
const clone = value => structuredClone(value);
const base = {
  id: 'test-sync', name: 'Test', type: 'amateur',
  primaryColor: color, secondaryColor: color,
  players: ['a','b','c','d'].map(id => ({id, name:id.toUpperCase(), color})),
  presets: [], competitions: [], matches: [],
};
const match = {
  id:'m', format:2, names:['A','B'], teams:[['a','b'],['c','d']],
  status:'scheduled', startedAt:null, finishedAt:null, goals:[], creatorId:user,
  scheduledAt:'2026-10-17T18:00:00Z', venue:'', teamColors:[color,color],
  presetIds:[null,null], competitionId:null, knockoutRound:null,
  qualifiedTeamId:null, competitionRules:false,
  keepers:[['a','b'],['c','d']].map(order => ({mode:'rotation',fixed:null,order,minutes:5,sound:true,vibration:true})),
};
const rotation = {...clone(base), matches:[clone(match)]};
const teams = {...clone(base), presets:[
  {id:'A',name:'A',color,players:['a','b'],numbers:{a:1,b:2},archived:false},
  {id:'B',name:'B',color,players:['c','d'],numbers:{c:1,d:2},archived:false},
]};
const competition = {...clone(teams),type:'competition',competitions:[
  {id:'cup',name:'Cup',kind:'league',format:2,teamIds:['A','B'],doubleLeg:false},
]};
const fixture = {...clone(match),competitionRules:true,competitionId:'cup',presetIds:['A','B'],
  keepers:[{mode:'none'},{mode:'none'}]};
competition.matches=[fixture];
const validate = state => db.query('select public.bc_validate($1::jsonb)',[JSON.stringify(state)]);
const metadata = () => db.query(`select oid::text, proname, proowner::text, proacl::text, proconfig, prosecdef
  from pg_proc where oid in ('public.bc_validate(jsonb)'::regprocedure,'public.bc_validate_rules_v041(jsonb)'::regprocedure) order by proname`);
const definition = name => db.query('select pg_get_functiondef($1::regprocedure) as body',[name]);
const save = (state,revision) => db.query('select public.bc_save($1,$2,$3::jsonb) as revision',[state.id,revision,JSON.stringify(state)]);

try {
  await db.exec(`create role anon; create role authenticated; create schema auth;
    create table auth.users(id uuid primary key, email text, raw_user_meta_data jsonb default '{}'::jsonb);
    create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid $$;`);
  await db.exec(bootstrap);
  await db.exec(invites);
  await db.query('insert into auth.users(id) values ($1),($2)',[user,other]);
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user]);
  await db.query('select public.bc_create($1::jsonb)',[JSON.stringify(base)]);
  for (const [label,state] of [['rotation',rotation],['preset',teams],['competition',competition]]) {
    await assert.rejects(validate(state), e => e.code === '42883', `${label}: reproduce precedence error`);
  }
  const beforeMeta = (await metadata()).rows;
  const beforeState = (await db.query('select * from public.bc_leagues')).rows;
  await db.exec(patch);
  assert.deepEqual((await metadata()).rows,beforeMeta,'function ACL, ownership and settings retained');
  assert.deepEqual((await db.query('select * from public.bc_leagues')).rows,beforeState,'stored state and revisions unchanged');
  const fixed = (await definition('public.bc_validate(jsonb)')).rows;
  await db.exec(patch);
  assert.deepEqual((await definition('public.bc_validate(jsonb)')).rows,fixed,'manual/already applied patch is idempotent');
  for (const state of [rotation,teams,competition]) await validate(state);
  const badRotation=clone(rotation);badRotation.matches[0].keepers[0].order=['a','c'];
  await assert.rejects(validate(badRotation), /INVALID_ROTATION/);
  const badPreset=clone(teams);badPreset.presets[0].players=['missing'];badPreset.presets[0].numbers={};
  await assert.rejects(validate(badPreset), /INVALID_PRESET_ROSTER/);
  const badCompetition=clone(competition);badCompetition.competitions[0].teamIds=['A','missing'];
  await assert.rejects(validate(badCompetition), /INVALID_COMPETITION_TEAMS/);
  const duplicate=clone(competition);duplicate.matches.push({...clone(fixture),id:'m2'});
  await assert.rejects(validate(duplicate), /DUPLICATE_FIXTURE/);
  const knockout=clone(competition);knockout.competitions[0].kind='knockout';knockout.matches[0].knockoutRound=1;
  await validate(knockout);
  let state=clone(rotation), revision=0;
  revision=(await save(state,revision)).rows[0].revision;
  state.matches[0].status='live';state.matches[0].startedAt='2026-10-17T18:00:00Z';
  revision=(await save(state,revision)).rows[0].revision;
  state.matches[0].goals.push({id:'g',team:0,scorer:'a',assist:'b',keeper:'c',ownGoal:false,time:'2026-10-17T18:01:00Z',voided:false});
  revision=(await save(state,revision)).rows[0].revision;
  assert.equal((await save(state,revision-1)).rows[0].revision,revision,'identical retry does not duplicate goal');
  const changed=clone(state);changed.matches[0].goals[0].voided=true;
  await assert.rejects(save(changed,revision-1),/REVISION_CONFLICT/);
  await db.query("insert into public.bc_members(league_id,user_id,role) values ($1,$2,'admin')",[base.id,other]);
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[other]);
  await assert.rejects(save(changed,revision),/ONLY_EVENT_CREATOR/);
  await db.query("select set_config('request.jwt.claim.sub',$1,false)",[user]);
  state.matches[0].status='finished';state.matches[0].finishedAt='2026-10-17T19:00:00Z';
  await save(state,revision);
  const rules = (await definition('public.bc_validate_rules_v041(jsonb)')).rows[0].body;
  // Check transactional rollback if the second validator has an unknown body.
  await db.exec(rules.replace("team @> (k->'order')", "team @> k->'order'"));
  await db.exec("create or replace function public.bc_validate(s jsonb) returns void language plpgsql set search_path='' as $$ begin return; end; $$");
  await assert.rejects(db.exec(patch),/HAYKO_PATCH_UNEXPECTED_DEFINITION/);
  await db.exec('rollback');
  assert.ok((await definition('public.bc_validate_rules_v041(jsonb)')).rows[0].body.includes("team @> k->'order'"),'failed patch rolls back all function changes');
  console.log('PASS: error reproduced; rotation, presets, league and knockout validated; ACL/state preserved; retry, conflict and event ownership retained; patch idempotence and rollback verified.');
} finally { await db.close(); }
