@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Employee Contact - Interface'
define view entity ZI_HCM_Contact
  as select from zhcm_contact
  association to parent ZI_HCM_Employee as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
{
  key contact_id              as ContactId,
      employee_id              as EmployeeId,
      personal_address           as PersonalAddress,
      phone_number             as PhoneNumber,
      personal_email            as PersonalEmail,
      work_email               as WorkEmail,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Employee
}
