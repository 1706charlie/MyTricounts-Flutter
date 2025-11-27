-- on delete cascade : Supprime automatiquement toutes les lignes enfants lorsque la ligne parent est supprimee -- PARENT : tricount (id : cle primaire), ENFANT : participation (tricount_id : cle etrangère)
-- on delete restrict : Interdit la suppression de la ligne parent si des lignes enfants existent

set search_path to public, auth;

/**************************************************************/
/*                    tricount                               */
/**************************************************************/

drop table if exists tricount cascade;
create table tricount
(
    id          serial primary key,
    title       varchar(255) not null
        check (length(trim(title)) >= 3),
    description text
        check (description is null or length(trim(description)) >= 3),
    creator_id  integer not null references users(id) on delete restrict,           -- empêche la suppression d'un user s'il est createur
    created_at  timestamp default current_timestamp not null,                        -- timestamp : pour une date + heure. current_timestamp retourne la date et l’heure actuelles du système
    delete_at   timestamp default null
);
create unique index uq_tricount_creator_title                                       -- contrainte d'unicite mise en dehors de la table pour pouvoir utiliser les fonctions lower() et trim()
    on tricount (creator_id, lower(trim(title)));

INSERT INTO tricount (id, title, description, creator_id, created_at) VALUES
(4, 'Vacances',        'A la mer du nord',  1, '2024-10-10 19:31:09'),
(2, 'Resto badminton', NULL,                1, '2024-10-10 19:25:10'),
(1, 'Gers 2022',       NULL,                1, '2024-10-10 18:42:24');

select setval('tricount_id_seq', (select max(id)
                                  from tricount));

/**************************************************************/
/*                    participation                           */
/**************************************************************/

drop table if exists participation cascade;
create table participation
(
    tricount_id     integer not null references tricount(id) on delete cascade,
    user_id         integer not null references users(id) on delete cascade,
    primary key (tricount_id, user_id)                                              -- implique une contrainte d'unicité sur tricount_id, user_id
);

INSERT INTO participation (tricount_id, user_id) VALUES
(4, 1),(4, 2), (4, 4), (4, 3),(2, 2), (2, 1);

/**************************************************************/ -- en fr : depense
/*                expense / operation                         */
/**************************************************************/

drop table if exists expense cascade;
create table expense
(
    id              serial primary key,
    title           varchar(255) not null
        check (length(trim(title)) >= 3),
    amount          numeric(10,2) not null
        check (amount >= 0.01),
    initiator_id    integer not null references users(id) on delete restrict,       -- empêche la suppression d'un user initiateur d'une depense
    operation_date  date not null,                                                  -- (date à laquelle la depense a ete faite)
    created_at      timestamp not null default current_timestamp,                   -- (date/heure à laquelle la depense a ete creee en base de donnees)
    tricount_id     integer not null references tricount(id) on delete cascade      -- quand un tricount est supprime, ses depenses liees aussi
);

INSERT INTO expense
(id, title, amount, initiator_id, operation_date, tricount_id, created_at) VALUES
(6, 'Loterie',               35.00, 1, '2024-10-26', 4, '2024-10-26 10:02:24'),
(5, 'Boucherie',             25.50, 2, '2024-10-26', 4, '2024-10-26 09:59:56'),
(4, 'Apéros',                31.897456217, 1, '2024-10-13', 4, '2024-10-13 23:51:20'),
(3, 'Grosses courses LIDL', 212.47, 3, '2024-10-13', 4, '2024-10-13 21:23:49'),
(2, 'Plein essence',         75.00, 1, '2024-10-13', 4, '2024-10-13 20:10:41'),
(1, 'Colruyt',              100.00, 2, '2024-10-13', 4, '2024-10-13 19:09:18');

select setval('expense_id_seq', (select max(id)
                                  from expense));

/**************************************************************/ -- en fr : repartition
/*                  split / repartition                       */
/**************************************************************/

drop table if exists split cascade;
create table split
(
    expense_id      integer not null references expense(id) on delete cascade,      -- si on supprime une depense, toutes les splits liees aussi
    user_id         integer not null references users(id) on delete restrict,       -- empêche la suppression d'un user implique dans un split
    weight          integer not null
        check (weight > 0),
    primary key (expense_id, user_id)
);

INSERT INTO split VALUES
(6,1,1),(6,3,1),(5,1,2),(5,2,1),
(5,3,1),(4,1,1),(4,2,2),(4,3,3),
(3,1,2),(3,2,1),(3,3,1),(2,1,1),
(2,2,1),(1,1,1),(1,2,1);