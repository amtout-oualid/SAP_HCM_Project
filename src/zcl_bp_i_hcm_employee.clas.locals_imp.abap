CLASS lhc_employee DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
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
    " Record the promotion in the history table using the parameters
    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_hist_id) = cl_system_uuid=>create_uuid_x16_static( ).
      INSERT INTO zhcm_emp_hist VALUES @( VALUE #(
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Promoted'
        event_date = cl_abap_context_info=>get_system_date( )
        new_position = ls_key-%param-NewPositionId
        new_salary = ls_key-%param-NewSalary
        currency_code = ls_key-%param-CurrencyCode
        changed_by = sy-uname
      ) ).
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
      INSERT INTO zhcm_emp_hist VALUES @( VALUE #(
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Terminated'
        event_date = cl_abap_context_info=>get_system_date( )
        notes = ls_key-%param-TerminationReason
        changed_by = sy-uname
      ) ).
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.

  METHOD transferEmployee.
    LOOP AT keys INTO DATA(ls_key).
      DATA(lv_hist_id) = cl_system_uuid=>create_uuid_x16_static( ).
      INSERT INTO zhcm_emp_hist VALUES @( VALUE #(
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Transferred'
        event_date = cl_abap_context_info=>get_system_date( )
        new_department = ls_key-%param-NewDepartmentId
        changed_by = sy-uname
      ) ).
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
      INSERT INTO zhcm_emp_hist VALUES @( VALUE #(
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Suspended'
        event_date = cl_abap_context_info=>get_system_date( )
        changed_by = sy-uname
      ) ).
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
      INSERT INTO zhcm_emp_hist VALUES @( VALUE #(
        client = sy-mandt
        history_id = lv_hist_id
        employee_id = ls_key-EmployeeId
        event_type = 'Activated'
        event_date = cl_abap_context_info=>get_system_date( )
        changed_by = sy-uname
      ) ).
    ENDLOOP.

    READ ENTITIES OF ZI_HCM_Employee IN LOCAL MODE
      ENTITY Employee ALL FIELDS WITH CORRESPONDING #( keys ) RESULT DATA(lt_result).
    result = VALUE #( FOR r IN lt_result ( %tky = r-%tky %param = r ) ).
  ENDMETHOD.
ENDCLASS.

CLASS lsc_employee DEFINITION INHERITING FROM cl_abap_behavior_saver.
  PROTECTED SECTION.
    METHODS save_modified REDEFINITION.
ENDCLASS.

CLASS lsc_employee IMPLEMENTATION.
  METHOD save_modified.
    IF create-employee IS NOT INITIAL.
      MODIFY zhcm_employee FROM TABLE @( VALUE #( FOR c IN create-employee (
          client = sy-mandt employee_id = c-EmployeeId first_name = c-FirstName last_name = c-LastName
          date_of_birth = c-DateOfBirth nationality = c-Nationality
          employee_status = c-EmployeeStatus hire_date = c-HireDate ) ) ).
    ENDIF.

    IF update-employee IS NOT INITIAL.
      MODIFY zhcm_employee FROM TABLE @( VALUE #( FOR u IN update-employee (
          client = sy-mandt employee_id = u-EmployeeId first_name = u-FirstName last_name = u-LastName
          date_of_birth = u-DateOfBirth nationality = u-Nationality
          employee_status = u-EmployeeStatus hire_date = u-HireDate ) ) ).
    ENDIF.

    IF delete-employee IS NOT INITIAL.
      DELETE zhcm_employee FROM TABLE @( VALUE #( FOR d IN delete-employee (
          client = sy-mandt employee_id = d-EmployeeId ) ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.

