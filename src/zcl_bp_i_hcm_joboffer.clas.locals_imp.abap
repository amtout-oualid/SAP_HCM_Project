CLASS lhc_joboffer DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
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
ENDCLASS.

CLASS lhc_joboffer IMPLEMENTATION.
  METHOD get_instance_features.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY JobOffer FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_offers).

    result = VALUE #( FOR offer IN lt_offers (
      %tky = offer-%tky
      %action-publishOffer = COND #( WHEN offer-Status = 'D' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
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
ENDCLASS.

CLASS lhc_application DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS putOnHold FOR MODIFY IMPORTING keys FOR ACTION Application~putOnHold RESULT result.
    METHODS addNote FOR MODIFY IMPORTING keys FOR ACTION Application~addNote RESULT result.
    METHODS rejectCandidate FOR MODIFY IMPORTING keys FOR ACTION Application~rejectCandidate RESULT result.
    METHODS sendMail FOR MODIFY IMPORTING keys FOR ACTION Application~sendMail RESULT result.
    METHODS passToNextStep FOR MODIFY IMPORTING keys FOR ACTION Application~passToNextStep RESULT result.
    METHODS preventDuplicateApplication FOR VALIDATE ON SAVE IMPORTING keys FOR Application~preventDuplicateApplication.
ENDCLASS.

CLASS lhc_application IMPLEMENTATION.
  METHOD putOnHold.
    MODIFY ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application UPDATE FIELDS ( OverallStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky OverallStatus = 'H' ) ).
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD addNote.
    LOOP AT keys INTO DATA(key).
      DATA(lv_uuid) = cl_system_uuid=>create_uuid_x16_static( ).
      INSERT INTO zhcm_pipe_prog VALUES @( VALUE #(
        client = sy-mandt
        progress_id = lv_uuid
        application_id = key-ApplicationId
        step_name = 'HR Note'
        status = 'N'
        notes = key-%param-NoteText
      ) ).
    ENDLOOP.
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
      INSERT INTO zhcm_talntpool VALUES @( VALUE #(
        client = sy-mandt
        pool_id = lv_pool_id
        candidate_id = app-CandidateId
        original_offer_id = app-OfferId
        ai_score = app-AiMatchScore
        resume_url = app-ResumeUrl
        status = 'A'
        rejection_reason = keys[ 1 ]-%param-RejectionReason
      ) ).
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD sendMail.
    LOOP AT keys INTO DATA(key).
      DATA(lv_mail_id) = cl_system_uuid=>create_uuid_x16_static( ).
      INSERT INTO zhcm_hr_mail VALUES @( VALUE #(
        client = sy-mandt
        mail_id = lv_mail_id
        application_id = key-ApplicationId
        mail_type = key-%param-MailType
        subject = key-%param-Subject
        body = key-%param-Body
      ) ).
    ENDLOOP.
    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
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
       INSERT INTO zhcm_pipe_prog VALUES @( VALUE #(
         client = sy-mandt
         progress_id = lv_prog_id
         application_id = key-ApplicationId
         step_order = lt_app[ 1 ]-CurrentStepOrder
         status = 'C'
       ) ).
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_JobOffer IN LOCAL MODE
      ENTITY Application ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.
ENDCLASS.

