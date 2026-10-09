CLASS lhc_orgunit DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR OrgUnit RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR OrgUnit RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE OrgUnit.

    METHODS earlynumbering_cba_Positions FOR NUMBERING
      IMPORTING entities FOR CREATE OrgUnit\_Positions.

    METHODS validateMandatory FOR VALIDATE ON SAVE
      IMPORTING keys FOR OrgUnit~validateMandatory.

    METHODS validateDelete FOR VALIDATE ON SAVE
      IMPORTING keys FOR OrgUnit~validateDelete.

    METHODS validateParent FOR VALIDATE ON SAVE
      IMPORTING keys FOR OrgUnit~validateParent.

    METHODS CalculateOrgUnitNum FOR DETERMINE ON MODIFY
      IMPORTING keys FOR OrgUnit~CalculateOrgUnitNum.

    METHODS DefaultStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR OrgUnit~DefaultStatus.

    METHODS setParentUnitName FOR DETERMINE ON MODIFY
      IMPORTING keys FOR OrgUnit~setParentUnitName.

    CLASS-METHODS new_uuid RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.
ENDCLASS.

CLASS lhc_orgunit IMPLEMENTATION.

  METHOD new_uuid.
    TRY.
        rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        CLEAR rv_uuid.
    ENDTRY.
  ENDMETHOD.

  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky = key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    LOOP AT entities INTO DATA(entity).
      APPEND VALUE #( %cid      = entity-%cid
                      %is_draft = entity-%is_draft
                      OrgUnitId = new_uuid( ) ) TO mapped-orgunit.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_cba_Positions.
    LOOP AT entities INTO DATA(entity).
      LOOP AT entity-%target INTO DATA(target).
        APPEND VALUE #( %cid       = target-%cid
                        %is_draft  = target-%is_draft
                        PositionId = new_uuid( ) ) TO mapped-position.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateMandatory.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY OrgUnit FIELDS ( UnitName ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_orgs).

    LOOP AT lt_orgs INTO DATA(ls_org).
      APPEND VALUE #( %tky = ls_org-%tky %state_area = 'VALIDATE_MANDATORY' ) TO reported-orgunit.

      IF ls_org-UnitName IS INITIAL.
        APPEND VALUE #( %tky = ls_org-%tky ) TO failed-orgunit.
        APPEND VALUE #( %tky              = ls_org-%tky
                        %state_area       = 'VALIDATE_MANDATORY'
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'The unit name is required.' )
                        %element-UnitName = if_abap_behv=>mk-on ) TO reported-orgunit.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDelete.
    DATA lv_has_positions TYPE abap_bool.
    DATA lv_has_children  TYPE abap_bool.

    " A unit can only be deleted when it has no positions and no sub-units (checked in the database)
    LOOP AT keys INTO DATA(ls_key).
      CLEAR: lv_has_positions, lv_has_children.
      SELECT SINGLE @abap_true FROM zhcm_position
        WHERE org_unit_id = @ls_key-OrgUnitId
        INTO @lv_has_positions.

      SELECT SINGLE @abap_true FROM zhcm_orgunit
        WHERE parent_org_unit_id = @ls_key-OrgUnitId
        INTO @lv_has_children.

      IF lv_has_positions = abap_true OR lv_has_children = abap_true.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-orgunit.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text(
                                 severity = if_abap_behv_message=>severity-error
                                 text     = COND string( WHEN lv_has_positions = abap_true
                                                         THEN `Cannot delete an organizational unit that still has positions.`
                                                         ELSE `Cannot delete an organizational unit that still has sub-units.` ) ) )
          TO reported-orgunit.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateParent.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY OrgUnit FIELDS ( OrgUnitId ParentOrgUnitId )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_orgs).

    LOOP AT lt_orgs INTO DATA(ls_org).
      APPEND VALUE #( %tky = ls_org-%tky %state_area = 'VALIDATE_PARENT' ) TO reported-orgunit.

      IF ls_org-ParentOrgUnitId IS INITIAL.
        CONTINUE.
      ENDIF.

      DATA(lv_error) = ``.
      IF ls_org-ParentOrgUnitId = ls_org-OrgUnitId.
        lv_error = `An organizational unit cannot be its own parent.`.
      ELSE.
        " Walk up the hierarchy: the parent must exist and must not be one of the unit's own sub-units
        DATA(lv_current) = ls_org-ParentOrgUnitId.
        DATA(lv_level) = 0.
        WHILE lv_current IS NOT INITIAL AND lv_level < 50.
          lv_level += 1.
          READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
            ENTITY OrgUnit FIELDS ( ParentOrgUnitId )
            WITH VALUE #( ( OrgUnitId = lv_current ) )
            RESULT DATA(lt_parent).
          IF lt_parent IS INITIAL.
            IF lv_level = 1.
              lv_error = `The selected parent unit does not exist.`.
            ENDIF.
            EXIT.
          ENDIF.
          lv_current = lt_parent[ 1 ]-ParentOrgUnitId.
          IF lv_current = ls_org-OrgUnitId.
            lv_error = `The parent unit cannot be one of the unit's own sub-units.`.
            EXIT.
          ENDIF.
        ENDWHILE.
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_org-%tky ) TO failed-orgunit.
        APPEND VALUE #( %tky                     = ls_org-%tky
                        %state_area              = 'VALIDATE_PARENT'
                        %msg                     = new_message_with_text(
                                                     severity = if_abap_behv_message=>severity-error
                                                     text     = lv_error )
                        %element-ParentOrgUnitId = if_abap_behv=>mk-on ) TO reported-orgunit.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD CalculateOrgUnitNum.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY OrgUnit FIELDS ( OrgUnitNum ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orgunits).

    " Next free number, looking at saved units and at units still in draft
    SELECT MAX( org_unit_num ) FROM zhcm_orgunit INTO @DATA(lv_max_active).
    SELECT MAX( orgunitnum ) FROM zhcm_d_orgunit INTO @DATA(lv_max_draft).

    DATA lv_next_num TYPE i.
    DATA lv_draft_num TYPE i.
    TRY.
        lv_next_num  = lv_max_active.
        lv_draft_num = lv_max_draft.
      CATCH cx_sy_conversion_no_number.
        CLEAR: lv_next_num, lv_draft_num.
    ENDTRY.
    lv_next_num = nmax( val1 = lv_next_num val2 = lv_draft_num ).

    LOOP AT lt_orgunits ASSIGNING FIELD-SYMBOL(<ls_orgunit>) WHERE OrgUnitNum IS INITIAL.
      lv_next_num += 1.
      <ls_orgunit>-OrgUnitNum = |{ lv_next_num WIDTH = 6 ALIGN = RIGHT PAD = '0' }|.

      MODIFY ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
        ENTITY OrgUnit
        UPDATE FIELDS ( OrgUnitNum ) WITH VALUE #( ( %tky = <ls_orgunit>-%tky OrgUnitNum = <ls_orgunit>-OrgUnitNum ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD DefaultStatus.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY OrgUnit FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orgunits).

    LOOP AT lt_orgunits ASSIGNING FIELD-SYMBOL(<ls_orgunit>) WHERE Status IS INITIAL.
      MODIFY ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
        ENTITY OrgUnit
        UPDATE FIELDS ( Status ) WITH VALUE #( ( %tky = <ls_orgunit>-%tky Status = 'A' ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD setParentUnitName.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY OrgUnit FIELDS ( ParentOrgUnitId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orgunits).

    " Shows the name of the chosen parent immediately (the text of the parent value help)
    LOOP AT lt_orgunits INTO DATA(ls_orgunit).
      DATA(lv_parent_name) = CONV zhcm_orgunit-unit_name( '' ).
      IF ls_orgunit-ParentOrgUnitId IS NOT INITIAL.
        READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
          ENTITY OrgUnit FIELDS ( UnitName ) WITH VALUE #( ( OrgUnitId = ls_orgunit-ParentOrgUnitId ) )
          RESULT DATA(lt_parent).
        IF lt_parent IS NOT INITIAL.
          lv_parent_name = lt_parent[ 1 ]-UnitName.
        ENDIF.
      ENDIF.

      MODIFY ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
        ENTITY OrgUnit UPDATE FIELDS ( ParentUnitName )
        WITH VALUE #( ( %tky = ls_orgunit-%tky ParentUnitName = lv_parent_name ) ).
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

