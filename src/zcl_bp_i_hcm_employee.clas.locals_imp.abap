CLASS lcl_buffer DEFINITION.
  PUBLIC SECTION.
    CLASS-DATA: mt_emp_hist         TYPE TABLE OF zhcm_emp_hist,
                mt_orgassign_update TYPE TABLE OF zhcm_orgassign.
ENDCLASS.
CLASS lcl_buffer IMPLEMENTATION.
ENDCLASS.

CLASS lsc_ZI_HCM_EMPLOYEE DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_HCM_EMPLOYEE IMPLEMENTATION.
  METHOD save_modified.
    IF lcl_buffer=>mt_emp_hist IS NOT INITIAL.
      INSERT zhcm_emp_hist FROM TABLE @lcl_buffer=>mt_emp_hist.
      CLEAR lcl_buffer=>mt_emp_hist.
    ENDIF.
    LOOP AT lcl_buffer=>mt_orgassign_update INTO DATA(ls_org).
      SELECT SINGLE FROM zhcm_orgassign FIELDS org_assignment_id WHERE employee_id = @ls_org-employee_id INTO @DATA(lv_existing_asg).
      IF sy-subrc = 0.
        IF ls_org-position_id IS NOT INITIAL.
          UPDATE zhcm_orgassign
            SET position_id = @ls_org-position_id,
                job_title   = @ls_org-job_title,
                org_unit_id = @ls_org-org_unit_id
            WHERE employee_id = @ls_org-employee_id.
        ENDIF.
        IF ls_org-department IS NOT INITIAL.
          UPDATE zhcm_orgassign
            SET department  = @ls_org-department,
                org_unit_id = @ls_org-org_unit_id
            WHERE employee_id = @ls_org-employee_id.
        ENDIF.
      ELSE.
        DATA(lv_new_asg_id) = cl_system_uuid=>create_uuid_x16_static( ).
        INSERT zhcm_orgassign FROM @( VALUE #(
          client            = sy-mandt
          org_assignment_id = lv_new_asg_id
          employee_id       = ls_org-employee_id
          position_id       = ls_org-position_id
          org_unit_id       = ls_org-org_unit_id
          job_title         = ls_org-job_title
          department        = ls_org-department
          valid_from        = cl_abap_context_info=>get_system_date( )
          valid_to          = '99991231'
        ) ).
      ENDIF.
    ENDLOOP.
    CLEAR lcl_buffer=>mt_orgassign_update.
  ENDMETHOD.
ENDCLASS.

CLASS lhc_employee DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS get_global_authorizations FOR GLOBAL AUTHORIZATION
      IMPORTING REQUEST requested_authorizations FOR Employee RESULT result.

    METHODS get_instance_authorizations FOR INSTANCE AUTHORIZATION
      IMPORTING keys REQUEST requested_authorizations FOR Employee RESULT result.

    METHODS get_instance_features FOR INSTANCE FEATURES
      IMPORTING keys REQUEST requested_features FOR Employee RESULT result.

    METHODS setDefaultStatus FOR DETERMINE ON MODIFY
      IMPORTING keys FOR Employee~setDefaultStatus.

    METHODS promoteEmployee FOR MODIFY
      IMPORTING keys FOR ACTION Employee~promoteEmployee RESULT result.
    METHODS terminateEmployee FOR MODIFY
      IMPORTING keys FOR ACTION Employee~terminateEmployee RESULT result.
    METHODS transferEmployee FOR MODIFY
      IMPORTING keys FOR ACTION Employee~transferEmployee RESULT result.
    METHODS suspendEmployee FOR MODIFY
      IMPORTING keys FOR ACTION Employee~suspendEmployee RESULT result.
    METHODS activateEmployee FOR MODIFY
      IMPORTING keys FOR ACTION Employee~activateEmployee RESULT result.
ENDCLASS.

