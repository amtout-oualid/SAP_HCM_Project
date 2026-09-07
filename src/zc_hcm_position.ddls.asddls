@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Position - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_Position
  as projection on ZI_HCM_Position
{
  key PositionId,
  OrgUnitId,
  JobTitle,
  IsManager,
  FteValue,
  Budget,
  CurrencyCode,
  Status,
  LocalLastChangedAt,
  
  /* Associations */
  _OrgUnit : redirected to parent ZC_HCM_OrgUnit
}
