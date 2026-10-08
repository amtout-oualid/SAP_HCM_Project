CLASS zcl_hello_walid DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.

    INTERFACES if_oo_adt_classrun .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_HELLO_WALID IMPLEMENTATION.


  METHOD if_oo_adt_classrun~main.
    out->write( 'hello walid amtout' ).
  ENDMETHOD.
ENDCLASS.
