CLASS zcl_hcm_populate_status DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_hcm_populate_status IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA lt_status TYPE TABLE OF zhcm_genstat.

    " Add common statuses
    APPEND VALUE #( status = 'A' description = 'Active' ) TO lt_status.
    APPEND VALUE #( status = 'I' description = 'Inactive' ) TO lt_status.
    APPEND VALUE #( status = 'P' description = 'Pending' ) TO lt_status.
    APPEND VALUE #( status = 'F' description = 'Filled' ) TO lt_status.

    " Clear and insert
    DELETE FROM zhcm_genstat.
    INSERT zhcm_genstat FROM TABLE @lt_status.

    COMMIT WORK.

    out->write( 'Status values successfully populated!' ).
  ENDMETHOD.
ENDCLASS.

