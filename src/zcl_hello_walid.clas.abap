CLASS zcl_hello_walid DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_hello_walid IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    out->write( 'hello walid amtout' ).
  ENDMETHOD.
ENDCLASS.
