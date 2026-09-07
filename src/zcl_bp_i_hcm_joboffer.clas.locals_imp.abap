CLASS lcl_buffer DEFINITION.
  PUBLIC SECTION.
    CLASS-DATA: mt_talentpool TYPE TABLE OF zhcm_talntpool,
                mt_hrmail     TYPE TABLE OF zhcm_hr_mail.
ENDCLASS.

CLASS lcl_buffer IMPLEMENTATION.
ENDCLASS.

CLASS lhc_joboffer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR JobOffer RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR JobOffer RESULT result.

    METHODS publishOffer FOR MODIFY
      IMPORTING keys FOR ACTION JobOffer~publishOffer RESULT result.
    METHODS closeOffer FOR MODIFY
      IMPORTING keys FOR ACTION JobOffer~closeOffer RESULT result.
    METHODS reopenOffer FOR MODIFY
      IMPORTING keys FOR ACTION JobOffer~reopenOffer RESULT result.

    METHODS validateBeforePublish FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validateBeforePublish.
    METHODS validateApplicationDeadline FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validateApplicationDeadline.
    METHODS autoCloseOnDeadline FOR DETERMINE ON SAVE
      IMPORTING keys FOR JobOffer~autoCloseOnDeadline.

    METHODS setDefaultValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR JobOffer~setDefaultValues.

    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validateMandatoryFields.
ENDCLASS.

CLASS lhc_joboffer IMPLEMENTATION.
  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky = key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed
                      %action-publishOffer = if_abap_behv=>auth-allowed
                      %action-closeOffer = if_abap_behv=>auth-allowed
                      %action-reopenOffer = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    result = VALUE #( FOR offer IN lt_offers (
      %tky = offer-%tky
      %action-publishOffer = COND #( WHEN offer-Status = 'D' OR offer-Status = 'C' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-closeOffer   = COND #( WHEN offer-Status = 'P' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-reopenOffer  = COND #( WHEN offer-Status = 'C' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
    ) ).
  ENDMETHOD.

  METHOD publishOffer.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer UPDATE FIELDS ( Status PublishedAt )
      WITH VALUE #( FOR key IN keys (
        %tky = key-%tky
        Status = 'P'
        PublishedAt = cl_abap_context_info=>get_system_time( )
      ) ).

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

  METHOD reopenOffer.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer UPDATE FIELDS ( Status PositionsFilled )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'P' PositionsFilled = 0 ) ).
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
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

  METHOD validateBeforePublish.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( Title Department Status ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    LOOP AT lt_offers INTO DATA(offer).
      IF offer-Status = 'P' AND ( offer-Title IS INITIAL OR offer-Department IS INITIAL ).
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky = offer-%tky
                        %msg = new_message( id = '00' number = '001' v1 = 'Title and Department required to publish' severity = if_abap_behv_message=>severity-error ) ) TO reported-joboffer.
      ELSEIF offer-Status = 'P'.
        SELECT COUNT(*) FROM zhcm_pipe_tmpl WHERE offer_id = @offer-OfferId INTO @DATA(lv_steps).
        IF lv_steps = 0.
          APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
          APPEND VALUE #( %tky = offer-%tky
                          %msg = new_message( id = '00' number = '006' v1 = 'Cannot publish: No pipeline steps defined' severity = if_abap_behv_message=>severity-error ) ) TO reported-joboffer.
        ENDIF.
      ENDIF.
    ENDLOOP.
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

  METHOD setDefaultValues.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( Status CurrencyCode ) WITH CORRESPONDING #( keys ) RESULT DATA(offers).

    " BUG-04 FIX: Only set defaults when Status is initial (new record).
    " Without this WHERE guard, every edit to a published offer resets it back to Draft.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer UPDATE FIELDS ( Status CurrencyCode )
      WITH VALUE #( FOR offer IN offers WHERE ( Status IS INITIAL )
          ( %tky        = offer-%tky
            Status      = 'D'
            CurrencyCode = COND #( WHEN offer-CurrencyCode IS INITIAL THEN 'USD'
                                   ELSE offer-CurrencyCode )
          ) ).
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
ENDCLASS.

CLASS lhc_application DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_features FOR INSTANCE FEATURES IMPORTING keys REQUEST requested_features FOR Application RESULT result.
    METHODS putOnHold FOR MODIFY IMPORTING keys FOR ACTION Application~putOnHold RESULT result.
    METHODS addNote FOR MODIFY IMPORTING keys FOR ACTION Application~addNote RESULT result.
    METHODS rejectCandidate FOR MODIFY IMPORTING keys FOR ACTION Application~rejectCandidate RESULT result.
    METHODS sendMail FOR MODIFY IMPORTING keys FOR ACTION Application~sendMail RESULT result.
    METHODS passToNextStep FOR MODIFY IMPORTING keys FOR ACTION Application~passToNextStep RESULT result.
    METHODS acceptToPost FOR MODIFY IMPORTING keys FOR ACTION Application~acceptToPost RESULT result.
    METHODS evaluateWithAI FOR MODIFY IMPORTING keys FOR ACTION Application~evaluateWithAI RESULT result.
    METHODS preventDuplicateApplication FOR VALIDATE ON SAVE IMPORTING keys FOR Application~preventDuplicateApplication.
