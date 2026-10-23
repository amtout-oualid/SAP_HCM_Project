"! Employees to create in the save sequence (buffer-then-save)
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_hire,
             employee_id        TYPE sysuuid_x16,
             application_id     TYPE sysuuid_x16,
             first_name         TYPE zhcm_employee-first_name,
             last_name          TYPE zhcm_employee-last_name,
             date_of_birth      TYPE zhcm_employee-date_of_birth,
             place_of_birth     TYPE zhcm_employee-place_of_birth,
             marital_status     TYPE zhcm_employee-marital_status,
             nationality        TYPE zhcm_employee-nationality,
             gender             TYPE zhcm_employee-gender,
             address            TYPE string,
             phone              TYPE zhcm_contact-phone_number,
             personal_email     TYPE zhcm_contact-personal_email,
             bank_name          TYPE zhcm_bankdetl-bank_name,
             bank_account       TYPE zhcm_bankdetl-account_number,
             iban               TYPE zhcm_bankdetl-iban,
             emergency_name     TYPE zhcm_emergency-contact_name,
             emergency_phone    TYPE zhcm_emergency-phone_number,
             emergency_relation TYPE zhcm_emergency-relationship,
             position_id        TYPE sysuuid_x16,
             org_unit_id        TYPE sysuuid_x16,
             job_title          TYPE zhcm_orgassign-job_title,
             department         TYPE zhcm_orgassign-department,
           END OF ty_hire.

    CLASS-DATA mt_hires TYPE STANDARD TABLE OF ty_hire WITH EMPTY KEY.

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

CLASS lhc_onboarding DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Onboarding RESULT result.
    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Onboarding RESULT result.
    METHODS setDefaultStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Onboarding~setDefaultStatus.
    METHODS validateSubmission FOR VALIDATE ON SAVE
      IMPORTING keys FOR Onboarding~validateSubmission.
    METHODS submitForm FOR MODIFY
      IMPORTING keys FOR ACTION Onboarding~submitForm RESULT result.
    METHODS approveAndCreateEmployee FOR MODIFY
      IMPORTING keys FOR ACTION Onboarding~approveAndCreateEmployee RESULT result.
    METHODS rejectForm FOR MODIFY
      IMPORTING keys FOR ACTION Onboarding~rejectForm RESULT result.
ENDCLASS.

