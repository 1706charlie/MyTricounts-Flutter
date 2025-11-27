set search_path to public, auth;

--  1) Calcule la somme des poids pour chaque dépense
create or replace view vw_expense_total_weight as
select
    e.id                as expense_id,
    sum(s.weight)       as total_weight
from expense       e
         join split         s on s.expense_id = e.id
group by e.id;


-- 2) Calcule pour chaque user la part (= montant * poids/total) qu’il doit pour la dépense
create or replace view vw_expense_shares as
select
    e.tricount_id,
    e.id                    as expense_id,
    s.user_id,
    /* part = montant * poids / poids_total */
    (e.amount * s.weight / t.total_weight)::numeric(14,2) as share
from expense                e
         join split                  s on s.expense_id = e.id
         join vw_expense_total_weight t on t.expense_id = e.id;


-- 3) Montant total dû par user dans chaque tricount
create or replace view vw_amount_owed_by_user as
select
    tricount_id,
    user_id,
    sum(share) as amount_owed
from vw_expense_shares
group by tricount_id, user_id;


-- 4) Montant total payé par user dans chaque tricount
create or replace view vw_amount_paid_by_user as
select
    e.tricount_id,
    e.initiator_id          as user_id,
    sum(e.amount)           as amount_paid
from expense e
group by e.tricount_id, e.initiator_id;

-- tous les utilisateurs impliques dans un tricount
create or replace view vw_tricount_users as
select id as tricount_id, creator_id as user_id  -- le createur
from tricount
union
select tricount_id, user_id     -- + tous les participants
from   participation;

-- 5) balance finale par user pour chaque tricount
create or replace view vw_tricount_balances as
select
    u.tricount_id,
    u.user_id,
    coalesce(p.amount_paid, 0)::numeric(12,2)  as amount_paid,
    coalesce(o.amount_owed, 0)::numeric(12,2)  as amount_owed,
    round( coalesce(p.amount_paid,0) - coalesce(o.amount_owed,0), 2)::numeric(12,2)  as balance
from vw_tricount_users u
         left join vw_amount_paid_by_user p
                   on p.tricount_id = u.tricount_id
                       and p.user_id = u.user_id
         left join vw_amount_owed_by_user o
                   on o.tricount_id = u.tricount_id
                       and o.user_id = u.user_id;


-- vue de controle qui retourne les eventuels tricounts errones : le total des balances doit etre environ 0,00 €
create or replace view vw_balance_consistency_check as
select
    tricount_id,
    round(sum(balance), 2) as total_balance
from vw_tricount_balances
group by tricount_id
having abs(round(sum(balance), 2)) > 0.01;


-- calcule la balance de chaque utilisateur dans chaque tricount
create or replace function compute_balance(p_tricount_id integer)
    returns table
            (
                user_id     integer,
                total_paid  numeric(12,2),
                total_owed  numeric(12,2),
                balance     numeric(12,2)
            )
as $$
select user_id,
       amount_paid,
       amount_owed,
       balance
from   vw_tricount_balances
where  tricount_id = p_tricount_id
order  by user_id;
$$ language sql;

grant execute on function compute_balance(integer) to authenticated;

-- Dans l'architecture mise en place pour ce cours et le projet, nous avons choisi de ne pas exposer les vues directement dans PostgREST, pour des raisons de securite.
-- Cependant, vous pouvez utiliser des vues en interne, et les lire depuis vos endpoints.
