"! Records that the save sequence writes for other objects (buffer-then-save)
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-DATA: mt_talentpool TYPE TABLE OF zhcm_talntpool,
                mt_hrmail     TYPE TABLE OF zhcm_hr_mail,
                mt_onboarding TYPE TABLE OF zhcm_onboardng.

    CLASS-METHODS new_uuid RETURNING VALUE(rv_uuid) TYPE sysuuid_x16.
    CLASS-METHODS reset.
ENDCLASS.

CLASS lcl_buffer IMPLEMENTATION.
  METHOD new_uuid.
    TRY.
        rv_uuid = cl_system_uuid=>create_uuid_x16_static( ).
      CATCH cx_uuid_error.
        CLEAR rv_uuid.
    ENDTRY.
  ENDMETHOD.

  METHOD reset.
    CLEAR: mt_talentpool, mt_hrmail, mt_onboarding.
  ENDMETHOD.
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
    METHODS validateMandatoryFields FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validateMandatoryFields.
    METHODS validatePositionVacant FOR VALIDATE ON SAVE
      IMPORTING keys FOR JobOffer~validatePositionVacant.

    METHODS autoCloseOnDeadline FOR DETERMINE ON SAVE
      IMPORTING keys FOR JobOffer~autoCloseOnDeadline.
    METHODS setDefaultValues FOR DETERMINE ON MODIFY
      IMPORTING keys FOR JobOffer~setDefaultValues.
    METHODS deriveFromPosition FOR DETERMINE ON MODIFY
      IMPORTING keys FOR JobOffer~deriveFromPosition.
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
      ENTITY JobOffer FIELDS ( Status PositionsNeeded PositionsFilled ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_offers).

    " Publish: first publication of a draft offer. Reopen: a closed offer that still has open positions.
    result = VALUE #( FOR offer IN lt_offers (
      %tky = offer-%tky
      %action-publishOffer = COND #( WHEN offer-Status = 'D' OR offer-Status IS INITIAL
                                     THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-closeOffer   = COND #( WHEN offer-Status = 'P'
                                     THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-reopenOffer  = COND #( WHEN offer-Status = 'C' AND offer-PositionsFilled < offer-PositionsNeeded
                                     THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
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
    " The filled positions are kept; HR raises Positions Needed before reopening a full offer
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'P' ) ).
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
      ENTITY JobOffer FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    " Steps are read from the transactional buffer, so new (unsaved) steps are counted too
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer BY \_Steps FIELDS ( OfferId ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_steps).

    LOOP AT lt_offers INTO DATA(offer).
      APPEND VALUE #( %tky = offer-%tky %state_area = 'VALIDATE_PUBLISH' ) TO reported-joboffer.

      IF offer-Status = 'P' AND NOT line_exists( lt_steps[ OfferId = offer-OfferId %is_draft = offer-%is_draft ] ).
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky        = offer-%tky
                        %state_area = 'VALIDATE_PUBLISH'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'Cannot publish: define at least one pipeline step.' ) ) TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateApplicationDeadline.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( AppDeadline ValidUntil ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).
    LOOP AT lt_offers INTO DATA(offer).
      APPEND VALUE #( %tky = offer-%tky %state_area = 'VALIDATE_DEADLINE' ) TO reported-joboffer.

      IF offer-AppDeadline > offer-ValidUntil AND offer-ValidUntil IS NOT INITIAL.
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky                 = offer-%tky
                        %state_area          = 'VALIDATE_DEADLINE'
                        %msg                 = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = 'The application deadline must be before the Valid Until date.' )
                        %element-AppDeadline = if_abap_behv=>mk-on ) TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validateMandatoryFields.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( Title Department ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    LOOP AT lt_offers INTO DATA(offer).
      APPEND VALUE #( %tky = offer-%tky %state_area = 'VALIDATE_MANDATORY' ) TO reported-joboffer.

      IF offer-Title IS INITIAL OR offer-Department IS INITIAL.
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky        = offer-%tky
                        %state_area = 'VALIDATE_MANDATORY'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'Title and Department are required.' )
                        %element-Title = if_abap_behv=>mk-on
                        %element-Department = if_abap_behv=>mk-on ) TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD validatePositionVacant.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( PositionId ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    LOOP AT lt_offers INTO DATA(offer).
      APPEND VALUE #( %tky = offer-%tky %state_area = 'VALIDATE_POSITION' ) TO reported-joboffer.

      IF offer-PositionId IS INITIAL.
        CONTINUE.
      ENDIF.

      " The organizational management BO also sees positions created in the same transaction
      READ ENTITIES OF ZI_HCM_OrgUnit
        ENTITY Position FIELDS ( Status ) WITH VALUE #( ( PositionId = offer-PositionId ) )
        RESULT DATA(lt_positions).

      IF NOT line_exists( lt_positions[ Status = 'V' ] ).
        APPEND VALUE #( %tky = offer-%tky ) TO failed-joboffer.
        APPEND VALUE #( %tky                = offer-%tky
                        %state_area         = 'VALIDATE_POSITION'
                        %msg                = new_message_with_text(
                                                severity = if_abap_behv_message=>severity-error
                                                text     = 'The selected position is not vacant. Choose a vacant position.' )
                        %element-PositionId = if_abap_behv=>mk-on ) TO reported-joboffer.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD setDefaultValues.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( Status CurrencyCode PositionsNeeded ) WITH CORRESPONDING #( keys ) RESULT DATA(offers).

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer UPDATE FIELDS ( Status CurrencyCode PositionsNeeded )
      WITH VALUE #( FOR offer IN offers
          ( %tky            = offer-%tky
            Status          = COND #( WHEN offer-Status IS INITIAL THEN 'D' ELSE offer-Status )
            CurrencyCode    = COND #( WHEN offer-CurrencyCode IS INITIAL THEN 'USD' ELSE offer-CurrencyCode )
            PositionsNeeded = COND #( WHEN offer-PositionsNeeded <= 0 THEN 1 ELSE offer-PositionsNeeded )
          ) ).
  ENDMETHOD.

  METHOD deriveFromPosition.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( PositionId Title Department ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    DATA lt_update TYPE TABLE FOR UPDATE ZI_HCM_JobOffer\\JobOffer.

    LOOP AT lt_offers INTO DATA(offer) WHERE PositionId IS NOT INITIAL.
      READ ENTITIES OF ZI_HCM_OrgUnit
        ENTITY Position FIELDS ( JobTitle ) WITH VALUE #( ( PositionId = offer-PositionId ) )
        RESULT DATA(lt_positions).
      IF lt_positions IS INITIAL.
        CONTINUE.
      ENDIF.

      READ ENTITIES OF ZI_HCM_OrgUnit
        ENTITY Position BY \_OrgUnit FIELDS ( UnitName ) WITH VALUE #( ( PositionId = offer-PositionId ) )
        RESULT DATA(lt_units).

      " Department = organizational unit of the position; the title is proposed if still empty
      APPEND VALUE #( %tky       = offer-%tky
                      Department = COND #( WHEN lt_units IS NOT INITIAL THEN lt_units[ 1 ]-UnitName
                                           ELSE offer-Department )
                      Title      = COND #( WHEN offer-Title IS INITIAL THEN lt_positions[ 1 ]-JobTitle
                                           ELSE offer-Title ) ) TO lt_update.
    ENDLOOP.

    IF lt_update IS NOT INITIAL.
      MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
        ENTITY JobOffer UPDATE FIELDS ( Department Title ) WITH lt_update.
    ENDIF.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_application DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES tt_applications TYPE TABLE FOR READ RESULT ZI_HCM_JobOffer\\Application.
    TYPES tt_offers       TYPE TABLE FOR READ RESULT ZI_HCM_JobOffer\\JobOffer.
    TYPES tt_steps        TYPE TABLE FOR READ RESULT ZI_HCM_JobOffer\\JobOffer\_Steps.

    METHODS get_instance_features FOR INSTANCE FEATURES IMPORTING keys REQUEST requested_features FOR Application RESULT result.
    METHODS setApplicationDefaults FOR DETERMINE ON MODIFY IMPORTING keys FOR Application~setApplicationDefaults.
    METHODS putOnHold FOR MODIFY IMPORTING keys FOR ACTION Application~putOnHold RESULT result.
    METHODS addNote FOR MODIFY IMPORTING keys FOR ACTION Application~addNote RESULT result.
    METHODS rejectCandidate FOR MODIFY IMPORTING keys FOR ACTION Application~rejectCandidate RESULT result.
    METHODS sendMail FOR MODIFY IMPORTING keys FOR ACTION Application~sendMail RESULT result.
    METHODS passToNextStep FOR MODIFY IMPORTING keys FOR ACTION Application~passToNextStep RESULT result.
    METHODS acceptToPost FOR MODIFY IMPORTING keys FOR ACTION Application~acceptToPost RESULT result.
    METHODS evaluateWithAI FOR MODIFY IMPORTING keys FOR ACTION Application~evaluateWithAI RESULT result.
    METHODS setAIEvaluation FOR MODIFY IMPORTING keys FOR ACTION Application~setAIEvaluation RESULT result.
    METHODS preventDuplicateApplication FOR VALIDATE ON SAVE IMPORTING keys FOR Application~preventDuplicateApplication.

    "! Parent job offers of the applications (one entry per offer)
    METHODS read_offers IMPORTING it_apps TYPE tt_applications RETURNING VALUE(rt_offers) TYPE tt_offers.
    "! Pipeline steps of the parent job offers
    METHODS read_steps IMPORTING it_apps TYPE tt_applications RETURNING VALUE(rt_steps) TYPE tt_steps.
