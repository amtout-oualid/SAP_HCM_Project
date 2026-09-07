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

    METHODS validateDelete FOR VALIDATE ON SAVE
      IMPORTING keys FOR OrgUnit~validateDelete.

    METHODS CalculateOrgUnitNum FOR DETERMINE ON MODIFY
      IMPORTING keys FOR OrgUnit~CalculateOrgUnitNum.

    METHODS DefaultStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR OrgUnit~DefaultStatus.

ENDCLASS.

CLASS lhc_orgunit IMPLEMENTATION.

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
                      OrgUnitId = cl_system_uuid=>create_uuid_x16_static( ) ) TO mapped-orgunit.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_cba_Positions.
    LOOP AT entities INTO DATA(entity).
      LOOP AT entity-%target INTO DATA(target).
        APPEND VALUE #( %cid       = target-%cid
                        %is_draft  = target-%is_draft
                        PositionId = cl_system_uuid=>create_uuid_x16_static( ) ) TO mapped-position.
      ENDLOOP.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDelete.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY OrgUnit BY \_Positions FIELDS ( PositionId )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_positions).

    LOOP AT keys INTO DATA(ls_key).
      IF line_exists( lt_positions[ OrgUnitId = ls_key-OrgUnitId ] ).
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-orgunit.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message(
                                 id       = '00'
                                 number   = '005'
                                 v1       = 'Cannot delete org unit with positions'
                                 severity = if_abap_behv_message=>severity-error ) )
               TO reported-orgunit.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD CalculateOrgUnitNum.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY OrgUnit FIELDS ( OrgUnitNum ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_orgunits).

    SELECT MAX( org_unit_num ) FROM zhcm_orgunit INTO @DATA(lv_max_num).
    DATA(lv_next_num) = CONV i( lv_max_num ).

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

ENDCLASS.

CLASS lhc_position DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS DefaultPosStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Position~DefaultPosStatus.
ENDCLASS.

CLASS lhc_position IMPLEMENTATION.
  METHOD DefaultPosStatus.
    READ ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
      ENTITY Position FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_positions).

    LOOP AT lt_positions ASSIGNING FIELD-SYMBOL(<ls_position>) WHERE Status IS INITIAL.
      MODIFY ENTITIES OF ZI_HCM_OrgUnit IN LOCAL MODE
        ENTITY Position
        UPDATE FIELDS ( Status ) WITH VALUE #( ( %tky = <ls_position>-%tky Status = 'A' ) ).
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

