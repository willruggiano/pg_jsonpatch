begin;
set client_min_messages to 'notice';

create extension pg_jsonpatch;

create temporary table test_cases (target jsonb, patch jsonb, result jsonb) on commit drop;

-- @see https://datatracker.ietf.org/doc/html/rfc6902#appendix-A
insert into test_cases
values
  -- add
  ('{"foo":"bar"}'::jsonb, '[{"op":"add","path":"/baz","value":"qux"}]'::jsonb, '{"baz":"qux","foo":"bar"}'::jsonb),
  ('{"foo":["bar","baz"]}', '[{"op":"add","path":"/foo/1","value":"qux"}]', '{"foo":["bar","qux","baz"]}'),
  ('{"q":{"bar":2}}', '[{"op":"add","path":"/a/b","value":"qux"}]', null),
  -- remove
  ('{"baz":"qux","foo":"bar"}', '[{"op":"remove","path":"/baz"}]', '{"foo":"bar"}'),
  ('{"foo":["bar","qux","baz"]}', '[{"op":"remove","path":"/foo/1"}]', '{"foo":["bar","baz"]}'),
  -- replace
  ('{"baz":"qux","foo":"bar"}', '[{"op":"replace","path":"/baz","value":"boo"}]', '{"baz":"boo","foo":"bar"}'),
  -- move
  ('{"foo":{"bar":"baz","waldo":"fred"},"qux":{"corge":"grault"}}', '[{"op":"move","from":"/foo/waldo","path":"/qux/thud"}]', '{"foo":{"bar":"baz"},"qux":{"corge":"grault","thud":"fred"}}'),
  ('{"foo":["all","grass","cows","eat"]}', '[{"op":"move","from":"/foo/1","path":"/foo/3"}]', '{"foo":["all","cows","eat","grass"]}'),
  -- copy
  ('{"foo":"bar"}', '[{"op":"copy","from":"/foo","path":"/bar"}]', '{"foo":"bar","bar":"bar"}'),
  -- test
  ('{"baz":"qux","foo":["a",2,"c"]}', '[{"op":"test","path":"/baz","value":"qux"},{"op":"test","path":"/foo/1","value":2}]', '{"baz":"qux","foo":["a",2,"c"]}'),
  ('{"baz":"qux"}', '[{"op":"test","path":"/baz","value":"bar"}]', null),
  -- adding a nested member object
  ('{"foo":"bar"}', '[{"op":"add","path":"/child","value":{"granchild":{}}}]', '{"foo":"bar","child":{"granchild":{}}}'),
  -- ignore unrecognized elements
  ('{"foo":"bar"}', '[{"op":"add","path":"/baz","value":"qux","xyz":123}]', '{"foo":"bar","baz":"qux"}'),
  -- add to non-existent target
  ('{"foo":"bar"}', '[{"op":"add","path":"/baz/bat","value":"qux","xyz":123}]', null),
  -- adding an array value
  ('{"foo":["bar"]}', '[{"op":"add","path":"/foo/-","value":["abc","def"]}]', '{"foo":["bar",["abc","def"]]}')
;

insert into test_cases
select
  '{"foo":"bar"}',
  jsonb_agg(patch),
  '{"bar":"foo","baz":"qux","foo":"bar"}'
from (
  values
    ('{"op":"add","path":"/baz","value":"qux"}'::jsonb),
    ('{"op":"add","path":"/bar","value":"foo"}')
) as patches(patch);

select * from test_cases;

insert into test_cases
select
  '{"foo":"bar"}',
  jsonb_agg(patch),
  '{"foo":"bar"}'
from (
  values
    ('{"op":"add","path":"/baz","value":"qux"}'::jsonb),
    ('{"op":"remove","path":"/baz"}')
) as patches(patch);

insert into test_cases
select
  '{"foo":"bar"}',
  jsonb_agg(patch),
  '{"bar":"qux","foo":"bar"}'
from (
  values
    ('{"op":"add","path":"/baz","value":"qux"}'::jsonb),
    ('{"op":"move","from":"/baz","path":"/bar"}')
) as patches(patch);

insert into test_cases
select
  '{"foo":"bar"}',
  jsonb_agg(patch),
  '{"baz":"bar","foo":"bar"}'
from (
  values
    ('{"op":"add","path":"/baz","value":"qux"}'::jsonb),
    ('{"op":"replace","path":"/baz","value":"bar"}')
) as patches(patch);

-- @see https://datatracker.ietf.org/doc/html/rfc6902#section-5
insert into test_cases
select
  '{"a":{"b":{"c":"C"}}}',
  jsonb_agg(patch),
  null
from (
  values
    ('{"op":"replace","path":"/a/b/c","value":42}'::jsonb),
    ('{"op":"test","path":"/a/b/c","value":"C"}')
) as patches(patch);

select plan(count(*)::int) from test_cases;

select is(jsonb_patch(target, patch), result)
from test_cases;

select * from finish();
rollback;