ENDCLASS.

CLASS lhc_application IMPLEMENTATION.

  METHOD read_offers.
    DATA lt_keys TYPE TABLE FOR READ IMPORT ZI_HCM_JobOffer\\JobOffer.

    LOOP AT it_apps INTO DATA(ls_app).
      IF NOT line_exists( lt_keys[ OfferId = ls_app-OfferId %is_draft = ls_app-%is_draft ] ).
        APPEND VALUE #( OfferId = ls_app-OfferId %is_draft = ls_app-%is_draft ) TO lt_keys.
      ENDIF.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer ALL FIELDS WITH lt_keys
      RESULT rt_offers.
  ENDMETHOD.

  METHOD read_steps.
    DATA lt_keys TYPE TABLE FOR READ IMPORT ZI_HCM_JobOffer\\JobOffer\_Steps.

    LOOP AT it_apps INTO DATA(ls_app).
      IF NOT line_exists( lt_keys[ OfferId = ls_app-OfferId %is_draft = ls_app-%is_draft ] ).
        APPEND VALUE #( OfferId = ls_app-OfferId %is_draft = ls_app-%is_draft ) TO lt_keys.
      ENDIF.
    ENDLOOP.
    IF lt_keys IS INITIAL.
      RETURN.
    ENDIF.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer BY \_Steps FIELDS ( OfferId StepOrder StepName ) WITH lt_keys
      RESULT rt_steps.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( OfferId OverallStatus CurrentStepOrder ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_apps).

    DATA(lt_offers) = read_offers( lt_apps ).
    DATA(lt_steps)  = read_steps( lt_apps ).

    LOOP AT lt_apps INTO DATA(ls_app).
      " Last step of the offer's pipeline (read from the buffer, so drafts and new steps count)
      DATA(lv_max_step) = 0.
      LOOP AT lt_steps INTO DATA(ls_step) WHERE OfferId = ls_app-OfferId AND %is_draft = ls_app-%is_draft.
        lv_max_step = nmax( val1 = lv_max_step val2 = ls_step-StepOrder ).
      ENDLOOP.

      " Pipeline actions run on the saved application only (display mode), never on a draft
      DATA(lv_active)     = xsdbool( ls_app-%is_draft = if_abap_behv=>mk-off ).
      DATA(lv_in_process) = xsdbool( ls_app-OverallStatus = 'N' OR ls_app-OverallStatus = 'H' OR ls_app-OverallStatus IS INITIAL ).
      DATA(lv_offer_open) = xsdbool( line_exists( lt_offers[ OfferId = ls_app-OfferId %is_draft = ls_app-%is_draft Status = 'P' ] ) ).

      APPEND VALUE #(
        %tky                    = ls_app-%tky
        %delete                 = COND #( WHEN ls_app-OverallStatus = 'A'
                                          THEN if_abap_behv=>fc-o-disabled ELSE if_abap_behv=>fc-o-enabled )
        %action-evaluateWithAI  = COND #( WHEN lv_active = abap_true AND lv_in_process = abap_true
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-passToNextStep  = COND #( WHEN lv_active = abap_true AND lv_in_process = abap_true
                                               AND ls_app-CurrentStepOrder < lv_max_step
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-acceptToPost    = COND #( WHEN lv_active = abap_true AND lv_in_process = abap_true AND lv_offer_open = abap_true
                                               AND lv_max_step > 0 AND ls_app-CurrentStepOrder >= lv_max_step
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-putOnHold       = COND #( WHEN lv_active = abap_true
                                               AND ( ls_app-OverallStatus = 'N' OR ls_app-OverallStatus IS INITIAL )
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-rejectCandidate = COND #( WHEN lv_active = abap_true AND lv_in_process = abap_true
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-sendMail        = COND #( WHEN lv_active = abap_true
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
        %action-addNote         = if_abap_behv=>fc-o-enabled
      ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD setApplicationDefaults.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( OverallStatus CurrentStepOrder ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_apps).

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus CurrentStepOrder )
      WITH VALUE #( FOR app IN lt_apps
                    ( %tky             = app-%tky
                      OverallStatus    = COND #( WHEN app-OverallStatus IS INITIAL THEN 'N' ELSE app-OverallStatus )
                      CurrentStepOrder = COND #( WHEN app-CurrentStepOrder <= 0 THEN 1 ELSE app-CurrentStepOrder ) ) ).
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
    GET TIME STAMP FIELD DATA(lv_now).

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application CREATE BY \_Progress
      FIELDS ( StepOrder StepName Status Notes CompletedAt )
      WITH VALUE #( FOR key IN keys (
                      %tky = key-%tky
                      %target = VALUE #( (
                         %cid        = |NOTE_{ key-ApplicationId }|
                         %is_draft   = key-%is_draft
                         StepOrder   = 0
                         StepName    = 'HR Note'
                         Status      = 'N'
                         Notes       = substring( val = key-%param-NoteText
                                                  len = nmin( val1 = strlen( key-%param-NoteText ) val2 = 500 ) )
                         CompletedAt = lv_now
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
      ENTITY Application FIELDS ( CandidateId OfferId AiMatchScore ResumeUrl ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_apps).

    GET TIME STAMP FIELD DATA(lv_now).
    DATA ls_candidate TYPE zhcm_candidate.
    DATA ls_offer     TYPE zhcm_joboffer.

    " The rejected candidate is kept in the talent pool (inserted in the save sequence)
    LOOP AT lt_apps INTO DATA(ls_app).
      CLEAR: ls_candidate, ls_offer.
      SELECT SINGLE * FROM zhcm_candidate WHERE candidate_id = @ls_app-CandidateId INTO @ls_candidate.
      SELECT SINGLE * FROM zhcm_joboffer  WHERE offer_id     = @ls_app-OfferId     INTO @ls_offer.

      DATA(ls_key) = keys[ %tky = ls_app-%tky ].

      APPEND VALUE #(
        pool_id           = lcl_buffer=>new_uuid( )
        candidate_id      = ls_app-CandidateId
        original_offer_id = ls_app-OfferId
        candidate_name    = condense( |{ ls_candidate-first_name } { ls_candidate-last_name }| )
        candidate_email   = ls_candidate-email
        resume_url        = ls_app-ResumeUrl
        ai_score          = ls_app-AiMatchScore
        skills            = ls_offer-required_skills
        status            = 'A'
        added_at          = lv_now
        notes             = |Applied for: { ls_offer-title }|
        rejection_reason  = ls_key-%param-RejectionReason
        last_changed_at   = lv_now
      ) TO lcl_buffer=>mt_talentpool.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD sendMail.
    GET TIME STAMP FIELD DATA(lv_now).

    LOOP AT keys INTO DATA(key).
      APPEND VALUE #(
        mail_id        = lcl_buffer=>new_uuid( )
        application_id = key-ApplicationId
        mail_type      = key-%param-MailType
        subject        = key-%param-Subject
        body           = key-%param-Body
        sent_at        = lv_now
        sent_by        = sy-uname
      ) TO lcl_buffer=>mt_hrmail.
    ENDLOOP.

    " Touch the application so that the save sequence (which sends the mail) runs for this request
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( LocalLastChangedAt )
      WITH VALUE #( FOR k IN keys ( %tky = k-%tky LocalLastChangedAt = lv_now ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD passToNextStep.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( OfferId CurrentStepOrder ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_apps).

    DATA(lt_steps) = read_steps( lt_apps ).
    GET TIME STAMP FIELD DATA(lv_now).

    DATA lt_app_update TYPE TABLE FOR UPDATE ZI_HCM_JobOffer\\Application.
    DATA lt_progress   TYPE TABLE FOR CREATE ZI_HCM_JobOffer\\Application\_Progress.

    LOOP AT lt_apps INTO DATA(ls_app).
      " The current step is recorded as completed, then the candidate moves to the next step
      DATA(lv_step_name) = CONV zhcm_pipe_tmpl-step_name( '' ).
      LOOP AT lt_steps INTO DATA(ls_step) WHERE OfferId   = ls_app-OfferId
                                             AND %is_draft = ls_app-%is_draft
                                             AND StepOrder = ls_app-CurrentStepOrder.
        lv_step_name = ls_step-StepName.
      ENDLOOP.

      APPEND VALUE #( %tky             = ls_app-%tky
                      CurrentStepOrder = ls_app-CurrentStepOrder + 1
                      OverallStatus    = 'N' ) TO lt_app_update.

      APPEND VALUE #( %tky    = ls_app-%tky
                      %target = VALUE #( ( %cid        = |PROG_{ ls_app-ApplicationId }|
                                           %is_draft   = ls_app-%is_draft
                                           StepOrder   = ls_app-CurrentStepOrder
                                           StepName    = lv_step_name
                                           Status      = 'C'
                                           CompletedAt = lv_now ) ) ) TO lt_progress.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( CurrentStepOrder OverallStatus ) WITH lt_app_update.

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application CREATE BY \_Progress
      FIELDS ( StepOrder StepName Status CompletedAt ) WITH lt_progress.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD acceptToPost.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( OfferId CandidateId CurrentStepOrder InternalNotes ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_apps).

    DATA(lt_offers) = read_offers( lt_apps ).
    DATA(lt_steps)  = read_steps( lt_apps ).
    DATA(lv_today)  = cl_abap_context_info=>get_system_date( ).
    GET TIME STAMP FIELD DATA(lv_now).

    DATA lt_app_update TYPE TABLE FOR UPDATE ZI_HCM_JobOffer\\Application.
    DATA lt_progress   TYPE TABLE FOR CREATE ZI_HCM_JobOffer\\Application\_Progress.
    DATA ls_candidate  TYPE zhcm_candidate.
    DATA lv_form_exists TYPE abap_bool.

    LOOP AT lt_apps INTO DATA(ls_app).
      DATA(ls_key) = keys[ %tky = ls_app-%tky ].

      " 1. Application accepted; the hire details are kept in the HR notes
      DATA(lv_notes) = |Accepted on { lv_today DATE = ISO }.|.
      IF ls_key-%param-StartDate IS NOT INITIAL.
        lv_notes = |{ lv_notes } Start date: { ls_key-%param-StartDate DATE = ISO }.|.
      ENDIF.
      IF ls_key-%param-OfferedSalary IS NOT INITIAL.
        lv_notes = |{ lv_notes } Offered salary: { ls_key-%param-OfferedSalary }.|.
      ENDIF.
      IF ls_key-%param-Notes IS NOT INITIAL.
        lv_notes = |{ lv_notes } { ls_key-%param-Notes }|.
      ENDIF.
      IF ls_app-InternalNotes IS NOT INITIAL.
        lv_notes = |{ ls_app-InternalNotes } / { lv_notes }|.
      ENDIF.
      lv_notes = substring( val = lv_notes len = nmin( val1 = strlen( lv_notes ) val2 = 1000 ) ).

      APPEND VALUE #( %tky          = ls_app-%tky
                      OverallStatus = 'A'
                      InternalNotes = lv_notes ) TO lt_app_update.

      " 2. The last pipeline step is recorded as completed
      DATA(lv_step_name) = CONV zhcm_pipe_tmpl-step_name( '' ).
      LOOP AT lt_steps INTO DATA(ls_step) WHERE OfferId   = ls_app-OfferId
                                             AND %is_draft = ls_app-%is_draft
                                             AND StepOrder = ls_app-CurrentStepOrder.
        lv_step_name = ls_step-StepName.
      ENDLOOP.
      APPEND VALUE #( %tky    = ls_app-%tky
                      %target = VALUE #( ( %cid        = |ACC_{ ls_app-ApplicationId }|
                                           %is_draft   = ls_app-%is_draft
                                           StepOrder   = ls_app-CurrentStepOrder
                                           StepName    = lv_step_name
                                           Status      = 'C'
                                           CompletedAt = lv_now ) ) ) TO lt_progress.

      " 3. One more position of the offer is filled; the offer closes when all positions are filled
      READ TABLE lt_offers ASSIGNING FIELD-SYMBOL(<ls_offer>)
           WITH KEY OfferId = ls_app-OfferId %is_draft = ls_app-%is_draft.
      IF sy-subrc = 0.
        <ls_offer>-PositionsFilled += 1.
        IF <ls_offer>-PositionsFilled >= <ls_offer>-PositionsNeeded.
          <ls_offer>-Status = 'C'.
        ENDIF.
      ENDIF.

      " 4. The onboarding form is prepared for the candidate (inserted in the save sequence)
      CLEAR lv_form_exists.
      SELECT SINGLE @abap_true FROM zhcm_onboardng
        WHERE application_id = @ls_app-ApplicationId
        INTO @lv_form_exists.
      IF lv_form_exists = abap_false AND NOT line_exists( lcl_buffer=>mt_onboarding[ application_id = ls_app-ApplicationId ] ).
        CLEAR ls_candidate.
        SELECT SINGLE * FROM zhcm_candidate WHERE candidate_id = @ls_app-CandidateId INTO @ls_candidate.

        APPEND VALUE #( form_id               = lcl_buffer=>new_uuid( )
                        application_id        = ls_app-ApplicationId
                        first_name            = ls_candidate-first_name
                        last_name             = ls_candidate-last_name
                        personal_email        = ls_candidate-email
                        phone                 = ls_candidate-phone
                        status                = 'P'
                        created_by            = sy-uname
                        created_at            = lv_now
                        last_changed_by       = sy-uname
                        last_changed_at       = lv_now
                        local_last_changed_at = lv_now ) TO lcl_buffer=>mt_onboarding.
      ENDIF.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus InternalNotes ) WITH lt_app_update.

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application CREATE BY \_Progress
      FIELDS ( StepOrder StepName Status CompletedAt ) WITH lt_progress.

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer UPDATE FIELDS ( PositionsFilled Status )
      WITH VALUE #( FOR offer IN lt_offers ( %tky            = offer-%tky
                                             PositionsFilled = offer-PositionsFilled
                                             Status          = offer-Status ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD evaluateWithAI.
    " The AI microservice scores the resume and writes the result back with setAIEvaluation.
    " This action asks for a new evaluation: the application is flagged as PENDING.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( AiRecommendation AiSummary )
      WITH VALUE #( FOR key IN keys
                    ( %tky             = key-%tky
                      AiRecommendation = 'PENDING'
                      AiSummary        = |New AI evaluation requested by { sy-uname } on { lv_today DATE = ISO }.| ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD setAIEvaluation.
    " Called by the AI integration (portal / AI service) with the computed score and recommendation
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( AiMatchScore AiRecommendation AiSummary )
      WITH VALUE #( FOR key IN keys
                    ( %tky             = key-%tky
                      AiMatchScore     = key-%param-Score
                      AiRecommendation = to_upper( key-%param-Recommendation )
                      AiSummary        = substring( val = key-%param-Summary
                                                    len = nmin( val1 = strlen( key-%param-Summary ) val2 = 1000 ) ) ) ).

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD preventDuplicateApplication.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application FIELDS ( CandidateId OfferId ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_apps).
    LOOP AT lt_apps INTO DATA(app).
      APPEND VALUE #( %tky = app-%tky %state_area = 'VALIDATE_DUPLICATE' ) TO reported-application.

      SELECT COUNT(*) FROM zhcm_applicatn
        WHERE candidate_id  = @app-CandidateId
          AND offer_id      = @app-OfferId
          AND application_id <> @app-ApplicationId
        INTO @DATA(lv_count).
      IF lv_count > 0.
        APPEND VALUE #( %tky = app-%tky ) TO failed-application.
        APPEND VALUE #( %tky        = app-%tky
                        %state_area = 'VALIDATE_DUPLICATE'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'This candidate has already applied to this job offer.' ) ) TO reported-application.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_pipetmpl DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS setStepOrder FOR DETERMINE ON MODIFY IMPORTING keys FOR PipeTmpl~setStepOrder.
    METHODS validateMandatorySteps FOR VALIDATE ON SAVE IMPORTING keys FOR PipeTmpl~validateMandatorySteps.
