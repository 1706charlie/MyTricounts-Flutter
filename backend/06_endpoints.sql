set search_path = public, auth;

/**************************************************************/
/*                    reset database                          */
/**************************************************************/

create or replace function reset_database()
    returns void as
$$
begin
    -- Restart les tables dans le bon ordre
    truncate table split          restart identity cascade;
    truncate table expense        restart identity cascade;
    truncate table participation  restart identity cascade;
    truncate table tricount       restart identity cascade;
    truncate table users          restart identity cascade;

    -- user
    insert into users (id, email, password, full_name, role, iban)
    values (1, 'boverhaegen@epfc.eu', '', 'Boris', 'basic_user', null),
           (2, 'bepenelle@epfc.eu', '', 'Benoît', 'basic_user', null),
           (3, 'xapigeolet@epfc.eu', '', 'Xavier', 'basic_user', null),
           (4, 'mamichel@epfc.eu', '', 'Marc', 'basic_user', 'BE12 1234 1234 1234'),
           (5, 'gedielman@epfc.eu', '', 'Geoffrey', 'basic_user', 'BE45 4567 4567 4567'),
           (9, 'admin@epfc.eu', '', 'Admin', 'admin', null);

    perform setval('users_id_seq', (select max(id)
                                   from users));

    update users -- met à jour les mots de passe pour forcer le hashage
    set password = 'Password1,';

    -- tricount
    INSERT INTO tricount (id, title, description, creator_id, created_at) VALUES
      (4, 'Vacances',        'A la mer du nord',          1, '2024-10-10 19:31:09'),
      (2, 'Resto badminton', NULL,                       1, '2024-10-10 19:25:10'),
      (1, 'Gers 2022',       NULL,               1, '2024-10-10 18:42:24');

    perform setval('tricount_id_seq', (select max(id)
                                      from tricount));

    -- participation (on n'ajoute pas le créateur, le trigger s'en chargera lui même)
    INSERT INTO participation (tricount_id, user_id) VALUES
     (4, 2), (4, 4), (4, 3),(2, 2); -- on n'ajoute pas le créateur, le trigger s'en charge

    -- expense
    INSERT INTO expense
    (id, title, amount, initiator_id, operation_date, tricount_id, created_at) VALUES
       (6, 'Loterie',               35.00, 1, '2024-10-26', 4, '2024-10-26 10:02:24'),
       (5, 'Boucherie',             25.50, 2, '2024-10-26', 4, '2024-10-26 09:59:56'),
       (4, 'Apéros',                31.897456217, 1, '2024-10-13', 4, '2024-10-13 23:51:20'),
       (3, 'Grosses courses LIDL', 212.47, 3, '2024-10-13', 4, '2024-10-13 21:23:49'),
       (2, 'Plein essence',         75.00, 1, '2024-10-13', 4, '2024-10-13 20:10:41'),
       (1, 'Colruyt',              100.00, 2, '2024-10-13', 4, '2024-10-13 19:09:18');

    perform setval('expense_id_seq', (select max(id)
                                      from expense));

    --split
    INSERT INTO split (expense_id,user_id,weight) VALUES (6,1,1),(6,3,1);
    INSERT INTO split VALUES (5,1,2),(5,2,1),(5,3,1);
    INSERT INTO split VALUES (4,1,1),(4,2,2),(4,3,3);
    INSERT INTO split VALUES (3,1,2),(3,2,1),(3,3,1);
    INSERT INTO split VALUES (2,1,1),(2,2,1);
    INSERT INTO split VALUES (1,1,1),(1,2,1);
end;
$$ language plpgsql security definer;

grant execute on function reset_database to anon;


/**************************************************************/
/*                   get_my_tricounts                       */
/**************************************************************/

drop type if exists user_public cascade;
create type user_public as (
                               id         int,
                               email      text,
                               full_name  text,
                               iban       text,
                               role       role_type
                           );


