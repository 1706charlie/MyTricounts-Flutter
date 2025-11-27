/**************************************************************/
/*                                                            */
/* CLEAN                                                      */
/*                                                            */
/**************************************************************/

set search_path to public, auth;

/*
 Supprime tout ce qui a été créé précédemment
 */

-- permet de revenir au rôle de la connexion, au cas où on aurait pris un autre rôle
reset role;

-- supprime les schémas et tout ce qu'ils contiennent
drop schema if exists public cascade;
drop schema if exists auth cascade;

-- supprime les rôles
drop role if exists anon, authenticator, authenticated;

/*
 Crée les rôles
 */

create role authenticator noinherit login password 'mysecretpassword';
create role anon nologin;
create role authenticated nologin;

grant anon to authenticator;
grant authenticated to authenticator;

grant anon to authenticated;

/*
 Crée le schéma public
 */

create schema public;

-- par défaut tout est privé
-- (le 'public' qui est dans le from signifie "tous les rôles présents et futurs")
revoke all on schema public from public;

-- par défault les fonctions ne sont pas accessibles
alter default privileges revoke all on functions from public;

-- donne accès à certains rôles
grant usage on schema public to anon, authenticated;

/**************************************************************/
/*                                                            */
/* POSTGREST_RELOAD_CACHE                                     */
/*                                                            */
/**************************************************************/

/*
 Crée un trigger qui fait en sorte que la cache de PostgREST soit rechargée à chaque commande ddl
 (voir https://postgrest.org/en/stable/references/schema_cache.html#automatic-schema-cache-reloading)
 */

create or replace function pgrst_watch() returns event_trigger
    language plpgsql
as
$$
begin
    notify pgrst, 'reload schema';
    raise notice 'pgrst_watch: reload schema';
end;
$$;

-- fait en sorte que le trigger se déclenche après chaque commande ddl
drop event trigger if exists pgrst_watch;
create event trigger pgrst_watch
    on ddl_command_end
execute procedure pgrst_watch();

-- test : force un reload
notify pgrst, 'reload schema';

/**************************************************************/
/*                                                            */
/* JWT                                                        */
/*                                                            */
/**************************************************************/

/*
 Met en place la sécurité à base de jetons JWT
 */

drop schema if exists auth cascade;

create schema auth;

grant usage on schema auth to anon, authenticated;

set search_path to auth;
-- par défault les fonctions ne sont pas accessibles
alter default privileges revoke all on functions from public;
set search_path to public;

create extension if not exists pgcrypto with schema auth;

create type auth.jwt_token as
(
    token text
);

/*
 Code copié depuis l'extension pgjwt (voir https://github.com/michelp/pgjwt).
 On n'utilise pas l'extension elle-même, car elle n'est généralement pas disponible dans les VM hostées.
 */

create or replace function auth.url_encode(data bytea) returns text
    language sql as
$$
select translate(encode(data, 'base64'), E'+/=\n', '-_');
$$ immutable;


create or replace function auth.url_decode(data text) returns bytea
    language sql as
$$
with t as (select translate(data, '-_', '+/') as trans),
     rem as (select length(t.trans) % 4 as remainder from t) -- compute padding size
select decode(
               t.trans ||
               case
                   when rem.remainder > 0
                       then repeat('=', (4 - rem.remainder))
                   else '' end,
               'base64')
from t,
     rem;
$$ immutable;


create or replace function auth.algorithm_sign(signables text, secret text, algorithm text)
    returns text
    language sql as
$$
with alg as (select case
                        when algorithm = 'HS256' then 'sha256'
                        when algorithm = 'HS384' then 'sha384'
                        when algorithm = 'HS512' then 'sha512'
                        else '' end as id) -- hmac throws error
select auth.url_encode(auth.hmac(signables, secret, alg.id))
from alg;
$$ immutable;


create or replace function auth.sign(payload json, secret text, algorithm text default 'HS256')
    returns text
    language sql as
$$
with header as (select auth.url_encode(convert_to('{"alg":"' || algorithm || '","typ":"JWT"}', 'utf8')) as data),
     payload as (select auth.url_encode(convert_to(payload::text, 'utf8')) as data),
     signables as (select header.data || '.' || payload.data as data
                   from header,
                        payload)
select signables.data || '.' ||
       auth.algorithm_sign(signables.data, secret, algorithm)
from signables;
$$ immutable;


create or replace function auth.try_cast_double(inp text)
    returns double precision as
$$
begin
    begin
        return inp::double precision;
    exception
        when others then return null;
    end;
end;
$$ language plpgsql immutable;


create or replace function auth.verify(token text, secret text, algorithm text default 'HS256')
    returns table
            (
                header  json,
                payload json,
                valid   boolean
            )
    language sql
as
$$
select jwt.header                                  as header,
       jwt.payload                                 as payload,
       jwt.signature_ok and tstzrange(
                                    to_timestamp(auth.try_cast_double(jwt.payload ->> 'nbf')),
                                    to_timestamp(auth.try_cast_double(jwt.payload ->> 'exp'))
                            ) @> current_timestamp as valid
from (select convert_from(auth.url_decode(r[1]), 'utf8')::json                  as header,
             convert_from(auth.url_decode(r[2]), 'utf8')::json                  as payload,
             r[3] = auth.algorithm_sign(r[1] || '.' || r[2], secret, algorithm) as signature_ok
      from regexp_split_to_array(token, '\.') r) jwt
$$ immutable;

/**************************************************************/
/*                                                            */
/* HELLO WORLD                                                */
/*                                                            */
/**************************************************************/

create or replace function hello_world() returns text as
$$
    select 'Hello, world!';
$$ language sql;

grant execute on function hello_world() to anon;