ENDCLASS.

CLASS lhc_pipetmpl IMPLEMENTATION.
  METHOD setStepOrder.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY PipeTmpl FIELDS ( OfferId StepOrder ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_new_steps).

    " A new step without an order number is placed after the last step of the offer
    LOOP AT lt_new_steps INTO DATA(ls_new) WHERE StepOrder IS INITIAL.
      READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
        ENTITY JobOffer BY \_Steps FIELDS ( StepOrder )
        WITH VALUE #( ( OfferId = ls_new-OfferId %is_draft = ls_new-%is_draft ) )
        RESULT DATA(lt_siblings).

      DATA(lv_max) = 0.
      LOOP AT lt_siblings INTO DATA(ls_sibling).
        lv_max = nmax( val1 = lv_max val2 = ls_sibling-StepOrder ).
      ENDLOOP.

      MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
        ENTITY PipeTmpl UPDATE FIELDS ( StepOrder )
        WITH VALUE #( ( %tky = ls_new-%tky StepOrder = lv_max + 1 ) ).
    ENDLOOP.
  ENDMETHOD.

  METHOD validateMandatorySteps.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY PipeTmpl FIELDS ( OfferId StepName StepType StepOrder ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_steps).

    LOOP AT lt_steps INTO DATA(step).
      APPEND VALUE #( %tky = step-%tky %state_area = 'VALIDATE_STEP' ) TO reported-pipetmpl.

      IF step-StepName IS INITIAL OR step-StepType IS INITIAL OR step-StepOrder IS INITIAL.
        APPEND VALUE #( %tky = step-%tky ) TO failed-pipetmpl.
        APPEND VALUE #( %tky        = step-%tky
                        %state_area = 'VALIDATE_STEP'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = 'Step name, type and order are required.' )
                        %element-StepName = if_abap_behv=>mk-on
                        %element-StepType = if_abap_behv=>mk-on ) TO reported-pipetmpl.
        CONTINUE.
      ENDIF.

      " Two steps of the same offer cannot have the same order number
      READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
        ENTITY JobOffer BY \_Steps FIELDS ( StepOrder )
        WITH VALUE #( ( OfferId = step-OfferId %is_draft = step-%is_draft ) )
        RESULT DATA(lt_siblings).

      LOOP AT lt_siblings TRANSPORTING NO FIELDS
           WHERE StepOrder = step-StepOrder AND TemplateId <> step-TemplateId.
        EXIT.
      ENDLOOP.
      IF sy-subrc = 0.
        APPEND VALUE #( %tky = step-%tky ) TO failed-pipetmpl.
        APPEND VALUE #( %tky        = step-%tky
                        %state_area = 'VALIDATE_STEP'
                        %msg        = new_message_with_text(
                                        severity = if_abap_behv_message=>severity-error
                                        text     = |Step order { step-StepOrder } is used twice in this pipeline.| )
                        %element-StepOrder = if_abap_behv=>mk-on ) TO reported-pipetmpl.
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
    " Onboarding forms prepared by acceptToPost
    IF lcl_buffer=>mt_onboarding IS NOT INITIAL.
      INSERT zhcm_onboardng FROM TABLE @lcl_buffer=>mt_onboarding.
    ENDIF.

    " Rejected candidates kept in the talent pool
    IF lcl_buffer=>mt_talentpool IS NOT INITIAL.
      INSERT zhcm_talntpool FROM TABLE @lcl_buffer=>mt_talentpool.
    ENDIF.

    " HR e-mails: stored, then sent (a missing mail configuration does not block the save)
    IF lcl_buffer=>mt_hrmail IS NOT INITIAL.
      INSERT zhcm_hr_mail FROM TABLE @lcl_buffer=>mt_hrmail.

      LOOP AT lcl_buffer=>mt_hrmail INTO DATA(ls_mail).
        TRY.
            SELECT SINGLE candidate_id FROM zhcm_applicatn WHERE application_id = @ls_mail-application_id INTO @DATA(lv_cand_id).
            CHECK sy-subrc = 0.
            SELECT SINGLE email FROM zhcm_candidate WHERE candidate_id = @lv_cand_id INTO @DATA(lv_email).
            CHECK sy-subrc = 0 AND lv_email IS NOT INITIAL.

            DATA(lo_mail) = cl_bcs_mail_message=>create_instance( ).
            lo_mail->set_sender( 'no-reply@company.com' ).
            lo_mail->set_subject( CONV #( ls_mail-subject ) ).
            lo_mail->set_main( cl_bcs_mail_textpart=>create_text_plain( CONV #( ls_mail-body ) ) ).
            lo_mail->add_recipient( CONV #( lv_email ) ).
            lo_mail->send( ).
          CATCH cx_bcs_mail.
            " The mail stays stored in ZHCM_HR_MAIL even if it cannot be sent
        ENDTRY.
      ENDLOOP.
    ENDIF.

    lcl_buffer=>reset( ).
  ENDMETHOD.

  METHOD cleanup_finalize.
    lcl_buffer=>reset( ).
  ENDMETHOD.
ENDCLASS.