drop type if exists repartition cascade;
create type repartition as (
                               "user" int,
                               weight int
                           );


drop type if exists expense_with_repartitions cascade;
create type expense_with_repartitions as (
                                             id             int,
                                             title          text,
                                             amount         numeric(10,2),
                                             operation_date date,
                                             initiator      int,
                                             created_at     timestamp,
                                             repartitions   repartition[]
                                         );


drop type if exists tricount_with_details cascade;
create type tricount_with_details as (
                                         id           int,
                                         title        text,
                                         description  text,
                                         created_at   timestamp,
                                         delete_at    timestamp,
                                         creator      int,
                                         participants user_public[],
                                         operations   expense_with_repartitions[]
                                     );


create or replace function get_my_tricounts()
    returns setof tricount_with_details as
$$
declare
    me          int       := auth.id();
    am_i_admin  boolean   := auth.is_admin();
begin
    perform auth.check_logged();

    return query
        select
            t.id,
            t.title::text,      -- cast
            t.description::text,
            t.created_at,
            t.delete_at,
            t.creator_id,

            /* participants ---------------------------------------------------- */
            array(
                    select row(
                               u.id,
                               u.email::text,
                               u.full_name::text,
                               u.iban::text,
                               u.role
                    )::user_public
                    from (
                             select p.user_id
                             from participation p
                             where p.tricount_id = t.id
                             union
                             select t.creator_id
                         ) uid
                    join users u on u.id = uid.user_id
                    order by u.full_name
            )                                                 as participants,

            /* operations ------------------------------------------------------ */
            array(
                    select row(
                               e.id,
                               e.title::text,
                               e.amount,
                               e.operation_date,
                               e.initiator_id,
                               e.created_at,
                               array(
                                       select row(s.user_id, s.weight)::repartition
                                       from split s
                                       where s.expense_id = e.id
                               )::repartition[]
                    )::expense_with_repartitions
                    from expense e
                    where e.tricount_id = t.id
                    order by e.id desc
            )                                                 as operations

        from tricount t
        where
            am_i_admin                          -- je suis admin
            or t.creator_id = me                -- je suis createur
            or exists (                         -- je suis participant
                select 1
                from participation p
                where p.tricount_id = t.id
                    and p.user_id = me )
        order by created_at desc;
end;
$$ language plpgsql security definer;

grant execute on function get_my_tricounts() to authenticated;


/**************************************************************/
/*                   get_user_data                            */
/**************************************************************/
drop function if exists get_user_data() cascade;
create or replace function get_user_data()
    returns user_public as                  -- un seul objet
$$
declare
    me   int         := auth.id();          -- id de l’utilisateur connecté
    res  user_public;                       -- variable resultat
begin
    perform auth.check_logged();

    select
        u.id,
        u.email::text,
        u.full_name::text,
        u.iban::text,
        u.role
    into res
    from users u
    where u.id = me;

    -- on renvoie
    return res;
end;
$$ language plpgsql security definer;

grant execute on function get_user_data() to authenticated;


/**************************************************************
 *                   get_all_users                            *
 **************************************************************/

drop function if exists get_all_users() cascade;
create or replace function get_all_users()
    returns setof user_public as
$$
begin
    perform auth.check_logged();

    return query
        select
            u.id,
            u.email::text,
            u.full_name::text,
            u.iban::text,
            u.role
        from users u
        order by u.full_name;
end;
$$ language plpgsql security definer;

grant execute on function get_all_users() to authenticated;


/**************************************************************
 *             check_tricount_title_available                  *
 **************************************************************/
-- tricount_id = 0 pour une création de tricount
-- tricount_id pour une édition de tricount
create or replace function check_tricount_title_available(title text, tricount_id int)
    returns boolean as
$$
declare
    me             int   := auth.id();
    p_title        text  := title;          -- p comme paramètre
    p_tricount_id  int   := tricount_id;
