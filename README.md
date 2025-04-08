# PostgreSQL implementation of JSON Patch

(tested on Postgres 14+)

[https://datatracker.ietf.org/doc/html/rfc6902]

```sql
select jsonb_patch(
  '{"foo":{"bar":"baz","waldo":"fred"},"qux":{"corge":"grault"}}',
  '[{"op":"move","from":"/foo/waldo","path":"/qux/thud"}]'
);
                             jsonb_patch                             
---------------------------------------------------------------------
 {"foo": {"bar": "baz"}, "qux": {"thud": "fred", "corge": "grault"}}
(1 row)
```

I have not yet written tests for A.11-A.15 from the RFC.
See [./test.sql](./test.sql) for more examples.
