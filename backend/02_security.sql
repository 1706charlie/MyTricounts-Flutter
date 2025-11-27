set search_path to public, auth;

/**************************************************************
  Role basic_user
 **************************************************************/

drop role if exists basic_user, admin;
create role basic_user nologin;
create role admin nologin;
grant basic_user, admin to authenticator;
grant authenticated to basic_user;
grant authenticated to admin;

/**************************************************************
  Table users
 **************************************************************/
drop type if exists role_type cascade;

create type role_type as enum ('basic_user', 'admin');

drop table if exists users cascade;


/**************************************************************
 Fonction qui permet de vérifier la validité du format de l'iban
 **************************************************************/

create or replace function is_iban_valid(iban text) returns boolean as
$$
begin
    -- Si l'IBAN est nul ou vide, on considère qu'il est valide (champ optionnel)
    if iban is null or trim(iban) = '' then
        return true;
    end if;

    -- Vérification du format de l'IBAN
    if iban ~ '^[A-Z]{2}[0-9]{2} [0-9]{4} [0-9]{4} [0-9]{4}$' then
        return true;
    else
        return false;
    end if;
end
$$ language plpgsql security definer;

grant execute on function is_iban_valid to anon;



create table users
(
    id        serial primary key,
    email     varchar(256) not null unique,
    password  varchar(512) not null,
    full_name varchar(256) not null unique
        check (length(trim(full_name)) >= 3),
    iban      varchar(256) null
        check (is_iban_valid(iban)),
    role      role_type    not null default 'basic_user'
);

insert into users (id, email, password, full_name, role, iban)
values (1, 'boverhaegen@epfc.eu', '', 'Boris', 'basic_user', null),
       (2, 'bepenelle@epfc.eu', '', 'Benoît', 'basic_user', null),
       (3, 'xapigeolet@epfc.eu', '', 'Xavier', 'basic_user', null),
       (4, 'mamichel@epfc.eu', '', 'Marc', 'basic_user', 'BE12 1234 1234 1234'),
       (5, 'gedielman@epfc.eu', '', 'Geoffrey', 'basic_user', 'BE45 4567 4567 4567'),
       (9, 'admin@epfc.eu', '', 'Admin', 'admin', null);

-- met à jour la séquence pour qu'elle commence à 10
select setval('users_id_seq', (select max(id)
                               from users));

/**************************************************************
 Trigger pour encrypter automatiquement le mot de passe
 **************************************************************/

create or replace function auth.encrypt_pass() returns trigger as
$$
begin
    if tg_op = 'INSERT' or new.password <> old.password then
        new.password = auth.crypt(new.password, auth.gen_salt('bf'));
    end if;
    return new;
end
$$ language plpgsql;

drop trigger if exists encrypt_pass on users;
create trigger encrypt_pass
    before insert or update
    on users
    for each row
execute procedure auth.encrypt_pass();

-- met à jour les mots de passe pour forcer le hashage
-- noinspection SqlWithoutWhere
update users
set password = 'Password1,';

/**************************************************************
 Fonction qui permet de faire le login et retourne un jeton JWT
 **************************************************************/

create or replace function
    login(email text, password text) returns auth.jwt_token as
$$
declare
    role   name;
    user_id integer;
    result auth.jwt_token;
begin
    -- check email and password
    if not exists(select *
                  from users
                  where users.email = login.email
                    and users.password = auth.crypt(login.password, users.password)) then
        raise invalid_password using message = 'invalid user or password';
    end if;

    select u.role, u.id
    from   users u
    where  u.email = login.email
    into   role, user_id;

    select auth.sign(row_to_json(r), '94VEF6BGSV4MHACYQYWYZZXILQR7412Z') as token
    from (select role                                              as role,
                 email                                             as sub,
                 user_id                                           as user_id,
                 -- valid for 24 hours
                 extract(epoch from now())::integer + 24 * 60 * 60 as exp) r
    into result;
    return result;
end;
$$ language plpgsql security definer;

grant execute on function login to anon;


/**************************************************************
 Fonction qui vérifie la longueur du full_name
 **************************************************************/

create or replace function check_full_name_length(full_name text) returns boolean as
$$
begin
    if length(trim(full_name)) < 3 then -- au moins 3 caractères
        return false;
    end if;

    return true;
