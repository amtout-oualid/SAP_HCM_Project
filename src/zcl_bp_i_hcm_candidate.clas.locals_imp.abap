CLASS lcl_buffer DEFINITION.
  PUBLIC SECTION.
    " This static table holds the applications in memory until the Save phase
    CLASS-DATA: mt_new_applications TYPE TABLE OF zhcm_applicatn.
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
    " 1. Read the Candidates
    READ ENTITIES OF ZI_HCM_Candidate IN LOCAL MODE
      ENTITY Candidate
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_candidates).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      " 2. Generate a new UUID for the Application
      DATA(lv_app_id) = cl_system_uuid=>create_uuid_x16_static( ).
      GET TIME STAMP FIELD DATA(lv_ts).

      " 3. Store the new application in the memory buffer
      APPEND VALUE #(
        client             = sy-mandt
        application_id     = lv_app_id
        offer_id           = <ls_key>-%param-OfferId
        candidate_id       = <ls_key>-CandidateId
        resume_url         = <ls_key>-%param-ResumeUrl
        cover_letter       = <ls_key>-%param-CoverLetter
        notice_period      = <ls_key>-%param-NoticePeriod
        salary_expectation = <ls_key>-%param-SalaryExpectation
        currency_code      = <ls_key>-%param-CurrencyCode
        applied_at         = lv_ts
        overall_status     = 'NW' " Default Status: New
        current_step_order = 1
      ) TO lcl_buffer=>mt_new_applications.

      " 4. Return success
      APPEND VALUE #( %tky = <ls_key>-%tky ) TO result.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lsc_ZI_HCM_CANDIDATE DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_HCM_CANDIDATE IMPLEMENTATION.
  METHOD save_modified.
    " 5. The Save Phase: This is where we are legally allowed to INSERT into the DB!
    IF lcl_buffer=>mt_new_applications IS NOT INITIAL.
      INSERT zhcm_applicatn FROM TABLE @lcl_buffer=>mt_new_applications.
      CLEAR lcl_buffer=>mt_new_applications.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

