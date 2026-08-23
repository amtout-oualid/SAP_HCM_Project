@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Bank Details - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_BankDetl
  as projection on ZI_HCM_BankDetl
{
  key BankId,
  EmployeeId,
  BankName,
  AccountNumber,
  Iban,
  BicSwift,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  LocalLastChangedAt,
  
  
  /* Associations */
  _Employee : redirected to parent ZC_HCM_Employee
}
