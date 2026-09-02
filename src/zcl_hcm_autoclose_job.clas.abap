CLASS zcl_hcm_autoclose_job DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_oo_adt_classrun.
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_hcm_autoclose_job IMPLEMENTATION.
  METHOD if_oo_adt_classrun~main.
    DATA: lt_keys TYPE TABLE FOR ACTION IMPORT ZI_HCM_JobOffer~closeOffer,
          lt_reported TYPE RESPONSE FOR REPORTED ZI_HCM_JobOffer,
          lt_failed TYPE RESPONSE FOR FAILED ZI_HCM_JobOffer.

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    " Select all published offers where the deadline is in the past
    SELECT offer_id
      FROM zhcm_joboffer
      WHERE status = 'P'
        AND app_deadline < @lv_today
        AND app_deadline IS NOT INITIAL
      INTO TABLE @DATA(lt_expired_offers).

    IF sy-subrc = 0 AND lt_expired_offers IS NOT INITIAL.

      " Prepare the keys for the closeOffer action
      LOOP AT lt_expired_offers INTO DATA(ls_offer).
        APPEND VALUE #( %tky-OfferId = ls_offer-offer_id ) TO lt_keys.
      ENDLOOP.

      " Execute the closeOffer action using EML
      MODIFY ENTITIES OF ZI_HCM_JobOffer
        ENTITY JobOffer
        EXECUTE closeOffer FROM lt_keys
        FAILED lt_failed
        REPORTED lt_reported.

      IF lt_failed IS INITIAL.
        COMMIT ENTITIES.
        out->write( |Successfully closed { lines( lt_keys ) } expired job offer(s).| ).
      ELSE.
        ROLLBACK ENTITIES.
        out->write( 'Failed to close job offers due to validation errors.' ).
      ENDIF.

    ELSE.
      out->write( 'No expired job offers found. Everything is up to date!' ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