begin
    -- cas création
    if p_tricount_id = 0 then
        return not exists (
            select 1
            from   tricount t
            where  lower(trim(t.title)) = lower(trim(p_title))
              and (
                t.creator_id = me
                    or exists (
                    select 1
                    from participation p
                    where p.tricount_id = t.id
                      and p.user_id = me ) )
        );

    -- cas édition
    else
        return not exists (
            select 1
            from tricount t
            where t.id <> p_tricount_id
              and lower(trim(t.title)) = lower(trim(p_title))
              and (
                -- Le créateur du tricount trouvé est participant du tricount qu’on modifie
                t.creator_id in (
                    select creator_id
                    from tricount
                    where id = p_tricount_id
                    union
                    select user_id
                    from participation p
                    where p.tricount_id = p_tricount_id
                )
                    -- OU un des participants du tricount trouvé est aussi participant du tricount courant
                    or exists (
                    select 1
                    from participation p
                    where p.tricount_id = t.id
                      and p.user_id in (
                        select creator_id
                        from tricount
                        where id = p_tricount_id
                        union
                        select user_id
                        from participation p
                        where p.tricount_id = p_tricount_id ) )
              )
        );
    end if;
end;
$$ language plpgsql security definer;

grant execute on function check_tricount_title_available to anon;


/**************************************************************
 *                  get_tricount_balance                      *
 **************************************************************/

drop type if exists user_balance cascade;
create type user_balance as (
    "user"  int,
    paid    numeric(12,2),
    due     numeric(12,2),
    balance numeric(12,2)
);
create or replace function get_tricount_balance(tricount_id int)
returns setof user_balance as
$$
begin
    perform auth.check_logged();
    
    if not auth.is_admin() and not exists (
        select 1
        from tricount t 
        where t.id = get_tricount_balance.tricount_id
            and (t.creator_id = auth.id()
            or exists (
                select 1
                from participation p 
                where p.tricount_id = t.id
                and p.user_id = auth.id()
            ))
    ) then
        raise exception 'access denied';
    end if;
    return query
    select
        user_id,
        total_paid::numeric(12,2),
        total_owed::numeric(12,2),
        balance::numeric(12,2)
    from compute_balance(tricount_id);
end;
$$ language plpgsql security definer;

grant execute on function get_tricount_balance(int) to authenticated;


/**************************************************************
 *                      save_tricount                         *
 **************************************************************/
create or replace function save_tricount(
    id           int,
    title        text,
    description  text,
    participants int[]
)
    returns tricount_with_details as
$$
declare
    -- pour éviter les conflits de nom. "p" comme paramètre
    p_id               int   := id;
    p_title            text  := title;
    p_description      text  := description;
    p_participants_id  int[] := participants;

    new_id      int;
    me_id       int := auth.id();
    creator_id  int;
    me_is_admin boolean := auth.is_admin();