end
$$ language plpgsql security definer;

grant execute on function check_full_name_length to anon;

/**************************************************************
      ENDPOINT : vérifier si un full_name est disponible
 **************************************************************/
-- user_id = 0 pour un nouvel utilisateur
-- le user_id pour un changement de full_name
create or replace function check_full_name_available(full_name text, user_id int) returns boolean as
$$
begin
    if user_id = 0 then
        -- nouvel utilisateur : l'email ne doit pas exister du tout
        return not exists (
            select 1
            from users u
            where lower(trim(u.full_name)) = lower(trim(check_full_name_available.full_name))
        );
    else
        -- mise à jour : on exclut l'utilisateur courant
        return not exists (
            select 1
            from users u
            where lower(trim(u.full_name)) = lower(trim(check_full_name_available.full_name))
              and u.id <> check_full_name_available.user_id
        );
    end if;
end
$$ language plpgsql security definer;

grant execute on function check_full_name_available to anon;

/**************************************************************
         ENDPOINT : vérifier si un email est disponible
 **************************************************************/
-- user_id = 0 pour un nouvel utilisateur
-- le user_id pour un changement d'email
create or replace function check_email_available(email text, user_id int)
    returns boolean as
$$
begin
    if user_id = 0 then
        -- nouvel utilisateur : l'email ne doit pas exister du tout
        return not exists (
            select 1
            from users u
            where lower(trim(u.email)) = lower(trim(check_email_available.email))
        );
    else
        -- mise à jour : on exclut l'utilisateur courant
        return not exists (
            select 1
            from users u
            where lower(trim(u.email)) = lower(trim(check_email_available.email))
              and u.id <> check_email_available.user_id
        );
    end if;
end;
$$ language plpgsql security definer;

grant execute on function check_email_available to anon;


/**************************************************************
 Fonction qui permet de vérifier la validité du format de l'email
 **************************************************************/

create or replace function is_email_valid(email text) returns boolean as
$$
begin
    -- Vérification si l'email est NULL ou vide
    if email is null or trim(email) = '' then
        return false;
    end if;

    -- Vérification du format de l'email
    if not (email ~ '^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$') then
        return false;
    end if;

    return true;
end
$$ language plpgsql security definer;

grant execute on function is_email_valid to anon;


/**************************************************************
 Fonction qui permet de vérifier la validité du format du mot de passe
 **************************************************************/

create or replace function is_password_valid(password text) returns boolean as
$$
begin
    -- Vérification de la longueur minimale
    if length(password) < 8 then
        return false;
    end if;

    -- Vérification de la présence d'une majuscule
    if not (password ~ '[A-Z]') then
        return false;
    end if;

    -- Vérification de la présence d'un chiffre
    if not (password ~ '\d') then
        return false;
    end if;

    -- Vérification de la présence d'un caractère non alphanumérique
    if not (password ~ '\W') then
        return false;
    end if;

    -- Si toutes les vérifications sont passées, le mot de passe est valide
    return true;
end
$$ language plpgsql security definer;

grant execute on function is_password_valid to anon;

/**************************************************************
 Fonction signup
 **************************************************************/

create or replace function signup(email text, password text, full_name text, iban text default null) returns void
as
$$
begin
    -- Vérification de la disponibilité et de la validité de l'email
    if not check_email_available(email, 0) then
        raise exception 'Email ''%'' already exists', email;
    end if;
    if not is_email_valid(email) then
        raise exception 'Email ''%'' is not valid', email;
    end if;

    -- Vérification de la longueur du nom et de sa disponibilité
    if not check_full_name_length(full_name) then
        raise exception 'Full name must contain at least 3 characters';
    end if;
    if not check_full_name_available(full_name, 0) then
        raise exception 'Full name ''%'' already exists', full_name;
    end if;

    -- Vérification de la validité du mot de passe
    if not is_password_valid(password) then
        raise exception 'Password ''%'' is not valid', password;
    end if;

    -- Vérification de la validité de l'IBAN (s'il est renseigné)
    if iban is not null and not is_iban_valid(iban) then
        raise exception 'IBAN ''%'' is not valid', iban;
    end if;

    -- Insertion de l'utilisateur dans la table
    insert into users (email, password, full_name, iban)
    values (signup.email, signup.password, signup.full_name, signup.iban);
