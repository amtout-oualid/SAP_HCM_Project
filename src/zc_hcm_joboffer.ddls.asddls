@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Job Offer - Projection'
@Metadata.allowExtensions: true
define root view entity ZC_HCM_JobOffer
  provider contract transactional_query
  as projection on ZI_HCM_JobOffer
{
  key OfferId,
  Title,
  Description,
  Department,
  RequiredSkills,
  ExperienceLevel,
  ContractType,
  Location,
  PositionsNeeded,
  PositionsFilled,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  SalaryMin,
  @Semantics.amount.currencyCode: 'CurrencyCode'
  SalaryMax,
  CurrencyCode,
  Status,
  StatusText,
  ValidUntil,
  CreatedBy,
  CreatedAt,
  LastChangedBy,
  @Semantics.systemDateTime.lastChangedAt: true
  LastChangedAt,
  @Semantics.systemDateTime.localInstanceLastChangedAt: true
  LocalLastChangedAt,
  
  /* Associations */
  _Applications : redirected to composition child ZC_HCM_Application
}
