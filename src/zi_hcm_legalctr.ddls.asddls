@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Legal Contract - Interface'
define view entity ZI_HCM_LegalCtr
  as select from zhcm_legal_ctr
  association to parent ZI_HCM_Employee as _Employee
    on $projection.EmployeeId = _Employee.EmployeeId
{
  key contract_id             as ContractId,
      employee_id              as EmployeeId,
      national_id              as NationalId,
      ssn                    as Ssn,
      contract_type             as ContractType,
      agreed_hours             as AgreedHours,
      contract_doc_url           as ContractDocUrl,
      valid_from               as ValidFrom,
      valid_to                as ValidTo,
      @Semantics.systemDateTime.localInstanceLastChangedAt: true
      local_last_changed_at        as LocalLastChangedAt,

      _Employee
}
