{
  postgresql,
  lib,
}:
postgresql.stdenv.mkDerivation {
  pname = "pg_jsonpatch";
  version = "1.0.0";
  src = ./.;
  dontBuild = true;
  installPhase = ''
    mkdir -p $out/share/postgresql/extension
    cp pg_jsonpatch* $out/share/postgresql/extension
  '';
  meta = {
    description = "PostgreSQL implementation of JSON Patch";
    license = lib.licenses.mit;
    inherit (postgresql.meta) platforms;
  };
  passthru = {inherit postgresql;};
}
