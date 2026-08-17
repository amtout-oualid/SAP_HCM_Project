CLASS lhc_joboffer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR JobOffer RESULT result.
    METHODS validateDates FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validateDates.
    METHODS validateSalary FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validateSalary.
    METHODS publishOffer FOR MODIFY
      IMPORTING keys FOR ACTION JobOffer~publishOffer RESULT result.
    METHODS closeOffer FOR MODIFY
      IMPORTING keys FOR ACTION JobOffer~closeOffer RESULT result.
ENDCLASS.

CLASS lhc_application DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Application RESULT result.
    METHODS validateCIN FOR VALIDATE ON SAVE
      IMPORTING keys FOR Application~validateCIN.
    METHODS evaluateWithAI FOR MODIFY
      IMPORTING keys FOR ACTION Application~evaluateWithAI RESULT result.
    METHODS passToNextStep FOR MODIFY
      IMPORTING keys FOR ACTION Application~passToNextStep RESULT result.
    METHODS rejectCandidate FOR MODIFY
      IMPORTING keys FOR ACTION Application~rejectCandidate RESULT result.
    METHODS acceptToPost FOR MODIFY
      IMPORTING keys FOR ACTION Application~acceptToPost RESULT result.
ENDCLASS.

CLASS lhc_joboffer IMPLEMENTATION.
  METHOD get_instance_authorizations.
    " Grant full authorization for everything to bypass checks
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky = ls_key-%tky
                      %update              = if_abap_behv=>auth-allowed
                      %delete              = if_abap_behv=>auth-allowed
                      %action-publishOffer = if_abap_behv=>auth-allowed
                      %action-closeOffer   = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateDates.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( ValidUntil )
      WITH CORRESPONDING #( keys ) RESULT DATA(offers).

    LOOP AT offers INTO DATA(offer).
      IF offer-ValidUntil IS NOT INITIAL AND offer-ValidUntil < cl_abap_context_info=>get_system_date( ).
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky = offer-%tky
                        %msg = new_message(
                                 id       = '00'
                                 number   = '001'
                                 v1       = 'Valid Until date must be in the future'
                                 severity = if_abap_behv_message=>severity-error ) )
               TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateSalary.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( SalaryMin SalaryMax )
      WITH CORRESPONDING #( keys ) RESULT DATA(offers).

    LOOP AT offers INTO DATA(offer).
      IF offer-SalaryMin > offer-SalaryMax.
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky = offer-%tky
                        %msg = new_message(
                                 id       = '00'
                                 number   = '002'
                                 v1       = 'Min salary cannot exceed max salary'
                                 severity = if_abap_behv_message=>severity-error ) )
               TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD publishOffer.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'P' ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD closeOffer.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'C' ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lhc_application IMPLEMENTATION.
  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky = ls_key-%tky
                      %action-evaluateWithAI  = if_abap_behv=>auth-allowed
                      %action-passToNextStep  = if_abap_behv=>auth-allowed
                      %action-rejectCandidate = if_abap_behv=>auth-allowed
                      %action-acceptToPost    = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateCIN.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( CandidateId OfferId )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_apps).

    LOOP AT lt_apps INTO DATA(ls_app).
      DATA lv_count TYPE i.
      SELECT COUNT( * ) FROM zhcm_applicatn
        WHERE candidate_id = @ls_app-CandidateId
          AND offer_id = @ls_app-OfferId
          AND application_id <> @ls_app-ApplicationId
        INTO @lv_count.

      IF lv_count > 0.
        APPEND VALUE #( %tky = ls_app-%tky ) TO failed-application.
        APPEND VALUE #( %tky = ls_app-%tky
                        %msg = new_message(
                                 id       = '00'
                                 number   = '003'
                                 v1       = 'Candidate already applied to this offer'
                                 severity = if_abap_behv_message=>severity-error ) )
               TO reported-application.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD evaluateWithAI.
    DATA(lv_time) = cl_abap_context_info=>get_system_time( ).
    DATA(lv_score) = 50 + ( CONV i( lv_time ) MOD 49 ). " Placeholder random score

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( AiMatchScore )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky AiMatchScore = lv_score ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD passToNextStep.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( CurrentStepOrder )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_app).

    LOOP AT lt_app ASSIGNING FIELD-SYMBOL(<fs_app>).
      <fs_app>-CurrentStepOrder += 1.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( CurrentStepOrder )
      WITH VALUE #( FOR a IN lt_app ( %tky = a-%tky CurrentStepOrder = a-CurrentStepOrder ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD rejectCandidate.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'R' ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD acceptToPost.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'A' ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( OfferId )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_app).

    LOOP AT lt_app INTO DATA(ls_app).
      READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
        ENTITY JobOffer FIELDS ( PositionsFilled )
        WITH VALUE #( ( OfferId = ls_app-OfferId ) ) RESULT DATA(lt_offer).

      IF lt_offer IS NOT INITIAL.
        DATA(lv_filled) = lt_offer[ 1 ]-PositionsFilled + 1.
        MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
          ENTITY JobOffer UPDATE FIELDS ( PositionsFilled )
          WITH VALUE #( ( OfferId = ls_app-OfferId PositionsFilled = lv_filled ) ).
      ENDIF.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.
ENDCLASS.

