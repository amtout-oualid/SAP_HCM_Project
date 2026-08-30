CLASS lcl_buffer DEFINITION.
  PUBLIC SECTION.
    CLASS-DATA: mt_pipe_prog TYPE TABLE OF zhcm_pipe_prog,
                mt_talntpool TYPE TABLE OF zhcm_talntpool,
                mt_hr_mail   TYPE TABLE OF zhcm_hr_mail.
ENDCLASS.
CLASS lcl_buffer IMPLEMENTATION.
ENDCLASS.

CLASS lsc_ZI_HCM_JOBOFFER DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_HCM_JOBOFFER IMPLEMENTATION.
  METHOD save_modified.
    IF lcl_buffer=>mt_pipe_prog IS NOT INITIAL.
      INSERT zhcm_pipe_prog FROM TABLE @lcl_buffer=>mt_pipe_prog.
      CLEAR lcl_buffer=>mt_pipe_prog.
    ENDIF.
    IF lcl_buffer=>mt_talntpool IS NOT INITIAL.
      INSERT zhcm_talntpool FROM TABLE @lcl_buffer=>mt_talntpool.
      CLEAR lcl_buffer=>mt_talntpool.
    ENDIF.
    IF lcl_buffer=>mt_hr_mail IS NOT INITIAL.
      INSERT zhcm_hr_mail FROM TABLE @lcl_buffer=>mt_hr_mail.
      CLEAR lcl_buffer=>mt_hr_mail.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_JobOffer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR JobOffer RESULT result.

    METHODS autoCloseOnDeadline FOR DETERMINE ON SAVE
      IMPORTING keys FOR JobOffer~autoCloseOnDeadline.

    METHODS setDefaultValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR JobOffer~setDefaultValues.

    METHODS validateApplicationDeadline FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validateApplicationDeadline.

    METHODS validateBeforePublish FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validateBeforePublish.

    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validateMandatoryFields.

    METHODS closeOffer FOR MODIFY
      IMPORTING keys FOR ACTION JobOffer~closeOffer RESULT result.

    METHODS publishOffer FOR MODIFY
      IMPORTING keys FOR ACTION JobOffer~publishOffer RESULT result.

    METHODS reopenOffer FOR MODIFY
      IMPORTING keys FOR ACTION JobOffer~reopenOffer RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR JobOffer RESULT result.

ENDCLASS.

CLASS lhc_JobOffer IMPLEMENTATION.

  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky = ls_key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed
                      %action-publishOffer = if_abap_behv=>auth-allowed
                      %action-closeOffer = if_abap_behv=>auth-allowed
                      %action-reopenOffer = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD autoCloseOnDeadline.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( AppDeadline Status ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).
    LOOP AT lt_offers INTO DATA(offer).
      IF offer-AppDeadline IS NOT INITIAL AND offer-AppDeadline < lv_today AND offer-Status = 'P'.
        MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
          ENTITY JobOffer UPDATE FIELDS ( Status )
          WITH VALUE #( ( %tky = offer-%tky Status = 'C' ) ).
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD setDefaultValues.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
      FIELDS ( Status CurrencyCode ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_offers).

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
      UPDATE
      FIELDS ( Status CurrencyCode )
      WITH VALUE #( FOR offer IN lt_offers (
                      %tky = offer-%tky
                      Status = COND #( WHEN offer-Status IS INITIAL THEN 'D' ELSE offer-Status )
                      CurrencyCode = COND #( WHEN offer-CurrencyCode IS INITIAL THEN 'USD' ELSE offer-CurrencyCode )
                  ) )
      REPORTED DATA(lt_reported).

    reported = CORRESPONDING #( DEEP lt_reported ).
  ENDMETHOD.

  METHOD validateApplicationDeadline.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( AppDeadline ValidUntil ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).
    LOOP AT lt_offers INTO DATA(offer).
      IF offer-AppDeadline > offer-ValidUntil AND offer-ValidUntil IS NOT INITIAL.
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky = offer-%tky
                        %msg = new_message( id = '00' number = '002' v1 = 'App Deadline must be before Valid Until' severity = if_abap_behv_message=>severity-error ) ) TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateBeforePublish.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( Title Department Status ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    LOOP AT lt_offers INTO DATA(offer).
      IF offer-Status = 'P' AND ( offer-Title IS INITIAL OR offer-Department IS INITIAL ).
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky = offer-%tky
                        %msg = new_message( id = '00' number = '001' v1 = 'Title and Department required to publish' severity = if_abap_behv_message=>severity-error ) ) TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateMandatoryFields.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( Title Department ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    LOOP AT lt_offers INTO DATA(offer).
      IF offer-Title IS INITIAL OR offer-Department IS INITIAL.
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky = offer-%tky
                        %msg = new_message( id = '00' number = '004' v1 = 'Title and Department are required!' severity = if_abap_behv_message=>severity-error )
                        %element-Title = if_abap_behv=>mk-on
                        %element-Department = if_abap_behv=>mk-on ) TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD closeOffer.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
      UPDATE
      FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'C' ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_offers).

    result = VALUE #( FOR offer IN lt_offers ( %tky = offer-%tky %param = offer ) ).
  ENDMETHOD.

  METHOD publishOffer.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
      UPDATE
      FIELDS ( Status PublishedAt )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'P' PublishedAt = cl_abap_context_info=>get_system_time( ) ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_offers).

    result = VALUE #( FOR offer IN lt_offers ( %tky = offer-%tky %param = offer ) ).
  ENDMETHOD.

  METHOD reopenOffer.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
      UPDATE
      FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'P' ) )
      FAILED failed
      REPORTED reported.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
      ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_offers).

    result = VALUE #( FOR offer IN lt_offers ( %tky = offer-%tky %param = offer ) ).
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer
      FIELDS ( Status ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_offers).

    result = VALUE #( FOR offer IN lt_offers (
      %tky = offer-%tky
      %action-publishOffer = COND #( WHEN offer-Status = 'D' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-closeOffer = COND #( WHEN offer-Status = 'P' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-reopenOffer = COND #( WHEN offer-Status = 'C' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
    ) ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_Application DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Application RESULT result.

    METHODS preventDuplicateApplication FOR VALIDATE ON SAVE
      IMPORTING keys FOR Application~preventDuplicateApplication.

    METHODS acceptToPost FOR MODIFY
      IMPORTING keys FOR ACTION Application~acceptToPost RESULT result.

    METHODS addNote FOR MODIFY
      IMPORTING keys FOR ACTION Application~addNote RESULT result.

    METHODS evaluateWithAI FOR MODIFY
      IMPORTING keys FOR ACTION Application~evaluateWithAI RESULT result.

    METHODS passToNextStep FOR MODIFY
      IMPORTING keys FOR ACTION Application~passToNextStep RESULT result.

    METHODS putOnHold FOR MODIFY
      IMPORTING keys FOR ACTION Application~putOnHold RESULT result.

    METHODS rejectCandidate FOR MODIFY
      IMPORTING keys FOR ACTION Application~rejectCandidate RESULT result.

    METHODS sendMail FOR MODIFY
      IMPORTING keys FOR ACTION Application~sendMail RESULT result.
