CLASS lcl_buffer DEFINITION.
  PUBLIC SECTION.
    CLASS-DATA: mt_emp_hist TYPE TABLE OF zhcm_emp_hist.
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
  ENDMETHOD.
ENDCLASS.

CLASS lhc_employee DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
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
      ENTITY Employee UPDATE FIELDS ( EmployeeStatus )
        WITH VALUE #( FOR emp IN employees WHERE ( EmployeeStatus IS INITIAL )
            ( %tky = emp-%tky EmployeeStatus = 'A' HireDate = cl_abap_context_info=>get_system_date( ) ) ).
  ENDMETHOD.

  METHOD promoteEmployee.
    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_hist_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Promoted'
        event_date = cl_abap_context_info=>get_system_date( )
        new_position = ls_key-%param-NewPositionId
        new_salary = ls_key-%param-NewSalary
        currency_code = ls_key-%param-CurrencyCode
        changed_by = sy-uname
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
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Terminated'
        event_date = cl_abap_context_info=>get_system_date( )
        notes = ls_key-%param-TerminationReason
        changed_by = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD transferEmployee.
    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_hist_id) = cl_system_uuid=>create_uuid_x16_static( ).
      APPEND VALUE #(
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Transferred'
        event_date = cl_abap_context_info=>get_system_date( )
        new_department = ls_key-%param-NewDepartmentId
        changed_by = sy-uname
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
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Suspended'
        event_date = cl_abap_context_info=>get_system_date( )
        changed_by = sy-uname
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
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Activated'
        event_date = cl_abap_context_info=>get_system_date( )
        changed_by = sy-uname
      ) TO lcl_buffer=>mt_emp_hist.
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.
ENDCLASS.