CLASS lhc_employee IMPLEMENTATION.
  METHOD get_global_authorizations.
    IF requested_authorizations-%create = if_abap_behv=>mk-on.
      result-%create = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%update = if_abap_behv=>mk-on.
      result-%update = if_abap_behv=>auth-allowed.
    ENDIF.
    IF requested_authorizations-%delete = if_abap_behv=>mk-on.
      result-%delete = if_abap_behv=>auth-allowed.
    ENDIF.
  ENDMETHOD.

  METHOD get_instance_authorizations.
    LOOP AT keys INTO DATA(key).
      APPEND VALUE #( %tky = key-%tky
                      %update = if_abap_behv=>auth-allowed
                      %delete = if_abap_behv=>auth-allowed
                      %action-promoteEmployee = if_abap_behv=>auth-allowed
                      %action-terminateEmployee = if_abap_behv=>auth-allowed
                      %action-transferEmployee = if_abap_behv=>auth-allowed
                      %action-suspendEmployee = if_abap_behv=>auth-allowed
                      %action-activateEmployee = if_abap_behv=>auth-allowed ) TO result.
    ENDLOOP.
  ENDMETHOD.

  METHOD get_instance_features.
    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee FIELDS ( EmployeeStatus ) WITH CORRESPONDING #( keys ) RESULT DATA(lt_emp).

    result = VALUE #( FOR emp IN lt_emp (
      %tky = emp-%tky
      %action-promoteEmployee   = COND #( WHEN emp-EmployeeStatus = 'A' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-terminateEmployee = COND #( WHEN emp-EmployeeStatus = 'A' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-transferEmployee  = COND #( WHEN emp-EmployeeStatus = 'A' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-suspendEmployee   = COND #( WHEN emp-EmployeeStatus = 'A' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-activateEmployee  = COND #( WHEN emp-EmployeeStatus = 'S' OR emp-EmployeeStatus = 'T' THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
    ) ).
  ENDMETHOD.

  METHOD setDefaultStatus.
    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee FIELDS ( EmployeeStatus ) WITH CORRESPONDING #( keys ) RESULT DATA(employees).

    MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee UPDATE FIELDS ( EmployeeStatus HireDate )
      WITH VALUE #( FOR emp IN employees WHERE ( EmployeeStatus IS INITIAL )
          ( %tky = emp-%tky EmployeeStatus = 'A' HireDate = cl_abap_context_info=>get_system_date( ) ) ).
  ENDMETHOD.

  METHOD promoteEmployee.
    LOOP AT keys INTO DATA(key).
      " Resolve Position Details (Job Title and Org Unit ID)
      SELECT SINGLE job_title, org_unit_id FROM zhcm_position
        WHERE position_id = @key-%param-NewPositionId
        INTO (@DATA(lv_new_title), @DATA(lv_new_org_id)).

      APPEND VALUE #(
        employee_id = key-EmployeeId
        position_id = key-%param-NewPositionId
        job_title   = lv_new_title
        org_unit_id = lv_new_org_id
      ) TO lcl_buffer=>mt_orgassign_update.

      " Mark the newly assigned position as Filled
      IF key-%param-NewPositionId IS NOT INITIAL.
        UPDATE zhcm_position SET status = 'F' WHERE position_id = @key-%param-NewPositionId.
      ENDIF.
    ENDLOOP.

    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_hist_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client        = sy-mandt
        history_id    = lv_hist_id
        employee_id   = ls_key-EmployeeId
        event_type    = 'Promoted'
        event_date    = cl_abap_context_info=>get_system_date( )
        new_position  = ls_key-%param-NewPositionId
        new_salary    = ls_key-%param-NewSalary
        currency_code = ls_key-%param-CurrencyCode
        changed_by    = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD terminateEmployee.
    MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee UPDATE FIELDS ( EmployeeStatus TerminationDate )
      WITH VALUE #( FOR key IN keys (
        %tky = key-%tky
        EmployeeStatus = 'T'
        TerminationDate = key-%param-TerminationDate
      ) ).

    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_hist_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client      = sy-mandt
        history_id  = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type  = 'Terminated'
        event_date  = cl_abap_context_info=>get_system_date( )
        notes       = ls_key-%param-TerminationReason
        changed_by  = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD transferEmployee.
    LOOP AT keys INTO DATA(key).
      " Look up Org Unit ID for the department name
      SELECT SINGLE org_unit_id FROM zhcm_orgunit
        WHERE unit_name = @key-%param-NewDepartment
        INTO @DATA(lv_dept_org_id).

      APPEND VALUE #(
        employee_id = key-EmployeeId
        department  = key-%param-NewDepartment
        org_unit_id = lv_dept_org_id
      ) TO lcl_buffer=>mt_orgassign_update.
    ENDLOOP.

    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_hist_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client         = sy-mandt
        history_id     = lv_hist_id
        employee_id    = ls_key-EmployeeId
        event_type     = 'Transferred'
        event_date     = cl_abap_context_info=>get_system_date( )
        new_department = ls_key-%param-NewDepartment
        changed_by     = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD suspendEmployee.
    MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee UPDATE FIELDS ( EmployeeStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky EmployeeStatus = 'S' ) ).

    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_hist_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client      = sy-mandt
        history_id  = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type  = 'Suspended'
        event_date  = cl_abap_context_info=>get_system_date( )
        changed_by  = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD activateEmployee.
    MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee UPDATE FIELDS ( EmployeeStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky EmployeeStatus = 'A' ) ).

    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_hist_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client      = sy-mandt
        history_id  = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type  = 'Activated'
        event_date  = cl_abap_context_info=>get_system_date( )
        changed_by  = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.
ENDCLASS.

