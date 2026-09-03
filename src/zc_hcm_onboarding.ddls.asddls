@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Onboarding - Projection'
@Metadata.allowExtensions: true
define root view entity ZC_HCM_Onboarding
  provider contract transactional_query
  as projection on ZI_HCM_Onboarding
{
  key FormId,
  ApplicationId,
  EmployeeId,
  FirstName,
  LastName,
  JobTitle, /* Exposed Job Title */
  DateOfBirth,
  PlaceOfBirth,
  Nationality,
  MaritalStatus,
  Gender,
  NationalId,
  Ssn,
  Address,
  Phone,
  PersonalEmail,
  BankName,
  BankAccount,
  Iban,
  EmergencyName,
  EmergencyPhone,
  EmergencyRelation,
  Status,
  StatusCriticality, /* Expose the criticality field */
  SubmittedAt,
  ApprovedBy,
  ApprovedAt,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  @Semantics.systemDateTime.lastChangedAt: true
  LastChangedAt,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  LocalLastChangedAt,
  
  /* Associations */
  _Application : redirected to ZC_HCM_Application
}
