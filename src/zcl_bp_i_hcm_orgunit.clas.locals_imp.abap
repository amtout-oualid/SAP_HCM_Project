CLASS lhc_orgunit DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateDelete FOR VALIDATE ON SAVE
      IMPORTING keys FOR OrgUnit~validateDelete.
ENDCLASS.

CLASS lhc_orgunit IMPLEMENTATION.

  METHOD validateDelete.
    " TODO: prevent deletion of Org Units that still have active Positions or child Org Units
  ENDMETHOD.

ENDCLASS.