begin
    perform auth.check_logged();

    -- vérifier que p_participants contient des participants existants
    if exists (
        select 1
        from unnest(p_participants_id) as u     -- unnest permet de transformer un tableau en lignes
        where u not in (select u.id
                        from users u)
    ) then
        raise exception 'Participant not found';
    end if;

    /* ---------- création ---------- */
    if p_id = 0 then
        insert into tricount(title, description, creator_id)
        values (p_title, p_description, me_id)
        returning tricount.id into new_id;

        -- ajoute les nouveaux participants
        insert into participation(tricount_id, user_id)
        select new_id, u
        from unnest(p_participants_id) as u
        where u <> me_id; -- on n'ajoute pas le créateur (le trigger s'en charge)


    /* ---------- mise à jour ---------- */
    else
        -- on récupère le créateur du tricount
        select t.creator_id into creator_id
        from   tricount t
        where  t.id = p_id;

        -- il faut que le créateur soit présent dans la liste des participants
        if not exists(
            select 1
            from unnest(p_participants_id) as u
            where u = creator_id
        ) then
            raise exception 'You cannot remove the participation of the owner of a tricount';
        end if;


        if not me_is_admin then
            --  vérifier que l’utilisateur courant est bien participant à ce tricount
            if not exists (
                select 1
                from participation p
                where p.tricount_id = p_id
                  and p.user_id     = me_id
            ) then
                raise exception 'Access denied';
            end if;
        end if;

        update tricount
        set title          = p_title,
            description    = p_description
        where tricount.id = p_id;

        -- supprimer uniquement les participants retirés
        delete
        from participation
        where tricount_id = p_id
          and user_id <> creator_id                       -- on ne supprime pas le créateur
          and user_id <> all (p_participants_id);         -- on ne supprime pas les participants qui sont dans la liste

        -- ajouter les participants manquants
        insert into participation(tricount_id, user_id)
        select p_id, u
        from unnest(p_participants_id) u
        where u <> creator_id                             -- on n'ajoute pas le créateur
          and not exists (                                -- on ajoute uniquement les nouveaux participants
            select 1
            from participation p
            where p.tricount_id = p_id
              and p.user_id = u );

        new_id := p_id;
    end if;

    -- retourne l'objet complet
    return (
        select row(t.*)::tricount_with_details
        from get_my_tricounts() as t
        where t.id = new_id
    );
end;
$$ language plpgsql security definer;

grant execute on function save_tricount(int, text, text, int[]) to authenticated;


/**************************************************************
 *                      delete_tricount                       *
 **************************************************************/
create or replace function delete_tricount(tricount_id int)
returns void as
$$
declare
    creator_id     int;
    p_tricount_id  int := tricount_id;
begin
    perform auth.check_logged();

    select t.creator_id into creator_id
    from tricount t
    where t.id = p_tricount_id;

    if not found then
        raise exception 'tricount not found';
    end if;

    if creator_id <> auth.id() and not auth.is_admin() then
        raise exception 'access denied';
    end if;

--     -- a) les dépenses (et les splits qui sont associés)
--     delete from expense e
--     where e.tricount_id = p_tricount_id;
--
--     -- b) les participants (sauf le créateur : évite l’erreur du trigger)
--     delete from participation p
--     where p.tricount_id = p_tricount_id
--       and p.user_id <> creator_id;
--
--     -- c) le tricount lui-même (les dernières participations s’en iront grâce au ON DELETE CASCADE)
--     delete from tricount
--     where id = p_tricount_id;

    update tricount
    set delete_at = current_timestamp
    where id = p_tricount_id;


end;
$$ language plpgsql security definer;

grant execute on function delete_tricount(int) to authenticated;


/**************************************************************
 *                      restore_tricount                       *
 **************************************************************/
create or replace function restore_tricount(tricount_id int)
    returns void as
$$
declare
    creator_id     int;
    p_tricount_id  int := tricount_id;
begin
    perform auth.check_logged();

    select t.creator_id into creator_id
    from tricount t
    where t.id = p_tricount_id;

    if not found then
        raise exception 'tricount not found';
    end if;

    if creator_id <> auth.id() and not auth.is_admin() then
        raise exception 'access denied';
    end if;

    --     -- a) les dépenses (et les splits qui sont associés)
--     delete from expense e
--     where e.tricount_id = p_tricount_id;
--
--     -- b) les participants (sauf le créateur : évite l’erreur du trigger)
--     delete from participation p
--     where p.tricount_id = p_tricount_id
--       and p.user_id <> creator_id;
--
--     -- c) le tricount lui-même (les dernières participations s’en iront grâce au ON DELETE CASCADE)
--     delete from tricount
--     where id = p_tricount_id;

    update tricount
    set delete_at = null
    where id = p_tricount_id;


end;
$$ language plpgsql security definer;

grant execute on function restore_tricount(int) to authenticated;

/**************************************************************
 *                      save_operation                        *
 **************************************************************/
