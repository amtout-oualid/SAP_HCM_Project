@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Dependent - Interface'
define view entity ZI_HCM_Dependent
  as select from zhcm_dependent
  association to parent ZI_HCM_Employee as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
{
  key dependent_id             as DependentId,
      employee_id              as EmployeeId,
      name                   as Name,
      relationship             as Relationship,
      date_of_birth             as DateOfBirth,
      gender                 as Gender,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Employee
}
