@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pipeline Progress - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_PipeProg
  as projection on ZI_HCM_PipeProg
{
  key ProgressId,
  ApplicationId,
  StepOrder,
  StepName,
  Status,
  Score,
  Notes,
  CompletedAt,
  LocalLastChangedAt,
  OfferId,
  
  /* Associations */
  _Application : redirected to parent ZC_HCM_Application ,
  _Offer : redirected to ZC_HCM_JobOffer
}
