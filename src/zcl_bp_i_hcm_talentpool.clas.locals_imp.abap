CLASS lhc_talentpool DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR TalentPool RESULT result.

    METHODS earlynumbering_create FOR NUMBERING
      IMPORTING entities FOR CREATE TalentPool.

    METHODS setDefaults FOR DETERMINE ON MODIFY
      IMPORTING keys FOR TalentPool~setDefaults.
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

  METHOD setDefaults.
    READ ENTITIES OF ZI_HCM_TalentPool IN LOCAL MODE
      ENTITY TalentPool FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_entries).

    DELETE lt_entries WHERE Status IS NOT INITIAL.
    IF lt_entries IS INITIAL.
      RETURN.
    ENDIF.

    " A: available for future offers
    MODIFY ENTITIES OF ZI_HCM_TalentPool IN LOCAL MODE
      ENTITY TalentPool UPDATE FIELDS ( Status )
      WITH VALUE #( FOR entry IN lt_entries ( %tky = entry-%tky Status = 'A' ) ).
  ENDMETHOD.
ENDCLASS.
