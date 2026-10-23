"! Records that the save sequence writes outside the employee (buffer-then-save)
CLASS lcl_buffer DEFINITION FINAL.
  PUBLIC SECTION.
    TYPES: BEGIN OF ty_position_status,
             position_id TYPE sysuuid_x16,
             status      TYPE zhcm_position-status,
           END OF ty_position_status.

    CLASS-DATA: mt_emp_hist        TYPE TABLE OF zhcm_emp_hist,
                mt_position_status TYPE STANDARD TABLE OF ty_position_status WITH EMPTY KEY.

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
    CLEAR: mt_emp_hist, mt_position_status.
  ENDMETHOD.
ENDCLASS.

CLASS lsc_ZI_HCM_EMPLOYEE DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
    METHODS cleanup_finalize REDEFINITION.
ENDCLASS.

CLASS lsc_ZI_HCM_EMPLOYEE IMPLEMENTATION.
  METHOD save_modified.
    " Employment history (personnel events)
    IF lcl_buffer=>mt_emp_hist IS NOT INITIAL.
      INSERT zhcm_emp_hist FROM TABLE @lcl_buffer=>mt_emp_hist.
    ENDIF.

    " Position status in Organizational Management: V = vacant again, F = filled
    IF lcl_buffer=>mt_position_status IS NOT INITIAL.
      GET TIME STAMP FIELD DATA(lv_now).
      LOOP AT lcl_buffer=>mt_position_status INTO DATA(ls_position).
        UPDATE zhcm_position
          SET status = @ls_position-status, local_last_changed_at = @lv_now
          WHERE position_id = @ls_position-position_id.
      ENDLOOP.
    ENDIF.

    lcl_buffer=>reset( ).
  ENDMETHOD.

  METHOD cleanup_finalize.
    lcl_buffer=>reset( ).
  ENDMETHOD.
ENDCLASS.

