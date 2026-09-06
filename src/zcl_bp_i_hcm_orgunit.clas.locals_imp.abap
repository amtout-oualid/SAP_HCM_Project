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
ENDCLASS.