ENDCLASS.

CLASS lhc_application IMPLEMENTATION.

  METHOD get_instance_features.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application BY \_Offer
      FIELDS ( OfferId ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( CurrentStepOrder OfferId ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_apps).

    TYPES: BEGIN OF ty_max_step,
             offer_id TYPE sysuuid_x16,
             step_order TYPE int4,
           END OF ty_max_step.
    DATA lt_all_steps TYPE TABLE OF ty_max_step.

    IF lt_apps IS NOT INITIAL.
      SELECT offer_id, step_order
        FROM zhcm_pipe_tmpl
        FOR ALL ENTRIES IN @lt_apps
        WHERE offer_id = @lt_apps-OfferId
        INTO TABLE @lt_all_steps.

      SORT lt_all_steps BY offer_id ASCENDING step_order DESCENDING.
    ENDIF.

    LOOP AT lt_apps INTO DATA(ls_app).
      DATA(lv_max_step) = 0.
      READ TABLE lt_all_steps INTO DATA(ls_max) WITH KEY offer_id = ls_app-OfferId.
      IF sy-subrc = 0.
        lv_max_step = ls_max-step_order.
      ENDIF.

      DATA(lv_can_pass) = COND #( WHEN ls_app-CurrentStepOrder < lv_max_step THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).
      DATA(lv_can_accept) = COND #( WHEN ls_app-CurrentStepOrder = lv_max_step THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled ).

      APPEND VALUE #( %tky = ls_app-%tky
                      %action-passToNextStep = lv_can_pass
                      %action-acceptToPost = lv_can_accept
                    ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD putOnHold.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'H' ) ).
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD addNote.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application CREATE BY \_Progress
      FIELDS ( StepOrder StepName Status Notes )
      WITH VALUE #( FOR key IN keys (
                      %tky = key-%tky
                      %target = VALUE #( (
                         %cid = 'NOTE_' && key-ApplicationId
                         StepOrder = 0
                         StepName = 'HR Note'
                         Status = 'N'
                         Notes = key-%param-NoteText
                      ) )
                  ) ).

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

    " BUG-02 FIX: Loop over keys (which carries %param-RejectionReason per application)
    " instead of lt_apps + keys[ 1 ] which always used the FIRST app's rejection reason.
    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_pool_id) = cl_system_uuid=>create_uuid_x16_static( ).
      " Look up the application data that corresponds to this key
      DATA(ls_app) = VALUE #( lt_apps[ ApplicationId = ls_key-ApplicationId ] DEFAULT VALUE #( ) ).
      APPEND VALUE #(
        client            = sy-mandt
        pool_id           = lv_pool_id
        candidate_id      = ls_app-CandidateId
        original_offer_id = ls_app-OfferId
        ai_score          = ls_app-AiMatchScore
        resume_url        = ls_app-ResumeUrl
        status            = 'A'
        rejection_reason  = ls_key-%param-RejectionReason
      ) TO lcl_buffer=>mt_talentpool.
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
      ) TO lcl_buffer=>mt_hrmail.
    ENDLOOP.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD passToNextStep.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( CurrentStepOrder OfferId )
      WITH CORRESPONDING #( keys ) RESULT DATA(lt_app).

    " Increment CurrentStepOrder for each application
    LOOP AT lt_app ASSIGNING FIELD-SYMBOL(<fs_app>).
      <fs_app>-CurrentStepOrder += 1.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( CurrentStepOrder )
      WITH VALUE #( FOR a IN lt_app ( %tky = a-%tky CurrentStepOrder = a-CurrentStepOrder ) ).

    " BUG-01 & BUG-11 FIX: Update StepOrder properly and fetch StepName for Progress record
    DATA lt_progress_create TYPE TABLE FOR CREATE ZI_HCM_JobOffer\\Application\_Progress.
    LOOP AT keys INTO DATA(ls_key_prog).
      DATA(ls_app_prog) = lt_app[ %tky = ls_key_prog-%tky ].
      DATA(lv_step_name) = CONV string( '' ).

      SELECT SINGLE step_name FROM zhcm_pipe_tmpl
        WHERE offer_id = @ls_app_prog-OfferId AND step_order = @ls_app_prog-CurrentStepOrder
        INTO @lv_step_name.

      APPEND VALUE #( %tky = ls_key_prog-%tky
                      %target = VALUE #( ( %cid      = 'PROG_' && ls_key_prog-ApplicationId
                                           StepOrder = ls_app_prog-CurrentStepOrder
                                           StepName  = lv_step_name
                                           Status    = 'C' ) )
                    ) TO lt_progress_create.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application CREATE BY \_Progress
      FIELDS ( StepOrder StepName Status )
      WITH lt_progress_create.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD acceptToPost.
    " Update the overall status to Accepted (A) AND save the HR Notes from the popup
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus InternalNotes )
      WITH VALUE #( FOR key IN keys (
          %tky = key-%tky
          OverallStatus = 'A'
          InternalNotes = key-%param-Notes
      ) ).

    " Close Job Offer if PositionsFilled reaches PositionsNeeded
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application BY \_Offer ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    LOOP AT lt_offers INTO DATA(ls_offer).
      ls_offer-PositionsFilled += 1.
      IF ls_offer-PositionsFilled >= ls_offer-PositionsNeeded.
        " BUG-03 FIX: Use 'C' (the correct closed code) instead of 'Closed' (a string).
        " Using 'Closed' stores corrupt data — the CDS view renders unknown status and
        " reopenOffer's feature check (Status = 'C') never matches.
        ls_offer-Status = 'C'.
      ENDIF.
      MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
        ENTITY JobOffer UPDATE FIELDS ( PositionsFilled Status )
        WITH VALUE #( ( %tky = ls_offer-%tky PositionsFilled = ls_offer-PositionsFilled Status = ls_offer-Status ) ).
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

  METHOD preventDuplicateApplication.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( CandidateId OfferId ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_apps).
    LOOP AT lt_apps INTO DATA(app).
      " BUG-07 FIX: SELECT COUNT(*) always sets sy-subrc = 0 regardless of row count.
      " Use INTO @DATA(lv_count) and check lv_count > 0 instead.
      SELECT COUNT(*) FROM zhcm_applicatn
        WHERE candidate_id  = @app-CandidateId
          AND offer_id      = @app-OfferId
          AND application_id <> @app-ApplicationId
        INTO @DATA(lv_count).
      IF lv_count > 0.
        APPEND VALUE #( %tky = app-%tky ) TO failed-application.
        APPEND VALUE #( %tky = app-%tky
                        %msg = new_message( id = '00' number = '003' v1 = 'Candidate already applied!' severity = if_abap_behv_message=>severity-error ) ) TO reported-application.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_pipetmpl DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS validateMandatorySteps FOR VALIDATE ON SAVE IMPORTING keys FOR PipeTmpl~validateMandatorySteps.