end
$$ language plpgsql security definer;

grant execute on function signup to anon;

/**************************************************************
 Fonctions utilitaires vàv de la sécurité
 **************************************************************/

/*
 Retourne l'email de l'utilisateur connecté via JWT
 */

create or replace function auth.email()
    returns varchar as
$$
begin
    return current_setting('request.jwt.claims', true)::json ->> 'sub';
end;
$$ language plpgsql;

/*
 Retourne le rôle de l'utilisateur connecté via JWT
 */

create or replace function auth.role()
    returns varchar as
$$
begin
    return current_setting('request.jwt.claims', true)::json ->> 'role';
end;
$$ language plpgsql;

/*
 Retourne l'id de l'utilisateur connecté via JWT
 */

create or replace function auth.id()
    returns int as
$$
begin
    return current_setting('request.jwt.claims', true)::json ->> 'user_id';
end;
$$ language plpgsql;


/*
 Vérifie si l'utilisateur est connecté
 */

create or replace function auth.check_logged()
    returns void as
$$
begin
    if auth.email() is null then
        raise exception 'You must be logged';
    end if;
end
$$ language plpgsql;

/*
 Vérifie si l'utilisateur connecté est un admin
 */

create or replace function auth.is_admin()
    returns bool as
$$
begin
    return auth.role() is not null and auth.role() = 'admin';
end
$$ language plpgsql;

/*
 Vérifie si un admin est connecté
 */

create or replace function auth.check_admin_logged()
    returns void as
$$
begin
    if not auth.is_admin() then
        raise exception 'You must be logged with an admin role';
    end if;
end
$$ language plpgsql;

/*
 Lors des tests, permet de simuler une connexion anonyme
 */

create or replace function auth.login_anonymously_for_test() returns void as
$$
begin
    execute 'set session role to anon';
    -- true = pour la transaction, false = pour la session
    perform set_config('request.jwt.claims', '{"role":"anon"}', false);
end
$$ language plpgsql;

/*
 Lors des tests, permet de simuler une connexion avec un utilisateur donné
 */

create or replace function auth.login_for_test(email text) returns void as
$$
declare
    role text;
    user_id int;
begin
    if not exists(select 1 from users u where u.email = login_for_test.email) then
        raise exception 'User ''%'' does not exist', email;
    end if;

    select m.role, m.id
    from users m
    where m.email = login_for_test.email
    into role, user_id;

    execute 'set session role to ' || role;
    -- true = pour la transaction, false = pour la session
    perform set_config('request.jwt.claims',
                       concat('{"role": "', role, '", "sub": "', email, '", "user_id": ', user_id, '}'),
                       false);
end
$$ language plpgsql;

/*
 Permet de revenir à son rôle normal (après un login_for_test)
 */

create or replace function auth.logout_for_test() returns void as
$$
begin
    perform set_config('request.jwt.claims', '{}', false);
    reset role;
end;
$$ language plpgsql;


grant execute on function auth.login_anonymously_for_test() to anon;
grant execute on function auth.login_for_test(text) to anon;
grant execute on function auth.logout_for_test() to anon;
grant execute on function auth.email() to anon;
grant execute on function auth.id() to anon;
grant execute on function auth.role() to anon;

/**************************************************************
  Fonction de test pour un utilisateur connecté
 **************************************************************/

create or replace function get_email() returns varchar as
$$
begin
    return auth.email();
end
$$ language plpgsql security definer;

grant execute on function get_email to authenticated;

/**************************************************************
  TESTS
 **************************************************************/

select login('bepenelle@epfc.eu', 'Password1,'); -- OK
-- select login('xxx', 'xxx'); -- KO: user n'existe pas
-- select login('bepenelle@epfc.eu', 'xxx'); -- KO: mauvais mot de passe

select auth.login_anonymously_for_test();
select current_user, auth.email(), auth.role(), auth.id();
select auth.logout_for_test();

select auth.login_for_test('bepenelle@epfc.eu');
select current_user, auth.email(), auth.role(), auth.id();
select auth.logout_for_test();

select auth.login_for_test('admin@epfc.eu');
select current_user, auth.email(), auth.role(), auth.id();
select auth.logout_for_test();
