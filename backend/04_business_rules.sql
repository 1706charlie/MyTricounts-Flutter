/**************************************************************/
/*                    Tricount                                */
/**************************************************************/

-- "le createur du tricount ne peut pas être modifie"
create or replace function prevent_creator_change() returns trigger as
$$
begin
    if new.creator_id <> old.creator_id then
        raise exception 'Le createur d''un tricount ne peut pas être modifie.';
    end if;
    return new;
end
$$ language plpgsql;
drop trigger if exists trg_no_change_creator on tricount;
create trigger trg_no_change_creator
    before update
    on tricount
    for each row
execute function prevent_creator_change();


-- "la date/heure de creation du tricount ne peut pas être modifiee"
create or replace function prevent_update_created_at()
    returns trigger as
$$
begin
    if new.created_at <> old.created_at then
        raise exception 'La date/heure de creation d''un tricount ne peut pas être modifiee.';
    end if;
    return new;
end;
$$ language plpgsql;
drop trigger if exists trg_prevent_update_created_at on tricount;
create trigger trg_prevent_update_created_at
    before update
    on tricount
    for each row
execute function prevent_update_created_at();


/**************************************************************/
/*                    Participation                           */
/**************************************************************/

-- "Le createur d'un tricount doit toujours être enregistre comme participant et cette participation ne peut pas être supprimee"
-- on insere automatiquement une participation pour le createur des qu'un tricount est cree
create or replace function add_creator_to_participation() returns trigger as
$$
begin
    insert into participation (tricount_id, user_id)
    values (new.id, new.creator_id);
    return new;
end;
$$ language plpgsql;
drop trigger if exists trigger_add_creator_to_participation on tricount;
create trigger trigger_add_creator_to_participation
    after insert
    on tricount
    for each row
execute function add_creator_to_participation();

-- maintenant, il faut attaquer la deuxieme partie de la phrase : "cette participation ne peut pas être supprimee"
-- 1) Interdire la suppression de la ligne
create or replace function prevent_creator_participation_delete() returns trigger as
$$
begin
    if exists (
        select 1
        from tricount t
        where t.id = old.tricount_id
          and t.creator_id = old.user_id
    ) then
        raise exception 'impossible de supprimer la participation du createur du tricount (id=%).', old.tricount_id;
    end if;
    return old;
end;
$$ language plpgsql;
drop trigger if exists trig_prevent_creator_participation_delete on participation;
create trigger trig_prevent_creator_participation_delete
    before delete
    on participation
    for each row
execute function prevent_creator_participation_delete();

-- 2) Interdire la modification de la ligne (changement de user_id ou tricount_id)
create or replace function prevent_creator_participation_update() returns trigger as
$$
begin
    if exists (
        select 1
        from tricount t
        where t.id = old.tricount_id
          and t.creator_id = old.user_id
    ) and (
        new.user_id <> old.user_id
        or new.tricount_id <> old.tricount_id
    )
        then
            raise exception 'impossible de modifier la participation du createur du tricount (id=%).', old.tricount_id;
    end if;
    return new;
end;
$$ language plpgsql;
drop trigger if exists trig_prevent_creator_participation_update on participation;
create trigger trig_prevent_creator_participation_update
    before update
    on participation
    for each row
execute function prevent_creator_participation_update();


-- "Un participant implique dans au moins une depense (comme initiateur ou dans la repartition) ne peut pas être supprime du tricount associe"
create or replace function prevent_deletion_participant_with_expense() returns trigger as
$$
begin
    if exists(
        select 1
        from expense
        where tricount_id = old.tricount_id
          and initiator_id = old.user_id
    ) then
        raise exception 'impossible de supprimer un participant initiateur d''une depense.';
    end if;

    if exists(
        select 1
        from split s
              join expense e on s.expense_id = e.id
        where e.tricount_id = old.tricount_id
          and s.user_id = old.user_id
    ) then
        raise exception 'impossible de supprimer un participant implique dans une depense.';
    end if;
    return old;
end;
$$ language plpgsql;
drop trigger if exists trigger_prevent_deletion_participant_with_expense on participation;
create trigger trigger_prevent_deletion_participant_with_expense
    before delete
    on participation
    for each row
execute function prevent_deletion_participant_with_expense();



/**************************************************************/ -- en fr : depense
/*                    expense                                 */
/**************************************************************/

-- "la date de l'operation ne peut pas être anterieure a la date de creation du tricount associe, ni superieure a la date du jour au moment de l'encodage"
create or replace function prevent_invalid_operation_date() returns trigger as
$$
declare
    tricount_created_at timestamp;
begin
    select created_at into tricount_created_at
    from tricount t
    where t.id = new.tricount_id;

    if new.operation_date < date(tricount_created_at) then
        raise exception 'La date d''operation ne peut être anterieure a la creation du tricount.';
    end if;

    if new.operation_date > current_date then
        raise exception 'La date d''operation ne peut être dans le futur.';
    end if;
    return new;