CLASS lhc_employee DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    TYPES tt_assignments TYPE TABLE FOR READ RESULT ZI_HCM_Employee\\Employee\_OrgAssign.
    TYPES ts_assignment  TYPE LINE OF tt_assignments.

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

    "! Current (open) organizational assignment of an employee
    METHODS current_assignment
      IMPORTING it_assignments       TYPE tt_assignments
                iv_employee_id       TYPE sysuuid_x16
                iv_today             TYPE d
      RETURNING VALUE(rs_assignment) TYPE ts_assignment.
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

    " Personnel actions run on the saved employee only (display mode)
    result = VALUE #( FOR emp IN lt_emp (
      %tky = emp-%tky
      %action-promoteEmployee   = COND #( WHEN emp-%is_draft = if_abap_behv=>mk-off AND emp-EmployeeStatus = 'A'
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-terminateEmployee = COND #( WHEN emp-%is_draft = if_abap_behv=>mk-off
                                               AND ( emp-EmployeeStatus = 'A' OR emp-EmployeeStatus = 'S' )
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-transferEmployee  = COND #( WHEN emp-%is_draft = if_abap_behv=>mk-off AND emp-EmployeeStatus = 'A'
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-suspendEmployee   = COND #( WHEN emp-%is_draft = if_abap_behv=>mk-off AND emp-EmployeeStatus = 'A'
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
      %action-activateEmployee  = COND #( WHEN emp-%is_draft = if_abap_behv=>mk-off
                                               AND ( emp-EmployeeStatus = 'S' OR emp-EmployeeStatus = 'T' )
                                          THEN if_abap_behv=>fc-o-enabled ELSE if_abap_behv=>fc-o-disabled )
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

  METHOD current_assignment.
    " Open-ended assignment (valid today or later) with the latest start date
    LOOP AT it_assignments INTO DATA(ls_assignment)
         WHERE EmployeeId = iv_employee_id AND ValidTo >= iv_today.
      IF rs_assignment IS INITIAL OR ls_assignment-ValidFrom > rs_assignment-ValidFrom.
        rs_assignment = ls_assignment.
      ENDIF.
    ENDLOOP.
  ENDMETHOD.

  METHOD promoteEmployee.
    DATA(lv_today)     = cl_abap_context_info=>get_system_date( ).
    DATA(lv_yesterday) = CONV d( lv_today - 1 ).

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee BY \_OrgAssign ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_assignments).

    DATA lt_close  TYPE TABLE FOR UPDATE ZI_HCM_Employee\\OrgAssign.
    DATA lt_create TYPE TABLE FOR CREATE ZI_HCM_Employee\\Employee\_OrgAssign.
    DATA ls_position TYPE zhcm_position.
    DATA lv_new_department TYPE zhcm_orgunit-unit_name.

    LOOP AT keys INTO DATA(ls_key).
      " 1. The new position must be vacant
      CLEAR: ls_position, lv_new_department.
      SELECT SINGLE * FROM zhcm_position
        WHERE position_id = @ls_key-%param-NewPositionId
        INTO @ls_position.
      IF sy-subrc <> 0 OR ls_position-status <> 'V'.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-employee.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Select a vacant position for the promotion.' ) )
          TO reported-employee.
        CONTINUE.
      ENDIF.
      SELECT SINGLE unit_name FROM zhcm_orgunit
        WHERE org_unit_id = @ls_position-org_unit_id
        INTO @lv_new_department.

      " 2. The current assignment ends, its position becomes vacant again
      DATA(ls_current) = current_assignment( it_assignments = lt_assignments
                                             iv_employee_id = ls_key-EmployeeId
                                             iv_today       = lv_today ).
      IF ls_current IS NOT INITIAL.
        APPEND VALUE #( %tky    = ls_current-%tky
                        ValidTo = COND #( WHEN ls_current-ValidFrom < lv_today THEN lv_yesterday ELSE lv_today ) )
          TO lt_close.
        IF ls_current-PositionId IS NOT INITIAL.
          APPEND VALUE #( position_id = ls_current-PositionId status = 'V' ) TO lcl_buffer=>mt_position_status.
        ENDIF.
      ENDIF.

      " 3. New assignment on the new position, which becomes filled
      APPEND VALUE #( %tky    = ls_key-%tky
                      %target = VALUE #( ( %cid       = |PROMO_{ ls_key-EmployeeId }|
                                           %is_draft  = ls_key-%is_draft
                                           PositionId = ls_position-position_id
                                           OrgUnitId  = ls_position-org_unit_id
                                           JobTitle   = ls_position-job_title
                                           Department = lv_new_department
                                           ValidFrom  = lv_today
                                           ValidTo    = '99991231' ) ) ) TO lt_create.
      APPEND VALUE #( position_id = ls_position-position_id status = 'F' ) TO lcl_buffer=>mt_position_status.

      " 4. Personnel event
      APPEND VALUE #(
        history_id     = lcl_buffer=>new_uuid( )
        employee_id    = ls_key-EmployeeId
        event_type     = 'Promoted'
        event_date     = lv_today
        old_position   = ls_current-JobTitle
        new_position   = ls_position-job_title
        old_department = ls_current-Department
        new_department = lv_new_department
        new_salary     = ls_key-%param-NewSalary
        currency_code  = ls_key-%param-CurrencyCode
        changed_by     = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    IF lt_close IS NOT INITIAL.
      MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
        ENTITY OrgAssign UPDATE FIELDS ( ValidTo ) WITH lt_close.
    ENDIF.
    IF lt_create IS NOT INITIAL.
      MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
        ENTITY Employee CREATE BY \_OrgAssign
        FIELDS ( PositionId OrgUnitId JobTitle Department ValidFrom ValidTo ) WITH lt_create.
    ENDIF.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD transferEmployee.
    DATA(lv_today)     = cl_abap_context_info=>get_system_date( ).
    DATA(lv_yesterday) = CONV d( lv_today - 1 ).

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee BY \_OrgAssign ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_assignments).

    DATA lt_close  TYPE TABLE FOR UPDATE ZI_HCM_Employee\\OrgAssign.
    DATA lt_create TYPE TABLE FOR CREATE ZI_HCM_Employee\\Employee\_OrgAssign.
    DATA lv_org_unit_id TYPE sysuuid_x16.
    DATA lv_unit_name   TYPE zhcm_orgunit-unit_name.

    LOOP AT keys INTO DATA(ls_key).
      " 1. The target department must exist
      CLEAR: lv_org_unit_id, lv_unit_name.
      SELECT SINGLE org_unit_id, unit_name FROM zhcm_orgunit
        WHERE unit_name = @ls_key-%param-NewDepartment
        INTO (@lv_org_unit_id, @lv_unit_name).
      IF sy-subrc <> 0.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-employee.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'Select an existing department.' ) )
          TO reported-employee.
        CONTINUE.
      ENDIF.

      DATA(ls_current) = current_assignment( it_assignments = lt_assignments
                                             iv_employee_id = ls_key-EmployeeId
                                             iv_today       = lv_today ).
      IF ls_current-OrgUnitId = lv_org_unit_id AND lv_org_unit_id IS NOT INITIAL.
        APPEND VALUE #( %tky = ls_key-%tky ) TO failed-employee.
        APPEND VALUE #( %tky = ls_key-%tky
                        %msg = new_message_with_text( severity = if_abap_behv_message=>severity-error
                                                      text     = 'The employee already belongs to this department.' ) )
          TO reported-employee.
        CONTINUE.
      ENDIF.

      " 2. The current assignment ends; the old position becomes vacant
      IF ls_current IS NOT INITIAL.
        APPEND VALUE #( %tky    = ls_current-%tky
                        ValidTo = COND #( WHEN ls_current-ValidFrom < lv_today THEN lv_yesterday ELSE lv_today ) )
          TO lt_close.
        IF ls_current-PositionId IS NOT INITIAL.
          APPEND VALUE #( position_id = ls_current-PositionId status = 'V' ) TO lcl_buffer=>mt_position_status.
        ENDIF.
      ENDIF.

      " 3. New assignment in the target department (same job title, position to be assigned by HR)
      APPEND VALUE #( %tky    = ls_key-%tky
                      %target = VALUE #( ( %cid       = |TRANS_{ ls_key-EmployeeId }|
                                           %is_draft  = ls_key-%is_draft
                                           OrgUnitId  = lv_org_unit_id
                                           JobTitle   = ls_current-JobTitle
                                           Department = lv_unit_name
                                           ValidFrom  = lv_today
                                           ValidTo    = '99991231' ) ) ) TO lt_create.

      " 4. Personnel event
      APPEND VALUE #(
        history_id     = lcl_buffer=>new_uuid( )
        employee_id    = ls_key-EmployeeId
        event_type     = 'Transferred'
        event_date     = lv_today
        old_position   = ls_current-JobTitle
        new_position   = ls_current-JobTitle
        old_department = ls_current-Department
        new_department = lv_unit_name
        changed_by     = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    IF lt_close IS NOT INITIAL.
      MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
        ENTITY OrgAssign UPDATE FIELDS ( ValidTo ) WITH lt_close.
    ENDIF.
    IF lt_create IS NOT INITIAL.
      MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
        ENTITY Employee CREATE BY \_OrgAssign
        FIELDS ( OrgUnitId JobTitle Department ValidFrom ValidTo ) WITH lt_create.
    ENDIF.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD terminateEmployee.
    DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee BY \_OrgAssign ALL FIELDS WITH CORRESPONDING #( keys )
      RESULT DATA(lt_assignments).

    DATA lt_employee TYPE TABLE FOR UPDATE ZI_HCM_Employee\\Employee.
    DATA lt_close    TYPE TABLE FOR UPDATE ZI_HCM_Employee\\OrgAssign.

    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_end_date) = COND d( WHEN ls_key-%param-TerminationDate IS INITIAL THEN lv_today
                                  ELSE ls_key-%param-TerminationDate ).

      APPEND VALUE #( %tky            = ls_key-%tky
                      EmployeeStatus  = 'T'
                      TerminationDate = lv_end_date ) TO lt_employee.

      " The current assignment ends on the termination date; its position becomes vacant
      DATA(ls_current) = current_assignment( it_assignments = lt_assignments
                                             iv_employee_id = ls_key-EmployeeId
                                             iv_today       = lv_today ).
      IF ls_current IS NOT INITIAL.
        APPEND VALUE #( %tky    = ls_current-%tky
                        ValidTo = COND #( WHEN lv_end_date < ls_current-ValidFrom THEN ls_current-ValidFrom
                                          ELSE lv_end_date ) ) TO lt_close.
        IF ls_current-PositionId IS NOT INITIAL.
          APPEND VALUE #( position_id = ls_current-PositionId status = 'V' ) TO lcl_buffer=>mt_position_status.
        ENDIF.
      ENDIF.

      APPEND VALUE #(
        history_id     = lcl_buffer=>new_uuid( )
        employee_id    = ls_key-EmployeeId
        event_type     = 'Terminated'
        event_date     = lv_end_date
        old_position   = ls_current-JobTitle
        old_department = ls_current-Department
        notes          = ls_key-%param-TerminationReason
        changed_by     = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee UPDATE FIELDS ( EmployeeStatus TerminationDate ) WITH lt_employee.
    IF lt_close IS NOT INITIAL.
      MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
        ENTITY OrgAssign UPDATE FIELDS ( ValidTo ) WITH lt_close.
    ENDIF.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD suspendEmployee.
    MODIFY ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee UPDATE FIELDS ( EmployeeStatus )
      WITH VALUE #( FOR key IN keys ( %tky = key-%tky EmployeeStatus = 'S' ) ).

    LOOP AT keys INTO DATA(ls_key).
      APPEND VALUE #(
        history_id  = lcl_buffer=>new_uuid( )
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
      APPEND VALUE #(
        history_id  = lcl_buffer=>new_uuid( )
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