ENDCLASS.

CLASS lhc_pipetmpl IMPLEMENTATION.

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

CLASS lsc_joboffer DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_joboffer IMPLEMENTATION.
  METHOD save_modified.
    IF lcl_buffer=>mt_talentpool IS NOT INITIAL.
      INSERT zhcm_talntpool FROM TABLE @lcl_buffer=>mt_talentpool.
    ENDIF.
    IF lcl_buffer=>mt_hrmail IS NOT INITIAL.
      INSERT zhcm_hr_mail FROM TABLE @lcl_buffer=>mt_hrmail.

      " F-04 FIX: Actual ABAP Email logic using cl_bcs_mail_message for ABAP Cloud
      LOOP AT lcl_buffer=>mt_hrmail INTO DATA(ls_mail).
        TRY.
            DATA(lo_mail) = cl_bcs_mail_message=>create_instance( ).
            lo_mail->set_sender( 'no-reply@company.com' ).
            lo_mail->set_subject( CONV #( ls_mail-subject ) ).
            lo_mail->set_main( cl_bcs_mail_textpart=>create_text_plain( CONV #( ls_mail-body ) ) ).

            " Find Candidate Email
            SELECT SINGLE candidate_id FROM zhcm_applicatn WHERE application_id = @ls_mail-application_id INTO @DATA(lv_cand_id).
            IF sy-subrc = 0.
              SELECT SINGLE email FROM zhcm_candidate WHERE candidate_id = @lv_cand_id INTO @DATA(lv_email).
              IF sy-subrc = 0 AND lv_email IS NOT INITIAL.
                lo_mail->add_recipient( CONV #( lv_email ) ).
                lo_mail->send( ).
              ENDIF.
            ENDIF.
          CATCH cx_bcs_mail INTO DATA(lx_mail).
            " Silently ignore so transaction does not fail
        ENDTRY.
      ENDLOOP.
    ENDIF.
  ENDMETHOD.

  METHOD cleanup_finalize.
    CLEAR lcl_buffer=>mt_talentpool.
    CLEAR lcl_buffer=>mt_hrmail.
  ENDMETHOD.
ENDCLASS.