end;
$$ language plpgsql;
drop trigger if exists trigger_check_expense_date on expense;
create trigger trigger_check_expense_date
    before insert or update
    on expense
    for each row
execute function prevent_invalid_operation_date();

-- "la date/heure de creation ne peut pas être modifiee"
create or replace function prevent_change_created_at() returns trigger as
$$
begin
    if new.created_at <> old.created_at then
        raise exception 'created_at est immuable.';
    end if;
    return new;
end
$$ language plpgsql;
drop trigger if exists trg_no_change_created_at on expense;
create trigger trg_no_change_created_at
    before update
    on expense
    for each row
execute function prevent_change_created_at();

-- "l'initiateur doit être un des participants du tricount associe a cette depense"
-- 1) garantir au moment de la creation ou de la mise a jour d’une depense que l’initiateur est bien inscrit comme participant
create or replace function prevent_insert_initiator_not_participant() returns trigger as
$$
begin
    if not exists(
        select 1
        from participation
        where tricount_id = new.tricount_id
          and user_id = new.initiator_id
    ) then
        raise exception 'L''initiateur de la depense doit être un participant du tricount.';
    end if;
    return new;
end;
$$ language plpgsql;
drop trigger if exists trigger_check_expense_initiator on expense;
create trigger trigger_check_expense_initiator
    before insert or update
    on expense
    for each row
execute function prevent_insert_initiator_not_participant();

-- 2) empêcher tout changement de cette participation si l’utilisateur a deja cree une depense
create or replace function prevent_update_participation_with_expense() returns trigger as
$$
begin
    if exists (
        select 1
        from expense
        where tricount_id = old.tricount_id
          and initiator_id = old.user_id
    )
    and (
        new.tricount_id <> old.tricount_id
        or new.user_id <> old.user_id
    )
    then
        raise exception
            'Impossible de modifier la participation (%,%) : un initiateur de dépense y est rattache.', old.tricount_id, old.user_id;
    end if;

    return new;
end;
$$ language plpgsql;
drop trigger if exists trig_prevent_update_participation_with_expense on participation;
create trigger trig_prevent_update_participation_with_expense
    before update on participation
    for each row
execute function prevent_update_participation_with_expense();


/**************************************************************/ -- en fr : repartition
/*                    split                                   */
/**************************************************************/

-- Verifie que le user_id du split appartient bien au tricount de la depense
create or replace function check_split_participant() returns trigger as
$$
begin
    if not exists (
        select 1
        from expense e
            join participation p on p.tricount_id = e.tricount_id
        where e.id = new.expense_id
          and p.user_id = new.user_id
    ) then raise exception 'Le participant % n''appartient pas au tricount de la depense %', new.user_id, new.expense_id;
    end if;
    return new;
end;
$$ language plpgsql;
drop trigger if exists trg_split_participant on split;
create trigger trg_split_participant
    before insert or update
    on split
    for each row
execute function check_split_participant();


-- "Il doit toujours y avoir au moins un participant implique dans une depense"

-- Fonction utilitaire : verifier qu’une depense possede au moins un participant dans la table split
create or replace function assert_expense_has_participant(p_expense_id int) returns void as
$$
declare
    cpt int;
begin
    -- p_expense_id correspond t il a une depense existante ?
    if not exists (select 1
                   from expense e
                   where e.id = p_expense_id
    ) then return;  -- rien à vérifier
    end if;

    -- on compte combien de lignes split sont liees à cette depense
    select count(*) into cpt
    from split
    where expense_id = p_expense_id;

    if cpt = 0 then
        raise exception 'La depense % doit avoir au moins un participant (table split).', p_expense_id;
    end if;
end;
$$ language plpgsql security definer;


create or replace function check_expense_has_participant() returns trigger as
$$
begin
    if tg_table_name = 'expense' then
        perform assert_expense_has_participant(new.id);

    elsif tg_table_name = 'split' then

        if tg_op in ('insert','update') then
            perform assert_expense_has_participant(new.expense_id);
        end if;

        if tg_op in ('delete','update') then
            -- update : seulement si l’id change vraiment
            if tg_op = 'update' and new.expense_id = old.expense_id then
                return null;
            end if;
            perform assert_expense_has_participant(old.expense_id);
        end if;
    end if;

    return null;  -- trigger de contrainte
end;
$$ language plpgsql security definer;

drop trigger if exists trg_expense_has_participant_on_expense on expense;
create constraint trigger trg_expense_has_participant_on_expense
    after insert or update on expense
    deferrable initially deferred
    for each row
execute procedure check_expense_has_participant();

drop trigger if exists trg_expense_has_participant_on_split on split;
create constraint trigger trg_expense_has_participant_on_split
    after insert or delete or update of expense_id on split
    deferrable initially deferred
    for each row
execute procedure check_expense_has_participant();
-- Un declencheur differe doit toujours être after et for each row