ENDCLASS.

CLASS lhc_Application IMPLEMENTATION.

  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #( %tky = ls_key-%tky
                      %action-evaluateWithAI = if_abap_behv=>auth-allowed
                      %action-passToNextStep = if_abap_behv=>auth-allowed
                      %action-acceptToPost = if_abap_behv=>auth-allowed
                      %action-putOnHold = if_abap_behv=>auth-allowed
                      %action-addNote = if_abap_behv=>auth-allowed
                      %action-rejectCandidate = if_abap_behv=>auth-allowed
                      %action-sendMail = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD preventDuplicateApplication.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( CandidateId OfferId ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_apps).

    LOOP AT lt_apps INTO DATA(app).
      SELECT COUNT(*) FROM zhcm_applicatn WHERE candidate_id = @app-CandidateId AND offer_id = @app-OfferId AND application_id <> @app-ApplicationId.
      IF sy-subrc = 0.
        APPEND VALUE #( %tky = app-%tky ) TO failed-application.
        APPEND VALUE #( %tky = app-%tky
                        %msg = new_message( id = '00' number = '003' v1 = 'Candidate already applied!' severity = if_abap_behv_message=>severity-error ) ) TO reported-application.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD acceptToPost.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'A' ) ).
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD addNote.
    LOOP AT keys INTO DATA(key).
      DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client = sy-mandt
        progress_id = lv_uuid
        application_id = key-ApplicationId
        step_name = 'HR Note'
        status = 'N'
        notes = key-%param-NoteText
      ) TO lcl_buffer=>mt_pipe_prog.
    ENDLOOP.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD evaluateWithAI.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( AiMatchScore )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky AiMatchScore = 75 ) ).
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

    LOOP AT keys INTO DATA(key).
       DATA(lv_prog_id) = cl_system_uuid=>create_uuid_x16_static( ).
       APPEND VALUE #(
         client = sy-mandt
         progress_id = lv_prog_id
         application_id = key-ApplicationId
         step_order = lt_app[ 1 ]-CurrentStepOrder
         status = 'C'
       ) TO lcl_buffer=>mt_pipe_prog.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD putOnHold.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'H' ) ).
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD rejectCandidate.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus RejectionReason )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'R' RejectionReason = key-%param-RejectionReason ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( CandidateId OfferId AiMatchScore ResumeUrl ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_apps).

    LOOP AT lt_apps INTO DATA(app).
      DATA(lv_pool_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client = sy-mandt
        pool_id = lv_pool_id
        candidate_id = app-CandidateId
        original_offer_id = app-OfferId
        ai_score = app-AiMatchScore
        resume_url = app-ResumeUrl
        status = 'A'
        rejection_reason = keys[ 1 ]-%param-RejectionReason
      ) TO lcl_buffer=>mt_talntpool.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD sendMail.
    LOOP AT keys INTO DATA(key).
      DATA(lv_mail_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client = sy-mandt
        mail_id = lv_mail_id
        application_id = key-ApplicationId
        mail_type = key-%param-MailType
        subject = key-%param-Subject
        body = key-%param-Body
      ) TO lcl_buffer=>mt_hr_mail.
    ENDLOOP.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

ENDCLASS.

CLASS lhc_PipeTmpl DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateMandatorySteps FOR VALIDATE ON SAVE
      IMPORTING keys FOR PipeTmpl~validateMandatorySteps.
ENDCLASS.

CLASS lhc_PipeTmpl IMPLEMENTATION.

  METHOD validateMandatorySteps.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY PipeTmpl FIELDS ( StepName StepType StepOrder ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_steps).

    LOOP AT lt_steps INTO DATA(step).
      IF step-StepName IS INITIAL OR step-StepType IS INITIAL OR step-StepOrder IS INITIAL.
        APPEND VALUE #( %tky = step-%tky ) TO failed-pipetmpl.
        APPEND VALUE #( %tky = step-%tky
                        %msg = new_message( id = '00' number = '005' v1 = 'Step Name, Type, and Order are required!' severity = if_abap_behv_message=>severity-error )
                        %element-StepName = if_abap_behv=>mk-on
                        %element-StepType = if_abap_behv=>mk-on ) TO reported-pipetmpl.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

ENDCLASS.