create or replace function save_operation(
    id              int,
    title           text,
    amount          numeric(10, 2),
    operation_date  date,
    tricount_id     int,
    initiator       int,
    repartitions    json
)
    returns json as
$$
declare
    new_id           int;
    me_is_admin      boolean := auth.is_admin();
begin
    perform auth.check_logged();

    if not me_is_admin then
        if not (
            --  je suis le créateur
            exists (
                select 1
                from tricount t
                where t.id = save_operation.tricount_id
                  and creator_id = auth.id()
            )
            -- je suis participant
            or exists (
                select 1
                from participation p
                where p.tricount_id = save_operation.tricount_id
                  and user_id     = auth.id()
            )
        ) then raise exception 'access denied';
        end if;
    end if;

    if not exists (
        select 1
        from participation p
        where p.tricount_id = save_operation.tricount_id
          and p.user_id     = save_operation.initiator
    ) then
        raise exception 'initiator must be participant';
    end if;


    if not exists (
        select 1
        from json_array_elements(repartitions) r
        where (r->>'weight')::int > 0
    ) then
        raise exception 'An operation must have at least one repartition';
    end if;


    -- création d'opération
    if save_operation.id = 0 then
        insert into expense (tricount_id, title, amount, operation_date, initiator_id)
        values (save_operation.tricount_id, title, amount, operation_date, initiator)
        returning expense.id into new_id;

    -- édition d'opération
    else
        if not exists (
            select 1
            from expense e
            where e.id          = save_operation.id
              and e.tricount_id = save_operation.tricount_id
        ) then
            raise exception 'operation not found';
        end if;

        update expense e
        set title         = save_operation.title,
            amount        = save_operation.amount,
            operation_date= save_operation.operation_date,
            initiator_id  = save_operation.initiator
        where e.id = save_operation.id
        returning e.id into new_id;

        -- on supprime les splits de l'opération
        delete from split where expense_id = new_id;
    end if;

    /* insertion des splits -------------------------------------------- */
    insert into split (expense_id, user_id, weight)
    select new_id,
           (r->>'user')::int,
           (r->>'weight')::int
    from json_array_elements(repartitions) r
    where (r->>'weight')::int > 0;

    /* résultat --------------------------------------------------------- */
    return json_build_object(
            'id',             new_id,
            'title',          title,
            'amount',         amount,
            'operation_date', operation_date,
            'initiator',      initiator,
            'created_at',     (select e.created_at
                               from expense e
                               where e.id = new_id),
            'repartitions',   (
                select json_agg(
                               json_build_object('user',   user_id,
                                                 'weight', weight))
                from split
                where expense_id = new_id
            )
    );
end;
$$ language plpgsql security definer;

grant execute on function save_operation(int, text, numeric, date, int, int, json) to authenticated;

/**************************************************************
 *                      delete_operation                      *
 **************************************************************/
create or replace function delete_operation(id int)
returns void as
$$
declare
    v_tricount_id   int;                    -- préfixe "v" pour "variable"
    allowed         bool := false;
begin
    perform auth.check_logged();

    -- vérifie si expense exist et récup tricount_id
    select e.tricount_id into v_tricount_id
    from expense e
    where e.id = delete_operation.id;

    if not found then
        raise exception 'operation not found';
    end if;

    -- vérifie si user peut supprimer
    if exists(  -- créateur du tricount
        select 1 from tricount t
        where t.id = v_tricount_id
            and t.creator_id = auth.id()
    ) then
        allowed := true;
    elsif auth.is_admin() then  -- admin
        allowed := true;
    elsif
        exists (    -- participant
            select 1 from participation p
            where p.tricount_id = v_tricount_id
                and p.user_id = auth.id()
    ) then
        allowed := true;
    end if;
    if not allowed then
        raise exception 'access denied';
    end if;

    -- supprimer l'opération (et les splits qui sont associés)
    delete from expense e where e.id = delete_operation.id;

end;
$$ language plpgsql security definer;

grant execute on function delete_operation(int) to authenticated;