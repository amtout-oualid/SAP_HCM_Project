CLASS zcl_hcm_cleanup DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
ENDCLASS.

CLASS zcl_hcm_cleanup IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    " Delete corrupt data with blank UUIDs
    DELETE FROM zhcm_orgunit.
    DELETE FROM zhcm_position.
    COMMIT WORK.

    out->write( 'All corrupt Org Units and Positions have been deleted successfully!' ).
  ENDMETHOD.
ENDCLASS.

