@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Pipeline Template - Projection'
@Metadata.allowExtensions: true
define view entity ZC_HCM_PipeTmpl
  as projection on ZI_HCM_PipeTmpl
{
  key TemplateId,
  OfferId,
  StepName,
  StepOrder,
  StepType,
  LocalLastChangedAt,
  
  /* Associations */
  _Offer : redirected to parent ZC_HCM_JobOffer
}
