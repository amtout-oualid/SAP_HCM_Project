@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank Details - Interface'
define view entity ZI_HCM_BankDetl
  as select from zhcm_bankdetl
  association to parent ZI_HCM_Employee as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
{
  key bank_detail_id           as BankId,
      employee_id              as EmployeeId,
      bank_name               as BankName,
      account_number            as AccountNumber,
      iban                   as Iban,
      bic_swift               as BicSwift,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,
      _Employee
}
