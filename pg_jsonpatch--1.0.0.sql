\echo Use "CREATE EXTENSION pg_jsonpatch" to load this file. \quit

create or replace function jsonb_patch_add(target jsonb, path text[], value jsonb)
returns jsonb
as $$
  with x as (
    select jsonb_typeof(jsonb_extract_path(target, variadic trim_array(path, 1))) as t
  )
  select jsonb_set(target, path, value, true)
  from x
  where x.t = 'object'
  union all
  select jsonb_insert(target, path, value)
  from x
  where x.t = 'array' and path[array_length(path, 1)] is distinct from '-'
  union all
  select jsonb_insert(target, trim_array(path, 1) || array['-1'], value, true)
  from x
  where x.t = 'array' and path[array_length(path, 1)] = '-'
  limit 1
$$
language sql
immutable;

create or replace function jsonb_patch_remove(target jsonb, path text[])
returns jsonb
as $$ select jsonb_set_lax(target, path, null, false, 'delete_key') $$
language sql
immutable;

create or replace function jsonb_patch_replace(target jsonb, path text[], value jsonb)
returns jsonb
as $$ select @extschema@.jsonb_patch_add(@extschema@.jsonb_patch_remove(target, path), path, value) $$
language sql
immutable;

create or replace function jsonb_patch_move(target jsonb, _from text[], path text[])
returns jsonb
as $$
  with old as (
    select jsonb_extract_path(target, variadic _from) as value
  )

  select @extschema@.jsonb_patch_add(@extschema@.jsonb_patch_remove(target, _from), path, value)
  from old
$$
language sql
immutable;

create or replace function jsonb_patch_copy(target jsonb, _from text[], path text[])
returns jsonb
as $$
  select @extschema@.jsonb_patch_add(target, path, jsonb_extract_path(target, variadic _from))
$$
language sql
immutable;

create or replace function jsonb_patch_test(target jsonb, path text[], value jsonb)
returns jsonb
as $$ select target where jsonb_extract_path(target, variadic path) = value $$
language sql
immutable;

create or replace function jsonb_patch_split_path(path text)
returns text[]
as $$ select array_remove(string_to_array(path, '/'), '') $$
language sql
immutable;

create or replace function jsonb_patch_apply(target jsonb, patch jsonb)
returns jsonb
as $$
declare
  op text := patch->>'op';
  path text[] := @extschema@.jsonb_patch_split_path(patch->>'path');
  rv jsonb;
begin
  case patch->>'op'
    when 'add' then rv := @extschema@.jsonb_patch_add(target, path, patch->'value');
    when 'remove' then rv := @extschema@.jsonb_patch_remove(target, path);
    when 'replace' then rv := @extschema@.jsonb_patch_replace(target, path, patch->'value');
    when 'move' then rv := @extschema@.jsonb_patch_move(target, @extschema@.jsonb_patch_split_path(patch->>'from'), path);
    when 'copy' then rv := @extschema@.jsonb_patch_copy(target, @extschema@.jsonb_patch_split_path(patch->>'from'), path);
    when 'test' then rv := @extschema@.jsonb_patch_test(target, path, patch->'value');
  end case;

  return rv;
end $$
language plpgsql
immutable;

create or replace function jsonb_coalesce(variadic jsonb[])
returns jsonb
as $$
  select value
  from unnest($1) as value
  where value is not null and jsonb_typeof(value) != 'null'
  limit 1
$$
language sql
immutable;

create or replace function jsonb_patch_agg(target jsonb, patch jsonb, base jsonb)
returns jsonb
as $$ select @extschema@.jsonb_patch_apply(@extschema@.jsonb_coalesce(target, base), patch) $$
language sql
immutable;

create or replace aggregate jsonb_patch_agg(jsonb, jsonb) (
  sfunc = @extschema@.jsonb_patch_agg,
  stype = jsonb,
  initcond = null
);

create or replace function jsonb_patch(target jsonb, patches jsonb)
returns jsonb
as $$ select jsonb_patch_agg(value, target) from jsonb_array_elements(patches) $$
language sql
immutable;
