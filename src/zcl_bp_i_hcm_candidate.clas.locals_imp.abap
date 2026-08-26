CLASS lhc_Candidate DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Candidate RESULT result.

    METHODS applyToJob FOR MODIFY
      IMPORTING keys FOR ACTION Candidate~applyToJob RESULT result.

ENDCLASS.

CLASS lhc_Candidate IMPLEMENTATION.

  METHOD get_instance_authorizations.
  ENDMETHOD.

  METHOD applyToJob.
    DATA: lt_applications TYPE TABLE OF zhcm_applicatn,
          ls_application  TYPE zhcm_applicatn.

    " 1. Read the Candidate details
    READ ENTITIES OF ZI_HCM_Candidate IN LOCAL MODE
      ENTITY Candidate
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_candidates).

    LOOP AT keys ASSIGNING FIELD-SYMBOL(<ls_key>).
      " 2. Generate a new UUID for the Application
      TRY.
          ls_application-application_id = cl_system_uuid=>create_uuid_x16_static( ).
        CATCH cx_uuid_error.
      ENDTRY.

      " 3. Map the fields from the Action Parameter to the Application Table
      ls_application-candidate_id = <ls_key>-CandidateId.
      ls_application-offer_id = <ls_key>-%param-OfferId.
      ls_application-resume_url = <ls_key>-%param-ResumeUrl.
      ls_application-cover_letter = <ls_key>-%param-CoverLetter.
      ls_application-notice_period = <ls_key>-%param-NoticePeriod.
      ls_application-salary_expectation = <ls_key>-%param-SalaryExpectation.
      ls_application-currency_code = <ls_key>-%param-CurrencyCode.

      " Set status to P (Pending) and start at Step 1
      GET TIME STAMP FIELD ls_application-applied_at.
      ls_application-overall_status = 'P'.
      ls_application-current_step_order = 1.

      APPEND ls_application TO lt_applications.
    ENDLOOP.

    " 4. Safely insert the application into the database (Bypassing Draft Locks)
    IF lt_applications IS NOT INITIAL.
      INSERT zhcm_applicatn FROM TABLE @lt_applications.
    ENDIF.

    " 5. Return the Candidate entity back to the UI
    result = VALUE #( FOR ls_cand IN lt_candidates (
                        %tky = ls_cand-%tky
                        %param = ls_cand ) ).
  ENDMETHOD.

ENDCLASS.