CLASS lhc_position DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Position RESULT result.

    METHODS DefaultPosStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Position~DefaultPosStatus.

    METHODS validatePosition FOR VALIDATE ON SAVE
      IMPORTING keys FOR Position~validatePosition.
ENDCLASS.

CLASS lhc_position IMPLEMENTATION.
  METHOD get_instance_features.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY Position FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_positions).

    " A filled position cannot be deleted (an employee is assigned to it)
    result = VALUE #( FOR ls_pos IN lt_positions (
      %tky    = ls_pos-%tky
      %delete = COND #( WHEN ls_pos-Status = 'F'
                        THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled ) ) ).
  ENDMETHOD.

  METHOD DefaultPosStatus.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY Position FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_positions).

    " New positions are vacant
    LOOP AT lt_positions ASSIGNING FIELD-SYMBOL(<ls_position>) WHERE Status IS INITIAL.
      MODIFY ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
        ENTITY Position
        UPDATE FIELDS ( Status ) WITH VALUE #( ( %tky = <ls_position>-%tky Status = 'V' ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD validatePosition.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY Position FIELDS ( JobTitle Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_positions).

    LOOP AT lt_positions INTO DATA(ls_position).
      APPEND VALUE #( %tky = ls_position-%tky %state_area = 'VALIDATE_POSITION' ) TO reported-position.

      IF ls_position-JobTitle IS INITIAL.
        APPEND VALUE #( %tky = ls_position-%tky ) TO failed-position.
        APPEND VALUE #( %tky              = ls_position-%tky
                        %state_area       = 'VALIDATE_POSITION'
                        %msg              = new_message_with_text(
                                              severity = if_abap_behv_message=>severity-error
                                              text     = 'The job title of the position is required.' )
                        %element-JobTitle = if_abap_behv=>mk-on ) TO reported-position.
      ELSEIF ls_position-Status <> 'V' AND ls_position-Status <> 'F' AND ls_position-Status <> 'Z'.
        APPEND VALUE #( %tky = ls_position-%tky ) TO failed-position.
        APPEND VALUE #( %tky            = ls_position-%tky
                        %state_area     = 'VALIDATE_POSITION'
                        %msg            = new_message_with_text(
                                            severity = if_abap_behv_message=>severity-error
                                            text     = 'Position status must be Vacant (V), Filled (F) or Frozen (Z).' )
                        %element-Status = if_abap_behv=>mk-on ) TO reported-position.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.
