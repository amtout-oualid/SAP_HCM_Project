CLASS lhc_talentpool DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR TalentPool RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE TalentPool.

ENDCLASS.

CLASS lhc_talentpool IMPLEMENTATION.
  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky    = key-%tky
                      %delete = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD earlynumbering_create.
    LOOP AT entities INTO DATA(entity).
      TRY.
          APPEND VALUE #( %cid   = entity-%cid
                          PoolId = cl_system_uuid=>create_uuid_x16_static( ) ) TO mapped-talentpool.
        CATCH cx_uuid_error.
          APPEND VALUE #( %cid = entity-%cid ) TO failed-talentpool.
      ENDTRY.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
