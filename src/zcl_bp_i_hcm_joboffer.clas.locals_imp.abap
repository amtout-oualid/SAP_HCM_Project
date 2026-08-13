CLASS lhc_joboffer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
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

  METHOD validateDates.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
        FIELDS ( ValidUntil )
        WITH CORRESPONDING #( keys )
      RESULT DATA(offers).

    LOOP AT offers INTO DATA(offer).
      IF offer-ValidUntil IS NOT INITIAL AND offer-ValidUntil < cl_abap_context_info=>get_system_date( ).
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky = offer-%tky
                        %msg = new_message( id       = '00'
                                            number   = '001'
                                            v1       = 'Valid Until date must be in the future'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateSalary.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
        FIELDS ( SalaryMin SalaryMax )
        WITH CORRESPONDING #( keys )
      RESULT DATA(offers).

    LOOP AT offers INTO DATA(offer).
      IF offer-SalaryMin IS NOT INITIAL AND offer-SalaryMax IS NOT INITIAL
         AND offer-SalaryMin > offer-SalaryMax.
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky = offer-%tky
                        %msg = new_message( id       = '00'
                                            number   = '002'
                                            v1       = 'Salary Min cannot exceed Salary Max'
                                            severity = if_abap_behv_message=>severity-error ) )
               TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD publishOffer.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'P' ) )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    LOOP AT lt_failed-joboffer INTO DATA(ls_failed).
      APPEND CORRESPONDING #( ls_failed ) TO failed-joboffer.
    ENDLOOP.

    LOOP AT lt_reported-joboffer INTO DATA(ls_reported).
      APPEND CORRESPONDING #( ls_reported ) TO reported-joboffer.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD closeOffer.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
        UPDATE FIELDS ( Status )
        WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'C' ) )
      FAILED   DATA(lt_failed)
      REPORTED DATA(lt_reported).

    LOOP AT lt_failed-joboffer INTO DATA(ls_failed).
      APPEND CORRESPONDING #( ls_failed ) TO failed-joboffer.
    ENDLOOP.

    LOOP AT lt_reported-joboffer INTO DATA(ls_reported).
      APPEND CORRESPONDING #( ls_reported ) TO reported-joboffer.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

ENDCLASS.


CLASS lhc_application IMPLEMENTATION.

  METHOD validateCIN.
    " TODO: duplicate-CIN check against zhcm_candidate for the same OfferId
  ENDMETHOD.

  METHOD evaluateWithAI.
    " TODO: call external AI microservice (FastAPI) and update AiMatchScore
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD passToNextStep.
    " TODO: increment CurrentStepOrder, set next PipelineProgress to InProgress, send email
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD rejectCandidate.
    " TODO: set OverallStatus = 'R', insert into ZI_HCM_TalentPool, send rejection email
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD acceptToPost.
    " TODO: set OverallStatus = 'A', increment JobOffer PositionsFilled, send acceptance email
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application
        ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_result).

    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

ENDCLASS.