CLASS lhc_onboarding IMPLEMENTATION.
  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky                             = key-%tky
                      %update                          = if_abap_behv=>auth-allowed
                      %delete                          = if_abap_behv=>auth-allowed
                      %action-submitForm               = if_abap_behv=>auth-allowed
                      %action-approveAndCreateEmployee = if_abap_behv=>auth-allowed
                      %action-rejectForm               = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_forms).

    " Pending -> Submitted (candidate) -> Approved or back to Pending (HR); never on a draft
    result = VALUE #( FOR form IN lt_forms (
      %tky = form-%tky
      %action-submitForm               = COND #( WHEN form-%is_draft = if_abap_behv=>mk-off
                                                  AND ( form-Status = 'P' OR form-Status IS INITIAL )
                                                 THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-approveAndCreateEmployee = COND #( WHEN form-%is_draft = if_abap_behv=>mk-off AND form-Status = 'S'
                                                 THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-rejectForm               = COND #( WHEN form-%is_draft = if_abap_behv=>mk-off AND form-Status = 'S'
                                                 THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
    ) ).
  ENDMETHOD.

  METHOD setDefaultStatus.
    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding FIELDS ( Status ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_forms).

    DELETE lt_forms WHERE Status IS NOT INITIAL.
    IF lt_forms IS INITIAL.
      RETURN.
    ENDIF.

    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status )
      WITH VALUE #( FOR form IN lt_forms ( %tky = form-%tky Status = 'P' ) ).
  ENDMETHOD.

  METHOD validateSubmission.
    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding FIELDS ( Status FirstName LastName DateOfBirth NationalId ) WITH CORRESPONDING #( keys )
      RESULT DATA(lt_forms).

    LOOP AT lt_forms INTO DATA(form).
      APPEND VALUE #( %tky = form-%tky %state_area = 'VALIDATE_FORM' ) TO reported-onboarding.

      " Only a submitted form must be complete
      IF form-Status <> 'S'.
        CONTINUE.
      ENDIF.

      IF form-FirstName IS INITIAL OR form-LastName IS INITIAL
         OR form-DateOfBirth IS INITIAL OR form-NationalId IS INITIAL.
        APPEND VALUE #( %tky = form-%tky ) TO failed-onboarding.
        APPEND VALUE #( %tky                 = form-%tky
                        %state_area          = 'VALIDATE_FORM'
                        %msg                 = new_message_with_text(
                                                 severity = if_abap_behv_message=>severity-error
                                                 text     = 'First name, last name, date of birth and national ID are required.' )
                        %element-FirstName   = if_abap_behv=>mk-on
                        %element-LastName    = if_abap_behv=>mk-on
                        %element-DateOfBirth = if_abap_behv=>mk-on
                        %element-NationalId  = if_abap_behv=>mk-on ) TO reported-onboarding.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD submitForm.
    GET TIME STAMP FIELD DATA(lv_ts).
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status SubmittedAt )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'S' SubmittedAt = lv_ts ) ).

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD approveAndCreateEmployee.
    TYPES: BEGIN OF ty_position,
             position_id TYPE zhcm_position-position_id,
             org_unit_id TYPE zhcm_position-org_unit_id,
             job_title   TYPE zhcm_position-job_title,
           END OF ty_position.

    DATA lt_update         TYPE TABLE FOR UPDATE ZI_HCM_Onboarding\\Onboarding.
    DATA lt_used_positions TYPE STANDARD TABLE OF sysuuid_x16 WITH EMPTY KEY.
    DATA lt_vacant         TYPE STANDARD TABLE OF ty_position WITH EMPTY KEY.
    DATA ls_chosen         TYPE ty_position.
    DATA ls_offer          TYPE zhcm_joboffer.
    DATA lv_offer_id       TYPE sysuuid_x16.
    DATA lv_ref_title      TYPE zhcm_position-job_title.
    DATA lv_ref_org        TYPE sysuuid_x16.
    DATA lv_rank           TYPE i.
    DATA lv_chosen_rank    TYPE i.

    GET TIME STAMP FIELD DATA(lv_now).

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_forms).

    LOOP AT lt_forms INTO DATA(ls_form).
      " 1. Employee data taken from the form; the employee key is fixed now and written in the save sequence
      DATA(ls_hire) = VALUE lcl_buffer=>ty_hire(
        employee_id        = lcl_buffer=>new_uuid( )
        application_id     = ls_form-ApplicationId
        first_name         = ls_form-FirstName
        last_name          = ls_form-LastName
        date_of_birth      = ls_form-DateOfBirth
        place_of_birth     = ls_form-PlaceOfBirth
        marital_status     = ls_form-MaritalStatus
        nationality        = ls_form-Nationality
        gender             = ls_form-Gender
        address            = ls_form-Address
        phone              = ls_form-Phone
        personal_email     = ls_form-PersonalEmail
        bank_name          = ls_form-BankName
        bank_account       = ls_form-BankAccount
        iban               = ls_form-Iban
        emergency_name     = ls_form-EmergencyName
        emergency_phone    = ls_form-EmergencyPhone
        emergency_relation = ls_form-EmergencyRelation ).

      " 2. Job offer of the application
      CLEAR: lv_offer_id, ls_offer, lv_ref_title, lv_ref_org, ls_chosen, lv_chosen_rank.
      SELECT SINGLE offer_id FROM zhcm_applicatn
        WHERE application_id = @ls_form-ApplicationId
        INTO @lv_offer_id.
      IF lv_offer_id IS NOT INITIAL.
        SELECT SINGLE * FROM zhcm_joboffer WHERE offer_id = @lv_offer_id INTO @ls_offer.
      ENDIF.
      ls_hire-job_title  = ls_offer-title.
      ls_hire-department = ls_offer-department.

      " 3. Position: the vacant position of the offer, else another vacant position with the same title
      "    (same organizational unit first). An offer for several positions fills one position per hire.
      IF ls_offer-position_id IS NOT INITIAL.
        SELECT SINGLE job_title, org_unit_id FROM zhcm_position
          WHERE position_id = @ls_offer-position_id
          INTO (@lv_ref_title, @lv_ref_org).
      ENDIF.
      IF lv_ref_title IS INITIAL.
        lv_ref_title = ls_offer-title.
      ENDIF.

      IF lv_ref_title IS NOT INITIAL.
        SELECT position_id, org_unit_id, job_title FROM zhcm_position
          WHERE status = 'V' AND job_title = @lv_ref_title
          INTO TABLE @lt_vacant.
      ELSE.
        CLEAR lt_vacant.
      ENDIF.

      LOOP AT lt_vacant INTO DATA(ls_vacant).
        IF line_exists( lt_used_positions[ table_line = ls_vacant-position_id ] ).
          CONTINUE.
        ENDIF.
        lv_rank = COND #( WHEN ls_vacant-position_id = ls_offer-position_id THEN 1
                          WHEN ls_vacant-org_unit_id = lv_ref_org           THEN 2
                          ELSE 3 ).
        IF ls_chosen IS INITIAL OR lv_rank < lv_chosen_rank.
          ls_chosen      = ls_vacant.
          lv_chosen_rank = lv_rank.
        ENDIF.
      ENDLOOP.

      IF ls_chosen IS NOT INITIAL.
        APPEND ls_chosen-position_id TO lt_used_positions.
        ls_hire-position_id = ls_chosen-position_id.
        ls_hire-org_unit_id = ls_chosen-org_unit_id.
        ls_hire-job_title   = ls_chosen-job_title.
      ELSE.
        ls_hire-org_unit_id = lv_ref_org.
      ENDIF.

      " 4. Department = name of the organizational unit
      IF ls_hire-org_unit_id IS INITIAL AND ls_hire-department IS NOT INITIAL.
        SELECT SINGLE org_unit_id FROM zhcm_orgunit
          WHERE unit_name = @ls_hire-department
          INTO @ls_hire-org_unit_id.
      ENDIF.
      IF ls_hire-org_unit_id IS NOT INITIAL.
        SELECT SINGLE unit_name FROM zhcm_orgunit
          WHERE org_unit_id = @ls_hire-org_unit_id
          INTO @DATA(lv_unit_name).
        IF sy-subrc = 0.
          ls_hire-department = lv_unit_name.
        ENDIF.
      ENDIF.

      APPEND ls_hire TO lcl_buffer=>mt_hires.

      " 5. The form is approved and linked to the new employee
      APPEND VALUE #( %tky       = ls_form-%tky
                      Status     = 'A'
                      ApprovedBy = sy-uname
                      ApprovedAt = lv_now
                      EmployeeId = ls_hire-employee_id ) TO lt_update.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status ApprovedBy ApprovedAt EmployeeId ) WITH lt_update.

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD rejectForm.
    " The form goes back to the candidate, who can correct it and submit it again
    MODIFY ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding UPDATE FIELDS ( Status )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky Status = 'P' ) ).

    READ ENTITIES OF ZI_HCM_Onboarding IN LOCAL MODE
      ENTITY Onboarding ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lsc_ZI_HCM_ONBOARDING DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified    REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_HCM_ONBOARDING IMPLEMENTATION.
  METHOD save_modified.
    " Atomic hire: the employee and its child records are written in the same LUW as the approval
    IF lcl_buffer=>mt_hires IS INITIAL.
      RETURN.
    ENDIF.

    DATA: lt_employee  TYPE STANDARD TABLE OF zhcm_employee  WITH EMPTY KEY,
          lt_contact   TYPE STANDARD TABLE OF zhcm_contact   WITH EMPTY KEY,
          lt_bank      TYPE STANDARD TABLE OF zhcm_bankdetl  WITH EMPTY KEY,
          lt_emergency TYPE STANDARD TABLE OF zhcm_emergency WITH EMPTY KEY,
          lt_assign    TYPE STANDARD TABLE OF zhcm_orgassign WITH EMPTY KEY,
          lt_history   TYPE STANDARD TABLE OF zhcm_emp_hist  WITH EMPTY KEY.

    GET TIME STAMP FIELD DATA(lv_now).
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    LOOP AT lcl_buffer=>mt_hires INTO DATA(ls_hire).
      APPEND VALUE #( employee_id           = ls_hire-employee_id
                      first_name            = ls_hire-first_name
                      last_name             = ls_hire-last_name
                      date_of_birth         = ls_hire-date_of_birth
                      place_of_birth        = ls_hire-place_of_birth
                      marital_status        = ls_hire-marital_status
                      nationality           = ls_hire-nationality
                      gender                = ls_hire-gender
                      employee_status       = 'A'
                      hire_date             = lv_today
                      created_by            = sy-uname
                      created_at            = lv_now
                      last_changed_by       = sy-uname
                      last_changed_at       = lv_now
                      local_last_changed_at = lv_now ) TO lt_employee.

      APPEND VALUE #( contact_id            = lcl_buffer=>new_uuid( )
                      employee_id           = ls_hire-employee_id
                      personal_address      = ls_hire-address
                      phone_number          = ls_hire-phone
                      personal_email        = ls_hire-personal_email
                      local_last_changed_at = lv_now ) TO lt_contact.

      IF ls_hire-bank_name IS NOT INITIAL OR ls_hire-bank_account IS NOT INITIAL OR ls_hire-iban IS NOT INITIAL.
        APPEND VALUE #( bank_detail_id        = lcl_buffer=>new_uuid( )
                        employee_id           = ls_hire-employee_id
                        bank_name             = ls_hire-bank_name
                        account_number        = ls_hire-bank_account
                        iban                  = ls_hire-iban
                        local_last_changed_at = lv_now ) TO lt_bank.
      ENDIF.

      IF ls_hire-emergency_name IS NOT INITIAL.
        APPEND VALUE #( em_contact_id         = lcl_buffer=>new_uuid( )
                        employee_id           = ls_hire-employee_id
                        contact_name          = ls_hire-emergency_name
                        relationship          = ls_hire-emergency_relation
                        phone_number          = ls_hire-emergency_phone
                        is_primary            = abap_true
                        local_last_changed_at = lv_now ) TO lt_emergency.
      ENDIF.

      APPEND VALUE #( org_assignment_id     = lcl_buffer=>new_uuid( )
                      employee_id           = ls_hire-employee_id
                      position_id           = ls_hire-position_id
                      org_unit_id           = ls_hire-org_unit_id
                      job_title             = ls_hire-job_title
                      department            = ls_hire-department
                      valid_from            = lv_today
                      valid_to              = '99991231'
                      local_last_changed_at = lv_now ) TO lt_assign.

      APPEND VALUE #( history_id     = lcl_buffer=>new_uuid( )
                      employee_id    = ls_hire-employee_id
                      event_type     = 'Hired'
                      event_date     = lv_today
                      new_position   = ls_hire-job_title
                      new_department = ls_hire-department
                      notes          = 'Hired through the recruitment pipeline (onboarding form approved).'
                      changed_by     = sy-uname ) TO lt_history.

      " The occupied position becomes Filled
      IF ls_hire-position_id IS NOT INITIAL.
        UPDATE zhcm_position
          SET status = 'F', local_last_changed_at = @lv_now
          WHERE position_id = @ls_hire-position_id.
      ENDIF.
    ENDLOOP.

    INSERT zhcm_employee  FROM TABLE @lt_employee.
    INSERT zhcm_contact   FROM TABLE @lt_contact.
    IF lt_bank IS NOT INITIAL.
      INSERT zhcm_bankdetl FROM TABLE @lt_bank.
    ENDIF.
    IF lt_emergency IS NOT INITIAL.
      INSERT zhcm_emergency FROM TABLE @lt_emergency.
    ENDIF.
    INSERT zhcm_orgassign FROM TABLE @lt_assign.
    INSERT zhcm_emp_hist  FROM TABLE @lt_history.

    CLEAR lcl_buffer=>mt_hires.
  ENDMETHOD.

  METHOD cleanup_finalize.
    CLEAR lcl_buffer=>mt_hires.
  ENDMETHOD.
ENDCLASS.
