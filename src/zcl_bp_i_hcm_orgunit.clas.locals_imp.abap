CLASS lhc_orgunit DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateDelete FOR VALIDATE ON SAVE
      IMPORTING keys FOR OrgUnit~validateDelete.
ENDCLASS.

CLASS lhc_orgunit IMPLEMENTATION.
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
