\echo Use "CREATE EXTENSION pg_jsonpatch" to load this file. \quit

create or replace function jsonb_patch_add(target jsonb, path text[], value jsonb)
returns jsonb
as $$
declare
  target_type text := jsonb_typeof(jsonb_extract_path(target, variadic trim_array(path, 1)));
begin
  case
    when target_type = 'object'
      then return jsonb_set(target, path, value, true);
    when target_type = 'array' and path[array_length(path, 1)] = '-'
      then return jsonb_insert(target, trim_array(path, 1) || array['-1'], value, true);
    when target_type = 'array'
      then return jsonb_insert(target, path, value);
    else return null;
  end case;
end $$
language plpgsql
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
as $$ select @extschema@.jsonb_patch_add(@extschema@.jsonb_patch_remove(target, _from), path, jsonb_extract_path(target, variadic _from)) $$
language sql
immutable;

create or replace function jsonb_patch_copy(target jsonb, _from text[], path text[])
returns jsonb
as $$ select @extschema@.jsonb_patch_add(target, path, jsonb_extract_path(target, variadic _from)) $$
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

-- Apply a single patch operation to an object.
create or replace function jsonb_patch_apply(target jsonb, patch jsonb)
returns jsonb
as $$
declare
  path text[] := @extschema@.jsonb_patch_split_path(patch->>'path');
begin
  case patch->>'op'
    when 'add' then return @extschema@.jsonb_patch_add(target, path, patch->'value');
    when 'remove' then return @extschema@.jsonb_patch_remove(target, path);
    when 'replace' then return @extschema@.jsonb_patch_replace(target, path, patch->'value');
    when 'move' then return @extschema@.jsonb_patch_move(target, @extschema@.jsonb_patch_split_path(patch->>'from'), path);
    when 'copy' then return @extschema@.jsonb_patch_copy(target, @extschema@.jsonb_patch_split_path(patch->>'from'), path);
    when 'test' then return @extschema@.jsonb_patch_test(target, path, patch->'value');
    else return null;
  end case;
end $$
language plpgsql
immutable;

create or replace function jsonb_patch(target jsonb, patches jsonb)
returns jsonb
as $$
declare
  patch jsonb;
  result jsonb := target;
begin
  for patch in select * from jsonb_array_elements(patches) loop
    result := @extschema@.jsonb_patch_apply(result, patch);
    if result is null then
      return null;
    end if;
  end loop;
  return result;
end $$
language plpgsql
immutable;
