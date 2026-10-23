@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employment History'
@UI.headerInfo: { typeName: 'Personnel Event', typeNamePlural: 'Employment History' }
@UI.presentationVariant: [{ sortOrder: [{ by: 'EventDate', direction: #DESC }] }]
define view entity ZI_HCM_EmpHistory
  as select from zhcm_emp_hist
{
      @UI.hidden: true
  key history_id     as HistoryId,

      @UI.hidden: true
      employee_id    as EmployeeId,

      @UI.lineItem: [{ position: 10, label: 'Date' }]
      event_date     as EventDate,

      @UI.lineItem: [{ position: 20, label: 'Event' }]
      event_type     as EventType,

      @UI.lineItem: [{ position: 30, label: 'Old Position' }]
      old_position   as OldPosition,

      @UI.lineItem: [{ position: 40, label: 'New Position' }]
      new_position   as NewPosition,

      @UI.lineItem: [{ position: 50, label: 'Old Department' }]
      old_department as OldDepartment,

      @UI.lineItem: [{ position: 60, label: 'New Department' }]
      new_department as NewDepartment,

      @UI.lineItem: [{ position: 70, label: 'New Salary' }]
      @Semantics.amount.currencyCode: 'CurrencyCode'
      new_salary     as NewSalary,

      @UI.hidden: true
      currency_code  as CurrencyCode,

      @UI.lineItem: [{ position: 80, label: 'Notes' }]
      notes          as Notes,

      @UI.lineItem: [{ position: 90, label: 'Changed By' }]
      changed_by     as ChangedBy
}
