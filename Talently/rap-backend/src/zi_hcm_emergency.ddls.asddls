@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Emergency Contact - Interface'
define view entity ZI_HCM_Emergency
  as select from zhcm_emergency
  association to parent ZI_HCM_Employee as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
{
  key em_contact_id            as EmContactId,
      employee_id              as EmployeeId,
      contact_name             as ContactName,
      relationship             as Relationship,
      phone_number             as Phone,
      is_primary               as IsPrimary,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Employee
}
