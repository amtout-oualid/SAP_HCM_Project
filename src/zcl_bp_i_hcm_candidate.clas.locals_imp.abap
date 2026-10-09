"! Applications created by applyToJob, written to ZHCM_APPLICATN in the save sequence
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-DATA mt_new_applications TYPE TABLE OF zhcm_applicatn.

    CLASS-METHODS new_uuid RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.
ENDCLASS.

CLASS lcl_buffer IMPLEMENTATION.
  METHOD new_uuid.
    TRY.
        rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        CLEAR rv_uuid.
    ENDTRY.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_candidate DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Candidate RESULT result.

    METHODS applyToJob FOR MODIFY
      IMPORTING keys FOR ACTION Candidate~applyToJob RESULT result.
ENDCLASS.

CLASS lhc_candidate IMPLEMENTATION.
  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky = ls_key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD applyToJob.
    GET TIME STAMP FIELD DATA(lv_now).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    DATA lt_touch TYPE TABLE FOR UPDATE ZI_HCM_Candidate\\Candidate.
    DATA lv_already_applied TYPE abap_bool.

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      DATA(lv_error) = ``.

      " 1. The job offer must be published and still open (read through the job offer BO)
      READ ENTITIES OF ZI_HCM_JobOffer
        ENTITY JobOffer FIELDS ( Status AppDeadline PositionsNeeded PositionsFilled )
        WITH VALUE #( ( OfferId = <ls_key>-%param-OfferId ) )
        RESULT DATA(lt_offer).

      IF lt_offer IS INITIAL.
        lv_error = `This job offer does not exist.`.
      ELSEIF lt_offer[ 1 ]-Status <> 'P'.
        lv_error = `This job offer is not open for applications.`.
      ELSEIF lt_offer[ 1 ]-AppDeadline IS NOT INITIAL AND lt_offer[ 1 ]-AppDeadline < lv_today.
        lv_error = `The application deadline of this job offer has passed.`.
      ELSEIF lt_offer[ 1 ]-PositionsNeeded > 0 AND lt_offer[ 1 ]-PositionsFilled >= lt_offer[ 1 ]-PositionsNeeded.
        lv_error = `All positions of this job offer are already filled.`.
      ELSE.
        " 2. A candidate applies only once to the same offer
        CLEAR lv_already_applied.
        SELECT SINGLE @abap_true FROM zhcm_applicatn
          WHERE candidate_id = @<ls_key>-CandidateId
            AND offer_id     = @<ls_key>-%param-OfferId
          INTO @lv_already_applied.
        IF lv_already_applied = abap_true
           OR line_exists( lcl_buffer=>mt_new_applications[ candidate_id = <ls_key>-CandidateId
                                                            offer_id     = <ls_key>-%param-OfferId ] ).
          lv_error = `You have already applied to this job offer.`.
        ENDIF.
      ENDIF.

      IF lv_error IS NOT INITIAL.
        APPEND VALUE #( %tky = <ls_key>-%tky ) TO failed-candidate.
        APPEND VALUE #( %tky = <ls_key>-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = lv_error ) ) TO reported-candidate.
        CONTINUE.
      ENDIF.

      " 3. The application starts at the first pipeline step; it is inserted in the save sequence
      APPEND VALUE #(
        application_id        = lcl_buffer=>new_uuid( )
        offer_id              = <ls_key>-%param-OfferId
        candidate_id          = <ls_key>-CandidateId
        resume_url            = <ls_key>-%param-ResumeUrl
        cover_letter          = <ls_key>-%param-CoverLetter
        notice_period         = <ls_key>-%param-NoticePeriod
        salary_expectation    = <ls_key>-%param-SalaryExpectation
        currency_code         = <ls_key>-%param-CurrencyCode
        source                = 'Candidate Portal'
        applied_at            = lv_now
        overall_status        = 'N'
        current_step_order    = 1
        created_by            = sy-uname
        created_at            = lv_now
        last_changed_by       = sy-uname
        last_changed_at       = lv_now
        local_last_changed_at = lv_now
      ) TO lcl_buffer=>mt_new_applications.

      " The candidate is touched so that the save sequence runs for this request
      APPEND VALUE #( %tky = <ls_key>-%tky LocalLastChangedAt = lv_now ) TO lt_touch.
    ENDLOOP.

    IF lt_touch IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF ZI_HCM_Candidate IN LOCAL MODE
      ENTITY Candidate UPDATE FIELDS ( LocalLastChangedAt ) WITH lt_touch.

    READ ENTITIES OF ZI_HCM_Candidate IN LOCAL MODE
      ENTITY Candidate ALL FIELDS WITH CORRESPONDING #( lt_touch )
      RESULT DATA(lt_candidates).
    result = VALUE #( FOR ls_candidate IN lt_candidates ( %tky = ls_candidate-%tky %param = ls_candidate ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lsc_ZI_HCM_CANDIDATE DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_HCM_CANDIDATE IMPLEMENTATION.
  METHOD save_modified.
    " The save sequence is the only place where the applications may be written to the database
    IF lcl_buffer=>mt_new_applications IS NOT INITIAL.
      INSERT zhcm_applicatn FROM TABLE @lcl_buffer=>mt_new_applications.
    ENDIF.
    CLEAR lcl_buffer=>mt_new_applications.
  ENDMETHOD.

  METHOD cleanup_finalize.
    CLEAR lcl_buffer=>mt_new_applications.
  ENDMETHOD.
ENDCLASS.
